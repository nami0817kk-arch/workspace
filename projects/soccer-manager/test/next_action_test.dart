import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/logic/next_action_advisor.dart';
import 'package:soccer_manager/logic/player_generator.dart';
import 'package:soccer_manager/logic/youth_departure_engine.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 「次にやること」の検査。
///
/// 画面は30以上あり、何から手を付ければよいか分からない。出すのは常に1件
/// だけで、損が確定しているものが先に来ること、無駄な催促をしないことを見る。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<GameState> newGame() async {
    final game = GameState();
    await game.startNewGame('助言FC');
    return game;
  }

  test('やることが無ければ何も出さない', () async {
    final game = await newGame();
    game.save!.trainingDoneThisWeek = true;
    game.save!.budget = 5000;
    // 契約切れ間近の主力とユースの流出候補を取り除く。
    for (final p in game.userTeam.players) {
      p.contractYearsRemaining = 3;
    }
    game.save!.youthProspects.clear();

    expect(NextActionAdvisor.top(game.save!, game.userTeam), isNull);
  });

  test('今週のトレーニングが残っていれば促す', () async {
    final game = await newGame();
    game.save!.trainingDoneThisWeek = false;
    game.save!.budget = 5000;
    for (final p in game.userTeam.players) {
      p.contractYearsRemaining = 3;
    }
    game.save!.youthProspects.clear();

    final action = NextActionAdvisor.top(game.save!, game.userTeam);
    expect(action?.target, NextActionTarget.training);
  });

  test('資金マイナスは、ほかの用事を追い越す', () async {
    final game = await newGame();
    game.save!.trainingDoneThisWeek = false; // 普通ならこちらが先
    game.save!.budget = -100;

    final action = NextActionAdvisor.top(game.save!, game.userTeam);
    expect(action?.target, NextActionTarget.finance);
    expect(action?.urgent, isTrue);
  });

  test('ユースの流出候補がいれば知らせる', () async {
    final game = await newGame();
    game.save!.trainingDoneThisWeek = true;
    game.save!.budget = 5000;
    for (final p in game.userTeam.players) {
      p.contractYearsRemaining = 3;
    }
    game.save!.youthProspects
      ..clear()
      ..add(PlayerGenerator.generate(
        position: Position.st,
        ageOverride: YouthDepartureEngine.departureAge,
        strengthTier: 50,
      ));

    final action = NextActionAdvisor.top(game.save!, game.userTeam);
    expect(action?.target, NextActionTarget.youth);
  });

  test('契約切れ間近でも、控えの選手では催促しない', () async {
    final game = await newGame();
    game.save!.trainingDoneThisWeek = true;
    game.save!.budget = 5000;
    game.save!.youthProspects.clear();

    final players = game.userTeam.players;
    for (final p in players) {
      p.contractYearsRemaining = 3;
    }
    // 一番弱い選手だけ契約1年にする。平均を下回るので催促しない。
    final weakest = players.reduce((a, b) => a.overall <= b.overall ? a : b);
    weakest.contractYearsRemaining = 1;

    expect(NextActionAdvisor.top(game.save!, game.userTeam), isNull,
        reason: '控えの契約まで急かしている');

    // 一番強い選手なら催促する。
    final best = players.reduce((a, b) => a.overall >= b.overall ? a : b);
    best.contractYearsRemaining = 1;
    final action = NextActionAdvisor.top(game.save!, game.userTeam);
    expect(action?.target, NextActionTarget.squad);
  });

  test('出すのは常に1件', () async {
    final game = await newGame();
    game.save!.budget = -100;
    game.save!.trainingDoneThisWeek = false;

    final all = NextActionAdvisor.all(game.save!, game.userTeam);
    expect(all.length, greaterThan(1), reason: '検査の前提が崩れている');
    expect(NextActionAdvisor.top(game.save!, game.userTeam), isNotNull);
  });
}
