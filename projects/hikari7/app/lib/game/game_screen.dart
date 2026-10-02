import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../monetization/monetization.dart';
import 'bridge.dart';

/// ゲーム本体（試作をアプリ用に組み立てた1枚のページ）を、画面いっぱいの WebView で動かす。
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.money, required this.store});
  final Monetization money;
  final WebStore store;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final WebViewController _web;
  late final GameBridge _bridge;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..addJavaScriptChannel('HikariApp', onMessageReceived: (m) => unawaited(_bridge.handle(m.message)))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loaded = true);
            unawaited(_bridge.pushApp());
          },
          // ページの中から別のサイトへ移らない（外部のページは端末のブラウザで開く）
          onNavigationRequest: (r) {
            final u = Uri.tryParse(r.url);
            if (u == null || u.scheme == 'about' || u.scheme == 'data' || u.host.isEmpty) return NavigationDecision.navigate;
            if (u.scheme == 'https' && GameBridge.allowedHosts.contains(u.host)) {
              unawaited(launchUrl(u, mode: LaunchMode.externalApplication));
            }
            return NavigationDecision.prevent;
          },
        ),
      );
    _bridge = GameBridge(
      money: widget.money,
      store: widget.store,
      runJs: (js) async {
        try {
          await _web.runJavaScript(js);
        } catch (_) {
          // ページの読み込み前など。次の pushApp で追いつく
        }
      },
      openUrl: (u) async {
        await launchUrl(u, mode: LaunchMode.externalApplication);
      },
      showLicenses: () => showLicensePage(context: context, applicationName: 'ひかりの七席', applicationLegalese: '© つるはし社'),
    );
    // 購入が後から届いた（家族の承認・別の端末・返金）ときも、ゲーム本体に伝える
    widget.money.addListener(_onMoney);
    unawaited(_load());
  }

  void _onMoney() => unawaited(_bridge.pushApp());

  Future<void> _load() async {
    final html = await rootBundle.loadString('assets/web/index.html');
    final boot = <String, Object?>{'store': widget.store.snapshot(), 'adFree': widget.money.adFree};
    await _web.loadHtmlString(injectBoot(html, boot));
  }

  @override
  void dispose() {
    widget.money.removeListener(_onMoney);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final bg = dark ? const Color(0xFF14111C) : const Color(0xFFF6F3FA);
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            WebViewWidget(controller: _web),
            if (!_loaded) const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}
