// 塔の意志（仮題）— 掘って育てる防衛ゲームの試作を、iPhone で遊ぶための入れ物。
//
// ゲーム本体は HTML の試作（assets/game/index.html）で、ここではそれを全画面の
// WebView で開くだけ。試作の正は game-assets/fukaana/prototype-v*.html にあり、
// 更新したら tool/sync_game.py で assets へ写す。
//
// 保存: ゲームは localStorage にも書くが、WebView のファイル読み込みでは消えることが
// あるので、TouStore という窓口で同じ値をアプリ側（shared_preferences）にも渡してもらう。
// 起動したらアプリ側の値を window.__boot へ渡して戻す。
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// 同梱したゲームの HTML の場所。テストからも参照する。
const gameAsset = 'assets/game/index.html';

/// ゲームが保存する値の名前（塔の途中経過・殿堂・自己ベスト・図鑑）。
const storeKeys = ['tou-save', 'tou-hall', 'tou-best', 'tou-dex'];

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const TouNoIshiApp());
}

class TouNoIshiApp extends StatelessWidget {
  const TouNoIshiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '塔の意志',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8A4B1C))),
      home: const GameScreen(),
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
      ..setBackgroundColor(const Color(0xFFEFECE4))
      ..addJavaScriptChannel('TouStore', onMessageReceived: (msg) => _store(msg.message))
      ..setNavigationDelegate(NavigationDelegate(onPageFinished: (_) => _boot()))
      ..loadFlutterAsset(gameAsset);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // 裏に回るときに、ゲームにその場で保存してもらう
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _controller.runJavaScript('window.__saveNow && window.__saveNow()');
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
    await _controller.runJavaScript('window.__boot && window.__boot(${jsonEncode(data)})');
    if (mounted) setState(() => _loading = false);
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
