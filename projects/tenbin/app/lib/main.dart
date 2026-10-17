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
  // 同梱しているもののライセンス文を「ライセンス一覧」に載せる（OFL は同梱時に添付を求めている）
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(['M PLUS Rounded 1c'], await rootBundle.loadString('assets/licenses/OFL-MPLUSRounded1c.txt'));
    yield LicenseEntryWithLineBreaks(['matter.js'], await rootBundle.loadString('assets/licenses/matter-js.txt'));
    yield LicenseEntryWithLineBreaks(['poly-decomp.js'], await rootBundle.loadString('assets/licenses/poly-decomp.txt'));
    yield LicenseEntryWithLineBreaks(['ことばの一覧（wordfreq・UniDic）'], await rootBundle.loadString('assets/licenses/words.txt'));
  });
  final prefs = await SharedPreferences.getInstance();
  final money = Monetization(prefs, ads: createAdService(), store: createPurchaseService());
  // 広告SDKの準備は待たずに画面を出す（読み込みは裏で続く）
  unawaited(money.start());
  // 長く裏にいた後は手元の広告が期限切れになっている。戻ったら読み直す
  AppLifecycleListener(onResume: money.refreshAds);
  runApp(MojitsumiApp(money: money, store: WebStore(prefs)));
}

class MojitsumiApp extends StatelessWidget {
  const MojitsumiApp({super.key, required this.money, required this.store});
  final Monetization money;
  final WebStore store;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'もじつみ',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorSchemeSeed: const Color(0xFFD9472F), useMaterial3: true),
    home: GameScreen(money: money, store: store),
  );
}
