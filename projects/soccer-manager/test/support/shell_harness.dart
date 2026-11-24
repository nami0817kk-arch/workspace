// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/l10n/app_localizations.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/main.dart';
import 'package:soccer_manager/monetization/ad_service.dart';
import 'package:soccer_manager/monetization/monetization_controller.dart';
import 'package:soccer_manager/screens/home_screen.dart';
import 'package:soccer_manager/screens/main_shell.dart';
import 'package:soccer_manager/state/game_state.dart';
import 'package:soccer_manager/state/settings_controller.dart';
import 'package:soccer_manager/widgets/fm_panel.dart';
import 'package:soccer_manager/widgets/landscape_scale.dart';
import 'package:soccer_manager/widgets/shell_nav.dart';

import 'stub_purchase_service.dart';

/// 横画面のシェル(左メニュー・上の帯)を、テストの中で出すための道具。
/// iPhone 横の大きさ。
const shellPhone = Size(844, 390);

Future<GameState> pumpShell(
  WidgetTester tester, {
  bool en = false,
  Size size = shellPhone,
  Future<void> Function(GameState gs)? arrange,
}) async {
  addTearDown(tester.view.reset);
  tester.view.devicePixelRatio = 2;
  tester.view.physicalSize = size * 2;
  SharedPreferences.setMockInitialValues({});
  late final SettingsController settings;
  late final MonetizationController monetization;
  late final GameState game;
  await tester.runAsync(() async {
    settings = SettingsController();
    await settings.init();
    Tr.language = en ? AppLanguage.english : AppLanguage.japanese;
    monetization = MonetizationController(
        adService: NoOpAdService(), purchases: StubPurchaseService());
    await monetization.initialize();
    game = GameState();
    await game.startNewGame('Seiran FC');
    game.save!.firstRunGuideDismissed = true;
    if (arrange != null) await arrange(game);
  });
  addTearDown(() => Tr.language = AppLanguage.system);
  const app = SoccerManagerApp();
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<GameState>.value(value: game),
      ChangeNotifierProvider<SettingsController>.value(value: settings),
      ChangeNotifierProvider<MonetizationController>.value(value: monetization),
    ],
    child: MaterialApp(
      locale: Locale(en ? 'en' : 'ja'),
      theme: app.buildTheme(Brightness.light, boldText: false),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => LandscapeScale(
        child: FmThemeScope(
          dark: app.buildTheme(Brightness.dark, boldText: false),
          child: child!,
        ),
      ),
      home: const MainShell(),
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  return game;
}

/// シェルの行き先の口。
ShellNav shellNavOf(WidgetTester tester) => ShellNav.maybeOf(
    tester.element(find.byType(HomeScreen, skipOffstage: false)))!;

/// 切り替えの動きが終わるまで待つ。
Future<void> settleShell(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}
