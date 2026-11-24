import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game/game.dart';
import 'ui/app.dart';
import 'ui/controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 横画面だけ（1.1.0+25 から。iPhone も iPad も横）
  await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  // 本物の経済の統計（24か国×1980〜2025年）
  try {
    EconData.current = loadEcon(await rootBundle.loadString('assets/econ/econ.json'));
  } catch (_) {
    // 読めなければ内蔵の最小データで動く（game_real.dart の econData）
  }
  // 同梱フォント(OFL)のライセンス文を「ライセンス」画面に載せる。OFL は同梱時に添付を求めている
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(['Noto Sans JP'], await rootBundle.loadString('assets/fonts/OFL-NotoSansJP.txt'));
  });
  final prefs = await SharedPreferences.getInstance();
  runApp(QuadrillionApp(controller: GameController(prefs: prefs)));
}
