// 塔の意志（仮題）— 掘って育てる防衛ゲームの試作を、iPhone で遊ぶための入れ物。
//
// ゲーム本体は HTML の試作（assets/game/index.html）で、ここではそれを全画面の
// WebView で開くだけ。試作の正は game-assets/fukaana/prototype-v*.html にあり、
// 更新したら tool/sync_game.py で assets へ写す。
//
// 保存: ゲームは localStorage にも書くが、WebView のファイル読み込みでは消えることが
// あるので、TouStore という窓口で同じ値をアプリ側（shared_preferences）にも渡してもらう。
// 起動したらアプリ側の値を window.__boot へ渡して戻す。
//
// 広告と課金: 全画面広告と「広告を消す」（lib/monetization/）。ゲームからの頼みは
// TouApp という窓口で受ける（lib/game/bridge.dart）。
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'game/bridge.dart';
import 'monetization/ad_service.dart';
import 'monetization/monetization.dart';
import 'monetization/purchase_service.dart';

/// 同梱したゲームの HTML の場所。テストからも参照する。
const gameAsset = 'assets/game/index.html';

/// WebView の中で開かず、外のブラウザに渡すリンクか（http/https。同梱の HTML は file: なので当たらない）。
bool isExternalLink(String url) => url.startsWith('https://') || url.startsWith('http://');

/// 裏に回る時にゲームへ送る JS（止めて保存。古いゲームなら保存だけ）。
const pauseJs = 'window.__pause ? window.__pause() : (window.__saveNow && window.__saveNow())';

/// ゲームが保存する値の名前（塔の途中経過・ストーリーと VS の途中経過・殿堂・自己ベスト・図鑑・
/// 面ごとのランク・ストーリー全クリア・チャレンジ・ヒント・音・VS の勇者）。
const storeKeys = [
  'tou-save',
  'tou-save-m',
  'tou-hall',
  'tou-best',
  'tou-dex',
  'tou-srank',
  'tou-story',
  'tou-chal',
  'tou-tut',
  'tou-snd',
  'tou-vs',
];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final prefs = await SharedPreferences.getInstance();
  final money = Monetization(prefs, ads: createAdService(), store: createPurchaseService());
  // 広告SDKとストアの準備は待たずに画面を出す（読み込みは裏で続く）
  unawaited(money.start());
  // 長く裏にいた後は手元の広告が期限切れになっている。戻ったら読み直す
  AppLifecycleListener(onResume: money.refreshAds);
  runApp(TouNoIshiApp(money: money));
}

class TouNoIshiApp extends StatelessWidget {
  const TouNoIshiApp({super.key, required this.money});
  final Monetization money;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '塔の意志',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8A4B1C))),
      home: GameScreen(money: money),
    );
  }
}

/// ゲームから届いた保存の知らせ（{"k": 名前, "v": 値か null}）を読み解く。
/// 名前が知らないものなら null を返し、何もしない。
({String key, String? value})? parseStoreMessage(String message) {
  try {
    final m = jsonDecode(message);
    if (m is! Map) return null;
    final k = m['k'];
    final v = m['v'];
    if (k is! String || !storeKeys.contains(k)) return null;
    if (v != null && v is! String) return null;
    return (key: k, value: v as String?);
  } catch (_) {
    return null;
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.money});
  final Monetization money;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late final WebViewController _controller;
  late final GameBridge _bridge;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bridge = GameBridge(
      money: widget.money,
      runJs: (js) async {
        try {
          await _controller.runJavaScript(js);
        } catch (_) {
          // ページの読み込み前など。次の pushApp で追いつく
        }
      },
    );
    // 購入が後から届いた（家族の承認・別の端末・返金）ときも、ゲーム本体に伝える
    widget.money.addListener(_onMoney);
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFEFECE4))
      ..addJavaScriptChannel('TouStore', onMessageReceived: (msg) => _store(msg.message))
      ..addJavaScriptChannel('TouApp', onMessageReceived: (msg) => unawaited(_bridge.handle(msg.message)))
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) => _boot(),
        // プライバシーポリシーなどのリンクは、ゲームの画面を離れずに外のブラウザで開く
        onNavigationRequest: (req) {
          if (isExternalLink(req.url)) {
            unawaited(launchUrl(Uri.parse(req.url), mode: LaunchMode.externalApplication));
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadFlutterAsset(gameAsset);
  }

  @override
  void dispose() {
    widget.money.removeListener(_onMoney);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // 裏に回るときに、ゲームを止めてその場で保存してもらう（戻っても止めたまま）
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _controller.runJavaScript(pauseJs);
    }
  }

  void _onMoney() => unawaited(_bridge.pushApp());

  Future<void> _store(String message) async {
    final r = parseStoreMessage(message);
    if (r == null) return;
    final prefs = await SharedPreferences.getInstance();
    if (r.value == null) {
      await prefs.remove(r.key);
    } else {
      await prefs.setString(r.key, r.value!);
    }
  }

  Future<void> _boot() async {
    final prefs = await SharedPreferences.getInstance();
    final data = <String, String>{};
    for (final k in storeKeys) {
      final v = prefs.getString(k);
      if (v != null) data[k] = v;
    }
    await _controller.runJavaScript('window.__boot && window.__boot(${jsonEncode(data)})');
    if (mounted) setState(() => _loading = false);
    // 値段と広告なしかを渡す（タイトルの「広告を消す」のボタン）
    await _bridge.pushApp();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFECE4),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
