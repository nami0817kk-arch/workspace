import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';
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

  /// 端末の言語。ゲームの言語の始まりと、起動画面・お知らせの言語に使う
  String get _deviceLang => WidgetsBinding.instance.platformDispatcher.locale.languageCode;
  bool get _ja => _deviceLang == 'ja';
  AppLifecycleListener? _life;

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFF4EDE1))
      ..addJavaScriptChannel('TenbinApp', onMessageReceived: (m) => unawaited(_bridge.handle(m.message)))
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
      deviceLang: _deviceLang,
      showLicenses: () => showLicensePage(
        context: context,
        applicationName: _bridge.lang == 'en' ? 'Moji Stack' : 'もじつみ',
        applicationLegalese: _bridge.lang == 'en' ? '© Tsuruhashi-sha' : '© つるはし社',
      ),
      haptic: (k) => switch (k) {
        'success' => HapticFeedback.mediumImpact(),
        'warn' => HapticFeedback.heavyImpact(),
        _ => HapticFeedback.selectionClick(),
      },
      share: (text) async {
        try {
          final box = context.findRenderObject() as RenderBox?;
          await SharePlus.instance.share(
            ShareParams(text: text, sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size),
          );
        } catch (_) {}
      },
      review: () async {
        try {
          final r = InAppReview.instance;
          if (await r.isAvailable()) await r.requestReview();
        } catch (_) {}
      },
    );
    // 裏に回る直前に、遊びを止めて記録を保存させる
    _life = AppLifecycleListener(onInactive: _pause, onHide: _pause);
    // 購入が後から届いた（家族の承認・別の端末・返金）ときも、ゲーム本体に伝える
    widget.money.addListener(_onMoney);
    unawaited(_load());
  }

  void _onMoney() => unawaited(_bridge.pushApp());

  void _pause() {
    if (_loaded) unawaited(_web.runJavaScript('window.tenbinPause&&tenbinPause()').catchError((_) {}));
  }

  Future<void> _load() async {
    final html = await rootBundle.loadString('assets/web/index.html');
    final boot = <String, Object?>{'store': widget.store.snapshot(), 'adFree': widget.money.adFree, 'lang': _deviceLang};
    await _web.loadHtmlString(injectBoot(html, boot));
  }

  @override
  void dispose() {
    widget.money.removeListener(_onMoney);
    _life?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFF4EDE1);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              WebViewWidget(controller: _web),
              // 起動画面：ページが出るまでの間、題字を見せる
              if (!_loaded)
                Container(
                  color: bg,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_ja ? 'もじつみ' : 'Moji Stack', style: const TextStyle(color: Color(0xFF3B2F24), fontSize: 40, fontWeight: FontWeight.w900, letterSpacing: 4)),
                      const SizedBox(height: 6),
                      Text(_ja ? 'ひらがな積み上げ ことばパズル' : 'Stack hiragana, learn Japanese words', style: const TextStyle(color: Color(0xFF8A7663), fontSize: 13, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 28),
                      const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Color(0xFFD9472F))),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
