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

class _MatchScreenState extends State<MatchScreen> {
  late final WebViewController _web;
  late final MonetizationBridge _bridge;
  bool _loaded = false;
  static const _prefix = 'ya_';

  @override
  void initState() {
    super.initState();
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

  // 広告・課金の依頼なら橋へ、そうでなければ保存の依頼
  Future<void> _onMessage(String message) async {
    if (await _bridge.handle(message)) return;
    await _save(message);
  }

  Future<void> _save(String message) async {
    try {
      final obj = _parse(message.trim());
      if (obj == null) return;
      await widget.prefs.setString('$_prefix${obj.$1}', obj.$2);
    } catch (_) {}
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
    final store = <String, String>{};
    for (final key in widget.prefs.getKeys()) {
      if (key.startsWith(_prefix)) {
        final v = widget.prefs.getString(key);
        if (v != null) store[key.substring(_prefix.length)] = v;
      }
    }
    await _web.loadHtmlString(injectBoot(html, store));
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
