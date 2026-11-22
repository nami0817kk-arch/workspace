// 塔の意志（仮題）— 掘って育てる防衛ゲームの試作を、iPhone で遊ぶための入れ物。
//
// ゲーム本体は HTML の試作（assets/game/index.html）で、ここではそれを全画面の
// WebView で開くだけ。試作の正は game-assets/fukaana/prototype-v9.html にあり、
// 更新したら tool/sync_game.py で assets へ写す。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// 同梱したゲームの HTML の場所。テストからも参照する。
const gameAsset = 'assets/game/index.html';

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

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFEFECE4))
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
      ))
      ..loadFlutterAsset(gameAsset);
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
