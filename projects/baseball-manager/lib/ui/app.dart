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
    return MaterialApp(
      title: '野球育成',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF2E7D32), useMaterial3: true),
      home: FutureBuilder<bool>(
        future: _loaded,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
