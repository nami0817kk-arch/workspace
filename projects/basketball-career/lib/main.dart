import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'monetization/ad_service.dart';
import 'monetization/monetization.dart';
import 'monetization/purchase_service.dart';
import 'ui/app.dart';
import 'ui/controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // 同梱フォント(OFL)のライセンス文を「ライセンス」画面に載せる。OFL は同梱時に添付を求めている
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(
        ['Noto Sans JP'], await rootBundle.loadString('assets/fonts/OFL-NotoSansJP.txt'));
  });
  final money = Monetization(await SharedPreferences.getInstance(),
      ads: createAdService(), store: createPurchaseService());
  // 広告SDKの準備は待たずに画面を出す(読み込みは裏で続く)
  unawaited(money.start());
  // 長く裏にいた後は手元の広告が期限切れになっている。戻ったら読み直す
  AppLifecycleListener(onResume: money.refreshAds);
  runApp(BasketballCareerApp(controller: GameController(money: money)));
}
