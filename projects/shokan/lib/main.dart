// 召喚の山札（仮題）— ヴァンサバ×デッキの試作を、iPhone で遊ぶための入れ物。
//
// ゲーム本体は HTML の試作（assets/game/index.html）で、ここではそれを全画面の
// WebView で開くだけ。試作の正は claude.ai の Artifact で、更新したら
// tool/sync_game.py で assets へ写す。
//
// 保存: ゲームは localStorage に書く。WebView のファイル読み込みでは消えることが
// あるので、同梱の HTML の頭に入れた小さな仕掛けが、書いた値を ShokanStore という
// 窓口でアプリ側（shared_preferences）にも渡す。起動したらアプリ側の値を
// localStorage へ戻し、違っていたら一度だけ読み込み直す。
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// 同梱したゲームの HTML の場所。テストからも参照する。
const gameAsset = 'assets/game/index.html';

/// ゲームが保存する値の名前（兵舎・解放・工房などの記録と、音のオンオフ）。
const storeKeys = ['shokan-yamafuda-v2', 'shokan-mute'];

/// 裏に回る時にゲームへ送る JS（遊んでいる最中なら一時停止を押す）。
const pauseJs = "(function(){var p=document.getElementById('pause'),o=document.getElementById('paused');"
    "if(p&&(!o||o.hidden)&&document.getElementById('title').hidden)p.click()})()";

/// 起動時にアプリ側の値を localStorage へ戻す JS。違っていたら一度だけ読み込み直す
/// （ゲームは読み込みの最初に localStorage を読むため）。
String restoreJs(Map<String, String> data) =>
    '(function(d){var ch=false;for(var k in d){if(localStorage.getItem(k)!==d[k]){localStorage.setItem(k,d[k]);ch=true}}'
    "if(ch&&!sessionStorage.getItem('shokan-restored')){sessionStorage.setItem('shokan-restored','1');location.reload();return 1}return 0})(${jsonEncode(data)})";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const ShokanApp());
}

class ShokanApp extends StatelessWidget {
  const ShokanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: '召喚の山札',
      debugShowCheckedModeBanner: false,
      home: GameScreen(),
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
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0F1A14))
      ..addJavaScriptChannel('ShokanStore', onMessageReceived: (msg) => _store(msg.message))
      ..setNavigationDelegate(NavigationDelegate(onPageFinished: (_) => _boot()))
      ..loadFlutterAsset(gameAsset);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _controller.runJavaScript(pauseJs).catchError((_) {});
    }
  }

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
    try {
      await _controller.runJavaScript(restoreJs(data));
    } catch (_) {
      // 読み込み直しの途中など。次の onPageFinished でもう一度呼ばれる
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1A14),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading) const Center(child: CircularProgressIndicator(color: Color(0xFFE8C25A))),
        ],
      ),
    );
  }
}
