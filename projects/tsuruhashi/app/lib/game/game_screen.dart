import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../monetization/monetization.dart';
import 'bridge.dart';
import 'game_audio.dart';
import 'notifier.dart';

/// ゲーム本体（試作をアプリ用に組み立てた1枚のページ）を、画面いっぱいの WebView で動かす。
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.money, required this.store, required this.notifier});
  final Monetization money;
  final WebStore store;
  final Notifier notifier;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final WebViewController _web;
  late final GameBridge _bridge;
  bool _loaded = false;
  bool? _dark;
  AppLifecycleListener? _life;
  final GameAudio _audio = GameAudio();
  double _capHours = 8;

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..addJavaScriptChannel('TsuruApp', onMessageReceived: (m) => unawaited(_bridge.handle(m.message)))
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
      showLicenses: () => showLicensePage(context: context, applicationName: 'つるはし採掘', applicationLegalese: '© つるはし社'),
      haptic: (k) => switch (k) {
        'success' => HapticFeedback.mediumImpact(),
        'heavy' => HapticFeedback.heavyImpact(),
        _ => HapticFeedback.selectionClick(),
      },
      review: () async {
        try {
          final r = InAppReview.instance;
          if (await r.isAvailable()) await r.requestReview();
        } catch (_) {}
      },
      theme: (d) {
        if (mounted) setState(() => _dark = d);
      },
      bgm: (k, v) => unawaited(_audio.bgm(k, v)),
      notifAsk: () async => widget.notifier.ask(),
      notifCap: (h) => _capHours = h,
    );
    // 裏に回る直前に、ゲームの進み具合をその場で保存させる
    _life = AppLifecycleListener(
      onInactive: _pause,
      onHide: () {
        _pause();
        unawaited(_audio.setHidden(true));
        // 留守の上限の時刻に「いっぱいになりました」を1件だけ予約（許可がなければ何も出ない）
        unawaited(widget.notifier.scheduleFull(_capHours));
      },
      onShow: () {
        unawaited(_audio.setHidden(false));
        unawaited(widget.notifier.cancelAll());
        // 戻ったら留守の計算をさせる（WebView の visibilitychange が来ない端末のため）
        if (_loaded) unawaited(_web.runJavaScript('window.tsuruResume&&tsuruResume()').catchError((_) {}));
      },
    );
    // 購入が後から届いた（家族の承認・別の端末・返金）ときも、ゲーム本体に伝える
    widget.money.addListener(_onMoney);
    unawaited(_load());
  }

  void _onMoney() => unawaited(_bridge.pushApp());

  void _pause() {
    if (_loaded) unawaited(_web.runJavaScript('window.tsuruPause&&tsuruPause()').catchError((_) {}));
  }

  Future<void> _load() async {
    final html = await rootBundle.loadString('assets/web/index.html');
    final boot = <String, Object?>{'store': widget.store.snapshot(), ...GameBridge.bootState(widget.money)};
    await _web.loadHtmlString(injectBoot(html, boot));
  }

  @override
  void dispose() {
    widget.money.removeListener(_onMoney);
    _life?.dispose();
    _audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = _dark ?? MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final bg = dark ? const Color(0xFF15120F) : const Color(0xFF2B2118);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            WebViewWidget(controller: _web),
            // 起動画面：ページが出るまでの間、社名と題字を見せる（ゲームの起動画面と同じ色）
            if (!_loaded)
              Container(
                color: const Color(0xFF1C140D),
                alignment: Alignment.center,
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('つるはし社', style: TextStyle(color: Color(0xFFF6B85C), fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 5)),
                    SizedBox(height: 6),
                    Text('つるはし採掘', style: TextStyle(color: Color(0xFFFFF4DC), fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: 3)),
                    SizedBox(height: 28),
                    SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Color(0xFFF6B85C))),
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
