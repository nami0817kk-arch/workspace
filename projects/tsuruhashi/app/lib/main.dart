import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game/bridge.dart';
import 'game/game_screen.dart';
import 'game/notifier.dart';
import 'monetization/ad_service.dart';
import 'monetization/monetization.dart';
import 'monetization/purchase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final prefs = await SharedPreferences.getInstance();
  final money = Monetization(prefs, ads: createAdService(), store: createPurchaseService());
  // 広告SDKの準備は待たずに画面を出す（読み込みは裏で続く）
  unawaited(money.start());
  // 長く裏にいた後は手元の広告が期限切れになっている。戻ったら読み直す
  AppLifecycleListener(onResume: money.refreshAds);
  final notifier = createNotifier();
  unawaited(notifier.init());
  runApp(TsuruApp(money: money, store: WebStore(prefs), notifier: notifier));
}

class TsuruApp extends StatelessWidget {
  const TsuruApp({super.key, required this.money, required this.store, required this.notifier});
  final Monetization money;
  final WebStore store;
  final Notifier notifier;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'つるはし採掘',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorSchemeSeed: const Color(0xFFC8740F), useMaterial3: true),
    darkTheme: ThemeData(colorSchemeSeed: const Color(0xFFC8740F), brightness: Brightness.dark, useMaterial3: true),
    home: GameScreen(money: money, store: store, notifier: notifier),
  );
}
