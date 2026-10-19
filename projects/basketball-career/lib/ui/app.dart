import 'package:flutter/material.dart';

import 'controller.dart';
import 'game_screen.dart';
import 'home_screen.dart';
import 'milestone_dialog.dart';

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
    return MaterialApp(
      title: 'バスケ育成',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
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
    if (_showing || widget.controller.pending.isEmpty) return;
    _showing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      while (mounted && widget.controller.pending.isNotEmpty) {
        final m = widget.controller.pending.first;
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => MilestoneDialog(milestone: m),
        );
        widget.controller.dismissMilestone();
      }
      _showing = false;
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

ThemeData _theme(Brightness b) {
  final scheme = ColorScheme.fromSeed(
          seedColor: const Color(0xFFE65100), brightness: b)
      .copyWith(primary: const Color(0xFFE65100), onPrimary: Colors.white);
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
