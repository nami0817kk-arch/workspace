import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'boot.dart';

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
  bool _loaded = false;
  static const _prefix = 'ya_';

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFEAF0F8))
      // ページからの保存の依頼：{"k": 名前, "v": JSON文字列}
      ..addJavaScriptChannel('YouthApp', onMessageReceived: (m) => unawaited(_save(m.message)))
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
    unawaited(_load());
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
