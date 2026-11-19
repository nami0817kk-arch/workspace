import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/l10n/app_localizations.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/screens/club_detail_screen.dart';
import 'package:soccer_manager/state/game_state.dart';
import 'package:soccer_manager/state/settings_controller.dart';

/// 他のクラブのページの検査。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => Tr.language = AppLanguage.system);

  testWidgets('順位・顔ぶれ(見立て)・注目の星が出て、星で注目に入る', (tester) async {
    late final GameState game;
    late final SettingsController settings;
    await tester.runAsync(() async {
      settings = SettingsController();
      await settings.init();
      game = GameState();
      await game.startNewGame('ページFC');
    });
    Tr.language = AppLanguage.japanese;
    tester.view.physicalSize = const Size(2400, 1200);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final other = game.save!.league.teams
        .firstWhere((t) => t.id != game.save!.userTeamId);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<GameState>.value(value: game),
        ChangeNotifierProvider<SettingsController>.value(value: settings),
      ],
      child: MaterialApp(
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ClubDetailScreen(teamId: other.id),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text(other.name), findsWidgets);
    expect(find.text('顔ぶれ(見立て)'), findsOneWidget);
    expect(find.textContaining('見えている度合い'), findsWidgets);
    final before = game.save!.watchlistPlayerIds.length;
    await tester.tap(find.byIcon(Icons.star_border).first);
    await tester.pump();
    expect(game.save!.watchlistPlayerIds.length, before + 1);
    await tester.pump(GameState.persistDebounce);
  });

  testWidgets('見つからないクラブなら、その旨を出す', (tester) async {
    late final GameState game;
    late final SettingsController settings;
    await tester.runAsync(() async {
      settings = SettingsController();
      await settings.init();
      game = GameState();
      await game.startNewGame('ページFC');
    });
    Tr.language = AppLanguage.japanese;
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<GameState>.value(value: game),
        ChangeNotifierProvider<SettingsController>.value(value: settings),
      ],
      child: const MaterialApp(home: ClubDetailScreen(teamId: 'nope')),
    ));
    await tester.pumpAndSettle();
    expect(find.text('このクラブは見つかりません。'), findsOneWidget);
  });
}
