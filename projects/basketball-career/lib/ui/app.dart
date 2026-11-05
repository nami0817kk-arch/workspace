import 'package:flutter/material.dart';

import 'controller.dart';
import 'game_screen.dart';
import 'home_screen.dart';
import 'milestone_dialog.dart';
import 'remove_ads_offer.dart';
import 'layout.dart';
import 'team_colors.dart';

class BasketballCareerApp extends StatefulWidget {
  const BasketballCareerApp({super.key, this.controller});

  /// テストで差し替える。
  final GameController? controller;

  @override
  State<BasketballCareerApp> createState() => _BasketballCareerAppState();
}

class _BasketballCareerAppState extends State<BasketballCareerApp> {
  late final GameController c = widget.controller ?? GameController();
  late final Future<bool> _loaded = c.loadSaved();

  @override
  Widget build(BuildContext context) {
    // 画面の差し色は、いまの所属チームの色(始める前はバスケットボールの橙)。
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => _app(c.game == null ? _ball : teamColorOfGame(c.game!).accent),
    );
  }

  Widget _app(Color accent) {
    return MaterialApp(
      title: 'バスケ育成',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light, accent),
      darkTheme: _theme(Brightness.dark, accent),
      // 幅の広い端末(iPad など)では文字を少し大きくする(小さく見えないように)。
      builder: (context, child) {
        final tablet = isTablet(context);
        if (!tablet || child == null) return child ?? const SizedBox.shrink();
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(mq.textScaler.scale(1.0) * 1.25)),
          child: child,
        );
      },
      home: FutureBuilder<bool>(
        future: _loaded,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          return _MilestoneHost(
            controller: c,
            child: ListenableBuilder(
              listenable: c,
              builder: (context, _) {
                final g = c.game;
                if (g == null) return HomeScreen(controller: c);
                return GameScreen(controller: c, game: g);
              },
            ),
          );
        },
      ),
    );
  }
}

/// 節目(優勝・個人賞・目標達成・進学・プロ契約・海外挑戦)が起きたら、ダイアログで見せる。
class _MilestoneHost extends StatefulWidget {
  const _MilestoneHost({required this.controller, required this.child});
  final GameController controller;
  final Widget child;

  @override
  State<_MilestoneHost> createState() => _MilestoneHostState();
}

class _MilestoneHostState extends State<_MilestoneHost> {
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
        final m = c.pending.first;
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => MilestoneDialog(milestone: m),
        );
        c.dismissMilestone();
      }
      // 節目を見終えてから、「広告を消す」の案内(全画面広告のあと、ときどき)
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

const _ball = Color(0xFFE65100);

final _themes = <(Brightness, Color), ThemeData>{};

ThemeData _theme(Brightness b, Color accent) =>
    _themes.putIfAbsent((b, accent), () => _makeTheme(b, accent));

ThemeData _makeTheme(Brightness b, Color accent) {
  final scheme = ColorScheme.fromSeed(seedColor: accent, brightness: b)
      .copyWith(primary: accent, onPrimary: Colors.white);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    fontFamily: 'NotoSansJP',
    scaffoldBackgroundColor:
        b == Brightness.light ? const Color(0xFFFFF6EE) : scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: 'NotoSansJP',
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: scheme.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: b == Brightness.light ? Colors.white : scheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );
}
