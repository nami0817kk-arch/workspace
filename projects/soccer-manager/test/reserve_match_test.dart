import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/logic/reserve_match_engine.dart';
import 'package:soccer_manager/models/attributes.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/models/team.dart';
import 'package:soccer_manager/state/game_state.dart';

/// リザーブ(Bチーム)。
///
/// これまで控えの選手にあったのは紅白戦だけで、実戦感覚を保つことしか
/// できなかった。若手を獲っても座っているだけで伸びず、不満が溜まる一方で、
/// 獲る・育てる・使うの輪が閉じていなかった。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Player make(
    String id, {
    int sharpness = 40,
    int happiness = 50,
    SquadStatus status = SquadStatus.prospect,
    Position position = Position.mc,
  }) {
    final p = Player(
      id: id,
      name: id,
      age: 20,
      position: position,
      potential: 85,
      matchSharpness: sharpness,
    );
    for (final k in AttributeKeys.all) {
      p.setAttributeValue(k, 50);
    }
    p.happiness = happiness;
    p.squadStatus = status;
    return p;
  }

  Team teamOf(List<Player> players, {List<String> startingXI = const []}) =>
      Team(id: 't', name: 'T', players: players, startingXI: startingXI);

  List<Player> bench(int n) =>
      [for (int i = 0; i < n; i++) make('b$i')];

  group('出場できる選手', () {
    test('人数が足りなければ試合は行われない', () {
      final team = teamOf(bench(ReserveMatchEngine.minPlayers - 1));
      expect(ReserveMatchEngine.play(team, opponentName: 'R'), isNull);
    });

    test('トップのスタメンは出ない', () {
      final players = bench(11);
      final team = teamOf(players, startingXI: [players.first.id]);

      final available = ReserveMatchEngine.availablePlayers(team);

      expect(available.map((p) => p.id), isNot(contains(players.first.id)),
          reason: 'トップで出ている選手がBチームにも出るのはおかしい');
    });

    test('負傷・代表招集・ローン放出中は出ない', () {
      final players = bench(11);
      players[0].injuryWeeks = 2;
      players[1].internationalDutyWeeksRemaining = 1;
      players[2].loanedOutWeeksRemaining = 4;
      final team = teamOf(players);

      final ids =
          ReserveMatchEngine.availablePlayers(team).map((p) => p.id).toSet();

      expect(ids, isNot(contains(players[0].id)));
      expect(ids, isNot(contains(players[1].id)));
      expect(ids, isNot(contains(players[2].id)));
    });

    test('出場停止の選手は出られる(リーグ戦の処分なので)', () {
      final players = bench(11);
      players[0].suspendedMatches = 2;
      final team = teamOf(players);

      expect(
        ReserveMatchEngine.availablePlayers(team).map((p) => p.id),
        contains(players[0].id),
      );
    });

    test('実戦感覚が低い選手から優先して出る', () {
      final players = [
        for (int i = 0; i < 14; i++) make('p$i', sharpness: 20 + i * 5),
      ];
      final team = teamOf(players);

      final result = ReserveMatchEngine.play(team, opponentName: 'R')!;
      final played = result.performances.map((p) => p.player.id).toSet();

      expect(played, contains('p0'), reason: '一番鈍っている選手が出ていない');
      expect(played, isNot(contains('p13')),
          reason: '一番仕上がっている選手まで出す必要はない');
    });
  });

  group('出場の効果', () {
    test('実戦感覚が戻る', () {
      final players = bench(11);
      final before = players.first.matchSharpness;

      ReserveMatchEngine.play(teamOf(players), opponentName: 'R');

      expect(players.first.matchSharpness, greaterThan(before));
    });

    test('疲労も溜まる(ただ出せば得ではない)', () {
      final players = bench(11);
      final before = players.first.fatigue;

      ReserveMatchEngine.play(teamOf(players), opponentName: 'R');

      expect(players.first.fatigue, greaterThan(before));
    });

    test('育成枠の選手は、出場で不満が和らぐ', () {
      final players = [
        for (int i = 0; i < 11; i++)
          make('p$i', happiness: 50, status: SquadStatus.prospect),
      ];

      ReserveMatchEngine.play(teamOf(players), opponentName: 'R');

      expect(players.first.happiness, greaterThan(50));
    });

    test('キープレイヤーをBチームに置くと、逆に不満が増える', () {
      // 出せば必ず良い作りにはしない。立場を約束した選手にとって
      // Bチーム行きは降格であって、出場機会が増えたこととは別の話。
      final players = [
        make('key', happiness: 50, status: SquadStatus.keyPlayer),
        for (int i = 0; i < 10; i++)
          make('p$i', happiness: 50, status: SquadStatus.prospect),
      ];

      ReserveMatchEngine.play(teamOf(players), opponentName: 'R');

      expect(players.first.happiness, lessThan(50));
      expect(players.last.happiness, greaterThan(50),
          reason: '同じ試合でも、立場によって受け取り方が違うはず');
    });
  });

  test('週次トレーニングでリザーブの試合が行われる', () async {
    final game = GameState();
    await game.startNewGame('テストFC');

    await game.runWeeklyTraining();

    expect(game.lastReserveMatch, isNotNull,
        reason: '通常のスカッド人数ならリザーブの試合が成立するはず');
    expect(game.lastReserveMatch!.performances, isNotEmpty);
    // 二重取りを避けるため、リザーブが行われた週は紅白戦を行わない。
    expect(game.lastPracticeMatchCount, 0);
  });
}
