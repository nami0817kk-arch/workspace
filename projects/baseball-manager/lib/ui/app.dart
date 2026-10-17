import 'package:flutter/material.dart';

import 'controller.dart';
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
          return ListenableBuilder(
            listenable: c,
            builder: (context, _) {
              final g = c.game;
              if (g == null) return HomeScreen(controller: c);
              return GameScreen(controller: c, game: g);
            },
          );
        },
      ),
    );
  }
}

