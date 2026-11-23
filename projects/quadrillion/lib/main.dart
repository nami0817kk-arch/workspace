import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ui/app.dart';
import 'ui/controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 縦画面だけ
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // 同梱フォント(OFL)のライセンス文を「ライセンス」画面に載せる。OFL は同梱時に添付を求めている
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(['Noto Sans JP'], await rootBundle.loadString('assets/fonts/OFL-NotoSansJP.txt'));
  });
  final prefs = await SharedPreferences.getInstance();
  runApp(QuadrillionApp(controller: GameController(prefs: prefs)));
}
