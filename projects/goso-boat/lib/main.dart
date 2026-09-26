import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app/progress.dart';
import 'l10n/app_localizations.dart';
import 'ui/menu_screens.dart';
import 'ui/palette.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final progress = await Progress.open(await loadLevels());
  runApp(GosoBoatApp(progress: progress));
}

class GosoBoatApp extends StatelessWidget {
  const GosoBoatApp({super.key, required this.progress, this.locale});
  final Progress progress;

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
        home: HomeScreen(progress: progress),
      );
}
