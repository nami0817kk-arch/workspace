import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/l10n/app_localizations.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/logic/youth_league_engine.dart';
import 'package:soccer_manager/screens/fixtures_screen.dart';
import 'package:soccer_manager/state/game_state.dart';
import 'package:soccer_manager/state/settings_controller.dart';
import 'package:soccer_manager/widgets/youth_league_table.dart';

/// ユースリーグが日程・順位表の画面からも見えることの検査。
///
/// 順位表を見に来た流れで目に入らないと、ユース画面を開く人しか存在を知れない。
/// 一方で、有望株が1人も居ない年には順位表そのものが無いので、空のタブを
/// 増やしてはいけない。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => Tr.language = AppLanguage.system);

  Future<Widget> wrap(WidgetTester tester, GameState game) async {
    late final SettingsController settings;
    await tester.runAsync(() async {
      settings = SettingsController();
      await settings.init();
    });
    Tr.language = AppLanguage.japanese;
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<GameState>.value(value: game),
        ChangeNotifierProvider<SettingsController>.value(value: settings),
      ],
      child: MaterialApp(
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const FixturesScreen(),
      ),
    );
  }

  testWidgets('ユースリーグがある年は、タブから順位表を見られる', (tester) async {
    late final GameState game;
    await tester.runAsync(() async {
      game = GameState();
      await game.startNewGame('日程FC');
    });
    game.save!.youthLeague = YouthLeagueEngine.create(prospectAverage: 50);

    await tester.pumpWidget(await wrap(tester, game));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('ユース'), findsOneWidget);

    await tester.tap(find.text('ユース'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(YouthLeagueTable), findsOneWidget);
  });

  testWidgets('ユースリーグが無い年は、タブを増やさない', (tester) async {
    late final GameState game;
    await tester.runAsync(() async {
      game = GameState();
      await game.startNewGame('日程FC2');
    });
    game.save!.youthLeague = null;

    await tester.pumpWidget(await wrap(tester, game));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('ユース'), findsNothing,
        reason: '中身の無いタブが増えている');
  });
}
