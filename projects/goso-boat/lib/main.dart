import 'dart:async';

import 'package:flutter/foundation.dart' show LicenseEntryWithLineBreaks, LicenseRegistry;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/progress.dart';
import 'app/settings.dart';
import 'l10n/app_localizations.dart';
import 'monetization/ad_service.dart';
import 'monetization/monetization.dart';
import 'monetization/purchase_service.dart';
import 'ui/menu_screens.dart';
import 'ui/palette.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // 同梱フォント（OFL）のライセンス文を「ライセンス」画面に載せる。OFL は同梱時に添付を求めている
  LicenseRegistry.addLicense(() async* {
    for (final (name, file) in [('M PLUS Rounded 1c', 'OFL-MPLUSRounded1c.txt'), ('Noto Sans JP', 'OFL-NotoSansJP.txt')]) {
      yield LicenseEntryWithLineBreaks([name], await rootBundle.loadString('assets/fonts/$file'));
    }
  });
  final progress = await Progress.open(await loadLevels());
  final money = Monetization(await SharedPreferences.getInstance(), ads: createAdService(), store: createPurchaseService());
  // 広告SDKの準備は待たずに画面を出す（読み込みは裏で続く）
  unawaited(money.start());
  runApp(GosoBoatApp(progress: progress, money: money, settings: GameSettings(await SharedPreferences.getInstance())));
}

class GosoBoatApp extends StatelessWidget {
  const GosoBoatApp({super.key, required this.progress, required this.money, required this.settings, this.locale});
  final Progress progress;
  final Monetization money;
  final GameSettings settings;

  /// テスト用に言語を固定する。null なら端末の言語（日本語以外は英語）。
  final Locale? locale;

  @override
  Widget build(BuildContext context) => MaterialApp(
        onGenerateTitle: (c) => AppLocalizations.of(c)!.appTitle,
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // 日本語の端末は日本語、それ以外はすべて英語
        localeResolutionCallback: (device, _) =>
            device?.languageCode == 'ja' ? const Locale('ja') : const Locale('en'),
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Palette.river, surface: Palette.sky),
          scaffoldBackgroundColor: Palette.sky,
          fontFamily: 'Goso',
          useMaterial3: true,
        ),
        // 文字の拡大は1.3倍まで（それ以上は画面が崩れる）。iPad など幅の広い画面では中央に寄せる
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          return AppScope(
            settings: settings,
            child: MediaQuery(
              data: mq.copyWith(textScaler: mq.textScaler.clamp(maxScaleFactor: 1.3)),
              child: ColoredBox(
                color: Palette.sky,
                child: Center(
                  child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: child),
                ),
              ),
            ),
          );
        },
        home: HomeScreen(progress: progress, money: money),
      );
}
