import 'package:flutter/material.dart';

import '../ui/dex_screen.dart';
import '../ui/how_to_screen.dart';
import '../ui/lives_screen.dart';
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

class _RanseAppState extends State<RanseApp> with WidgetsBindingObserver {
  late final AppController c =
      widget.controller ?? AppController(autoGuide: true);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    c.init();
  }

  /// アプリが前面に戻ったら、期限切れの広告を読み直す（AdMob の広告は1時間で出せなくなる）。
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) c.money?.refreshAds();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
          AppScreen.guide => Scaffold(body: HowToScreen(c)),
          AppScreen.lives => Scaffold(body: LivesScreen(c)),
        },
      ),
    );
  }
}
