import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:soccer_manager/logic/player_generator.dart';
import 'package:soccer_manager/logic/youth_league_engine.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/models/youth_league.dart';

/// ユースの年間リーグの検査。
///
/// 練習試合は毎週あったが勝敗が何にも残らず、「今年のユースはどうだったか」
/// が言えなかった。順位表が実際に積み上がること、自クラブの行だけが埋まる
/// 片側だけの表にならないことを見る。
void main() {
  YouthLeague make({int average = 50}) =>
      YouthLeagueEngine.create(prospectAverage: average);

  test('自クラブを含む8チームで、2回戦総当たりの節数になる', () {
    final league = make();
    expect(league.standings.length, YouthLeague.teamCount);
    expect(league.standings.where((s) => s.isUser).length, 1);
    expect(league.opponentOrder.length, YouthLeague.matchdayCount);
    expect(YouthLeague.matchdayCount, 14);
  });

  test('相手の強さは自クラブのユースの水準から散らばる', () {
    final league = make(average: 60);
    for (final s in league.standings.where((s) => !s.isUser)) {
      expect(s.strength,
          inInclusiveRange(60 - YouthLeagueEngine.strengthSpread, 60 + YouthLeagueEngine.strengthSpread));
    }
  });

  test('1節ごとに全チームの試合数が増える', () {
    final league = make();
    YouthLeagueEngine.recordUserResult(league, goalsFor: 2, goalsAgainst: 1);

    expect(league.matchday, 1);
    for (final s in league.standings) {
      expect(s.played, 1, reason: '${s.name} が試合をしていない');
    }
  });

  test('自クラブの勝敗と得失点が記録される', () {
    final league = make();
    YouthLeagueEngine.recordUserResult(league, goalsFor: 3, goalsAgainst: 0);
    final me = league.userStanding;
    expect(me.won, 1);
    expect(me.goalsFor, 3);
    expect(me.goalsAgainst, 0);
    expect(me.points, 3);
  });

  test('全節を終えると完了し、それ以上進まない', () {
    final league = make();
    for (var i = 0; i < YouthLeague.matchdayCount; i++) {
      expect(league.isComplete, isFalse);
      YouthLeagueEngine.recordUserResult(league, goalsFor: 1, goalsAgainst: 1);
    }
    expect(league.isComplete, isTrue);
    expect(league.nextOpponent, isNull);
    expect(
      YouthLeagueEngine.recordUserResult(league, goalsFor: 5, goalsAgainst: 0),
      isNull,
      reason: '完了後も記録できてしまっている',
    );
    expect(league.userStanding.played, YouthLeague.matchdayCount);
  });

  test('順位は勝点 → 得失点差 → 得点の順で決まる', () {
    final league = make();
    final a = league.standings[1]
      ..won = 3
      ..goalsFor = 6
      ..goalsAgainst = 3
      ..played = 3;
    final b = league.standings[2]
      ..won = 3
      ..goalsFor = 9
      ..goalsAgainst = 3
      ..played = 3;
    expect(league.sorted.indexOf(b), lessThan(league.sorted.indexOf(a)));
  });

  test('セーブの往復で順位表が保たれる', () {
    final league = make();
    YouthLeagueEngine.recordUserResult(league, goalsFor: 2, goalsAgainst: 0);
    final restored =
        YouthLeague.fromJson(jsonDecode(jsonEncode(league.toJson())));

    expect(restored.matchday, league.matchday);
    expect(restored.standings.length, league.standings.length);
    expect(restored.userStanding.points, league.userStanding.points);
    expect(restored.nextOpponent?.name, league.nextOpponent?.name);
  });

  test('得点王は自クラブのユースの中から選ばれる', () {
    Player p(int goals) {
      final player = PlayerGenerator.generate(
        position: Position.st,
        ageOverride: 18,
        strengthTier: 50,
      );
      player.youthMatchGoals = goals;
      return player;
    }

    expect(YouthLeagueEngine.topScorer([p(0), p(0)]), isNull,
        reason: '誰も得点していないのに得点王が出ている');
    final players = [p(2), p(7), p(5)];
    expect(YouthLeagueEngine.topScorer(players)?.youthMatchGoals, 7);
  });
}
