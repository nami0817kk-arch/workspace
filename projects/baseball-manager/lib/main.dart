import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'monetization/ad_service.dart';
import 'monetization/monetization.dart';
import 'monetization/purchase_service.dart';
import 'ui/app.dart';
import 'ui/backup_share.dart';
import 'ui/controller.dart';
import 'ui/sound.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 広告と購入の準備は待たない(起動を遅らせない)。準備が済むまで広告は出ず、購入の表示も出ない
  final money = Monetization(
    await SharedPreferences.getInstance(),
    ads: createAdService(),
    store: createPurchaseService(),
  );
  unawaited(money.start());
  runApp(BaseballManagerApp(
      controller: GameController(
          sound: AudioSound(),
          autoGuide: true,
          sharer: const SharePlusSharer(),
          money: money)));
}
