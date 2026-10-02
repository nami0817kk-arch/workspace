import 'dart:async';

import 'package:flutter/foundation.dart' show LicenseEntryWithLineBreaks, LicenseRegistry;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game/bridge.dart';
import 'game/game_screen.dart';
import 'monetization/ad_service.dart';
import 'monetization/monetization.dart';
import 'monetization/purchase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // 同梱フォント（OFL）のライセンス文を「ライセンス」画面に載せる。OFL は同梱時に添付を求めている
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(['Dela Gothic One'], await rootBundle.loadString('assets/licenses/OFL-DelaGothicOne.txt'));
  });
  final prefs = await SharedPreferences.getInstance();
  final money = Monetization(prefs, ads: createAdService(), store: createPurchaseService());
  // 広告SDKの準備は待たずに画面を出す（読み込みは裏で続く）
  unawaited(money.start());
  // 長く裏にいた後は手元の広告が期限切れになっている。戻ったら読み直す
  AppLifecycleListener(onResume: money.refreshAds);
  runApp(HikariApp(money: money, store: WebStore(prefs)));
}

class HikariApp extends StatelessWidget {
  const HikariApp({super.key, required this.money, required this.store});
  final Monetization money;
  final WebStore store;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'ひかりの七席',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorSchemeSeed: const Color(0xFF7445D6), useMaterial3: true),
    darkTheme: ThemeData(colorSchemeSeed: const Color(0xFF7445D6), brightness: Brightness.dark, useMaterial3: true),
    home: GameScreen(money: money, store: store),
  );
}
