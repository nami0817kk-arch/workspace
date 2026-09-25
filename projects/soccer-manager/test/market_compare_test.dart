import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/l10n/app_localizations.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/screens/player_compare_screen.dart';
import 'package:soccer_manager/state/game_state.dart';
import 'package:soccer_manager/state/settings_controller.dart';

/// 市場の選手を比べられることの検査。
///
/// 買う判断は「誰と比べて良いか」で決まるのに、比較画面は自軍しか見て
/// いなかった。市場の選手を渡すと firstWhere が要素なしで投げて落ちる。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => Tr.language = AppLanguage.system);

  test('IDから、自軍以外の選手も見つけられる', () async {
    final game = GameState();
    await game.startNewGame('探索FC');

    expect(game.playerById(game.userTeam.players.first.id), isNotNull);
    expect(game.playerById(game.transferMarket.first.id), isNotNull,
        reason: '市場の選手が見つからない');
    if (game.scoutCandidates.isNotEmpty) {
      expect(game.playerById(game.scoutCandidates.first.id), isNotNull,
          reason: 'スカウト候補が見つからない');
    }
    expect(game.playerById('存在しないID'), isNull);
  });

  testWidgets('市場の選手どうしを比較しても落ちない', (tester) async {
    late final GameState game;
    late final SettingsController settings;
    await tester.runAsync(() async {
      settings = SettingsController();
      await settings.init();
      game = GameState();
      await game.startNewGame('比較FC');
    });
    Tr.language = AppLanguage.japanese;

    final market = game.transferMarket;
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<GameState>.value(value: game),
        ChangeNotifierProvider<SettingsController>.value(value: settings),
      ],
      child: MaterialApp(
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PlayerCompareScreen(
          playerAId: market[0].id,
          playerBId: market[1].id,
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    expect(find.text(market[0].name), findsWidgets);
  });

  testWidgets('居なくなった選手を渡されたら、落ちずに理由を出す', (tester) async {
    late final GameState game;
    late final SettingsController settings;
    await tester.runAsync(() async {
      settings = SettingsController();
      await settings.init();
      game = GameState();
      await game.startNewGame('消えたFC');
    });
    Tr.language = AppLanguage.japanese;

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<GameState>.value(value: game),
        ChangeNotifierProvider<SettingsController>.value(value: settings),
      ],
      child: MaterialApp(
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const PlayerCompareScreen(
          playerAId: 'もう居ない1',
          playerBId: 'もう居ない2',
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull, reason: '落ちている');
    expect(find.textContaining('見つかりませんでした'), findsOneWidget);
  });
}
