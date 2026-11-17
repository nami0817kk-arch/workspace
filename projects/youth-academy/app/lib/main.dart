import 'dart:async';
import 'dart:convert';

// Flutter 3.50 で material.dart が非推奨になった（material_ui への移行は別件）。CI の analyze を止めないよう、この1行だけ許す
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'boot.dart';
import 'monetization/ad_service.dart';
import 'monetization/bridge.dart';
import 'monetization/purchase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 横向き固定（決定67）
  await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  final prefs = await SharedPreferences.getInstance();
  runApp(YouthApp(prefs: prefs));
}

class YouthApp extends StatelessWidget {
  const YouthApp({super.key, required this.prefs});
  final SharedPreferences prefs;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'ユースの系譜',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorSchemeSeed: const Color(0xFF1F6FEB), useMaterial3: true),
    home: MatchScreen(prefs: prefs),
  );
}

/// 試合の画面（Web の中身）を、画面いっぱいの WebView で動かす。
class MatchScreen extends StatefulWidget {
  const MatchScreen({super.key, required this.prefs});
  final SharedPreferences prefs;

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> with WidgetsBindingObserver {
  late final WebViewController _web;
  late final MonetizationBridge _bridge;
  bool _loaded = false;
  bool _reloading = false;
  static const _prefix = 'ya_';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFEAF0F8))
      // ページからの保存の依頼：{"k": 名前, "v": JSON文字列}
      ..addJavaScriptChannel('YouthApp', onMessageReceived: (m) => unawaited(_onMessage(m.message)))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loaded = true);
          },
          // 裏に回っているあいだに iOS が WebView の中身を落とすと、戻ったときに真っ白になる。落ちたと分かったら読み直す
          onWebResourceError: (e) {
            if (e.errorType == WebResourceErrorType.webContentProcessTerminated) unawaited(_reload());
          },
          // ページの中から別のサイトへ移らない
          onNavigationRequest: (r) {
            final u = Uri.tryParse(r.url);
            if (u == null || u.scheme == 'about' || u.scheme == 'data' || u.host.isEmpty) return NavigationDecision.navigate;
            return NavigationDecision.prevent;
          },
        ),
      );
    // 広告と課金（ページからの依頼は _onMessage で受ける）。権利を書き込むのはこの橋だけ
    _bridge = MonetizationBridge(
      prefs: widget.prefs,
      ads: createAdService(),
      purchases: createPurchaseService(),
      send: (json) {
        if (!mounted) return;
        unawaited(_web.runJavaScript('window.YAnative && window.YAnative.onMsg(${jsonEncode(json)});'));
      },
    );
    unawaited(_bridge.start());
    unawaited(_load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // 別アプリから戻ったら、ページに中身があるかを確かめる。無い（真っ白）・答えが返らないときは保存から読み直す
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_checkAlive());
  }

  Future<void> _checkAlive() async {
    if (!_loaded || _reloading) return;
    Object? r;
    try {
      r = await _web.runJavaScriptReturningResult(aliveProbe).timeout(const Duration(seconds: 2));
    } catch (_) {
      r = null;
    }
    if (needsReload(r)) await _reload();
  }

  Future<void> _reload() async {
    if (_reloading || !mounted) return;
    _reloading = true;
    setState(() => _loaded = false);
    try {
      await _load();
    } finally {
      _reloading = false;
    }
  }

  // 広告・課金の依頼なら橋へ、そうでなければ保存の依頼
  Future<void> _onMessage(String message) async {
    if (await _bridge.handle(message)) return;
    await _save(message);
  }

  Future<void> _save(String message) async {
    final obj = _parse(message.trim());
    if (obj == null) return;
    var ok = false;
    try {
      ok = await widget.prefs.setString('$_prefix${obj.$1}', obj.$2);
    } catch (_) {
      ok = false;
    }
    // 書けなかったらページへ知らせる（ページは続いたら「保存できませんでした」と出す）
    if (!ok && mounted) {
      unawaited(_web.runJavaScript('window.YAnative && window.YAnative.onMsg(${jsonEncode(jsonEncode({'ev': 'saveFail', 'k': obj.$1}))});'));
    }
  }

  (String, String)? _parse(String s) {
    Object? d;
    try {
      d = jsonDecode(s);
    } catch (_) {
      return null;
    }
    if (d is! Map) return null;
    final k = d['k'];
    final v = d['v'];
    if (k is! String || v is! String || k.isEmpty || k.length > 40) return null;
    return (k, v);
  }

  Future<void> _load() async {
    final html = await rootBundle.loadString('assets/web/index.html');
    final all = {for (final k in widget.prefs.getKeys()) k: widget.prefs.get(k)};
    await _web.loadHtmlString(injectBoot(html, collectStore(all, prefix: _prefix)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFEAF0F8),
    body: Stack(
      children: [
        WebViewWidget(controller: _web),
        if (!_loaded)
          Container(
            color: const Color(0xFF14284B),
            alignment: Alignment.center,
            child: const Text('ユースの系譜', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 4)),
          ),
      ],
    ),
  );
}
