import 'package:flutter/material.dart';

import 'controller.dart';
import 'milestone_dialog.dart';
import 'game_screen.dart';
import 'home_screen.dart';

class BaseballManagerApp extends StatefulWidget {
  const BaseballManagerApp({super.key, this.controller});

  /// テストで差し替える。
  final GameController? controller;

  @override
  State<BaseballManagerApp> createState() => _BaseballManagerAppState();
}

class _BaseballManagerAppState extends State<BaseballManagerApp> {
  late final GameController c = widget.controller ?? GameController();
  late final Future<bool> _loaded = c.loadSaved();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => MaterialApp(
        title: kTestBuild ? '野球育成(テスト版)' : '野球育成',
        debugShowCheckedModeBanner: false,
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        themeMode: c.themeMode,
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          if (c.textScale == 1.0) return child!;
          return MediaQuery(
            data: mq.copyWith(
                textScaler:
                    TextScaler.linear(mq.textScaler.scale(1) * c.textScale)),
            child: child!,
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
      ),
    );
  }
}

/// 節目(ドラフト指名・優勝・進学・コツの習得)が起きたら、ダイアログで見せる。
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
    _check(); // 起動時に出したい知らせ(読み込めなかった保存データなど)
  }

  @override
  void dispose() {
    widget.controller.removeListener(_check);
    super.dispose();
  }

  void _check() {
    final t = widget.controller.toast;
    if (t != null) {
      widget.controller.toast = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final m = ScaffoldMessenger.maybeOf(context);
        m?.hideCurrentSnackBar();
        final tone = widget.controller.toastTone;
        final c = widget.controller;
        m?.showSnackBar(SnackBar(
          key: const Key('result-toast'),
          content: Row(children: [
            Icon(
                tone > 0
                    ? Icons.trending_up
                    : (tone < 0 ? Icons.warning_amber_rounded : Icons.check),
                size: 20,
                color: tone > 0
                    ? const Color(0xFF81C784)
                    : (tone < 0 ? const Color(0xFFFFB74D) : Colors.white70)),
            const SizedBox(width: 8),
            Expanded(child: Text(t)),
          ]),
          action: c.canUndo
              ? SnackBarAction(
                  key: const Key('toast-undo'), label: '戻す', onPressed: c.undo)
              : null,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          // 広い画面では、操作バーと同じ幅に収める。
          width: MediaQuery.sizeOf(context).width > 560 ? 520 : null,
        ));
      });
    }
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
  final scheme =
      ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32), brightness: b);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    fontFamily: 'NotoSansJP',
    scaffoldBackgroundColor:
        b == Brightness.light ? const Color(0xFFF3F7EF) : scheme.surface,
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
