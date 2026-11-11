import 'package:flutter/material.dart';

import '../gm/profile.dart';
import 'gm/home_screen.dart';
import 'gm/hub_screen.dart';
import 'gm/style.dart';
import 'gm_controller.dart';
import 'layout.dart';
import 'remove_ads_offer.dart';

class BasketballCareerApp extends StatefulWidget {
  const BasketballCareerApp({super.key, this.controller});

  /// テストで差し替える。
  final GmController? controller;

  @override
  State<BasketballCareerApp> createState() => _BasketballCareerAppState();
}

class _BasketballCareerAppState extends State<BasketballCareerApp> {
  late final GmController c = widget.controller ?? GmController();
  late final Future<bool> _loaded = c.load();
  static final _theme = gmTheme();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appFullName,
      debugShowCheckedModeBanner: false,
      theme: _theme,
      darkTheme: _theme,
      // 幅の広い端末(iPad など)では、画面全体をそのまま大きくする(カードや絵が小さく、余白だらけにならないように)。
      builder: (context, child) => TabletScale(child: child ?? const SizedBox.shrink()),
      home: FutureBuilder<bool>(
        future: _loaded,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return _NoticeHost(
            controller: c,
            child: ListenableBuilder(
              listenable: c,
              builder: (context, _) {
                if (c.career == null || c.atHome) return GmHomeScreen(c: c);
                return HubScreen(c: c);
              },
            ),
          );
        },
      ),
    );
  }
}

/// 実績の解放と「広告を消す」の案内を、ダイアログで見せる。
class _NoticeHost extends StatefulWidget {
  const _NoticeHost({required this.controller, required this.child});
  final GmController controller;
  final Widget child;

  @override
  State<_NoticeHost> createState() => _NoticeHostState();
}

class _NoticeHostState extends State<_NoticeHost> {
  bool _showing = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_check);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_check);
    super.dispose();
  }

  void _check() {
    final c = widget.controller;
    if (_showing || (c.pending.isEmpty && !c.offerRemoveAds)) return;
    _showing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      while (mounted && c.pending.isNotEmpty) {
        final a = c.pending.first;
        await showDialog<void>(
          context: context,
          builder: (ctx) => AchievementDialog(achievement: a),
        );
        c.dismissAchievement();
      }
      final money = c.money;
      if (mounted && c.offerRemoveAds && money != null) {
        await showRemoveAdsOffer(context, money);
      }
      c.dismissRemoveAdsOffer();
      _showing = false;
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class AchievementDialog extends StatelessWidget {
  const AchievementDialog({super.key, required this.achievement});
  final Achievement achievement;

  @override
  Widget build(BuildContext context) => AlertDialog(
        icon: const Icon(Icons.emoji_events_rounded, color: GmColors.gold, size: 44),
        title: Text('実績「${achievement.title}」'),
        content: Text(
          achievement.text,
          textAlign: TextAlign.center,
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      );
}

/// 幅の広い端末(iPad)では、[designWidth] の幅で作った画面を、拡大して全面に出す。押す位置も一緒に変わる。
/// 作る基準は横向きのスマホ(844x390)。
class TabletScale extends StatelessWidget {
  const TabletScale({super.key, required this.child});
  final Widget child;

  static const designWidth = 844.0;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    if (mq.size.width < tabletWidth) return child;
    final scale = (mq.size.width / designWidth).clamp(1.0, 1.8);
    final size = mq.size / scale;
    return FittedBox(
      fit: BoxFit.fill,
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: MediaQuery(
          data: mq.copyWith(
            size: size,
            padding: mq.padding / scale,
            viewPadding: mq.viewPadding / scale,
            viewInsets: mq.viewInsets / scale,
          ),
          child: child,
        ),
      ),
    );
  }
}
