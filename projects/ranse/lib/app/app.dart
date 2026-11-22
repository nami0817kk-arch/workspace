import 'package:flutter/material.dart';

import '../ui/dex_screen.dart';
import '../ui/play_screen.dart';
import '../ui/theme.dart';
import '../ui/title_birth_screens.dart';
import 'controller.dart';

class RanseApp extends StatefulWidget {
  const RanseApp({super.key, this.controller});

  /// テストで差し替えるための入り口。
  final AppController? controller;

  @override
  State<RanseApp> createState() => _RanseAppState();
}

class _RanseAppState extends State<RanseApp> {
  late final AppController c = widget.controller ?? AppController();

  @override
  void initState() {
    super.initState();
    c.init();
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '乱世下剋上',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      // iPhone の「文字を大きく」は効かせるが、横棒や選択肢カードが崩れないよう1.3倍までにする。
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: mq.textScaler.clamp(
              minScaleFactor: 1,
              maxScaleFactor: 1.3,
            ),
          ),
          child: child!,
        );
      },
      home: ListenableBuilder(
        listenable: c,
        builder: (context, _) => switch (c.screen) {
          AppScreen.title => Scaffold(body: TitleScreen(c)),
          AppScreen.birth => Scaffold(body: BirthScreen(c)),
          AppScreen.play => PlayScreen(c),
          AppScreen.dex => Scaffold(body: DexScreen(c)),
        },
      ),
    );
  }
}
