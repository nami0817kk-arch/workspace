import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/l10n/app_localizations.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/logic/development_advisor.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/screens/player_detail_screen.dart';
import 'package:soccer_manager/state/game_state.dart';
import 'package:soccer_manager/state/settings_controller.dart';

/// 選手を開いたときに、その選手について手を打つべきことが見えるかの検査。
///
/// 同じ判定はトレーニング画面の提案カードにもあるが、選手を開いた人はその
/// 画面まで見に行かない。逆に、手を打つことが無いのに「問題ありません」と
/// 毎回書くと、本当に必要なときの一行が埋もれる。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => Tr.language = AppLanguage.system);

  Future<(GameState, SettingsController)> prepare(WidgetTester tester) async {
    late final GameState game;
    late final SettingsController settings;
    await tester.runAsync(() async {
      settings = SettingsController();
      await settings.init();
      game = GameState();
      await game.startNewGame('助言FC');
    });
    Tr.language = AppLanguage.japanese;
    return (game, settings);
  }

  Widget wrap(GameState game, SettingsController settings, Player p) =>
      MultiProvider(
        providers: [
          ChangeNotifierProvider<GameState>.value(value: game),
          ChangeNotifierProvider<SettingsController>.value(value: settings),
        ],
        child: MaterialApp(
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PlayerDetailScreen(playerId: p.id),
        ),
      );

  testWidgets('疲労が濃い選手を開くと、その指摘が出る', (tester) async {
    final (game, settings) = await prepare(tester);
    final p = game.userTeam.players.first;
    p.fatigue = DevelopmentAdvisor.fatigueThreshold + 10;

    await tester.pumpWidget(wrap(game, settings, p));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('疲労'), findsWidgets);
  });

  testWidgets('手を打つことが無ければ、助言の枠を出さない', (tester) async {
    final (game, settings) = await prepare(tester);
    // 指摘の条件をすべて外す。
    for (final p in game.userTeam.players) {
      p.fatigue = 0;
      p.matchSharpness = 100;
      p.mentorId = 'someone';
      p.potential = p.overall;
    }
    final p = game.userTeam.players.first;

    await tester.pumpWidget(wrap(game, settings, p));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // 「問題ありません」のような常時表示の文言を出していないこと。
    expect(find.textContaining('問題ありません'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('助言の判定は、選手ごとに絞り込める', () async {
    final game = GameState();
    await game.startNewGame('絞り込みFC');
    final team = game.userTeam;
    for (final p in team.players) {
      p.fatigue = 0;
    }
    final target = team.players.first
      ..fatigue = DevelopmentAdvisor.fatigueThreshold + 5;

    final mine = DevelopmentAdvisor.advise(team)
        .where((a) => a.playerId == target.id)
        .toList();
    expect(mine, isNotEmpty);
    expect(mine.every((a) => a.playerId == target.id), isTrue);
  });
}
