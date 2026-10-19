import 'dart:math';

import 'package:baseball_manager/game/path.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:baseball_manager/game/season.dart';
import 'package:flutter_test/flutter_test.dart';

Player _p(Role role, int v) => Player(
      name: 't',
      role: role,
      age: 17,
      potential: 50,
      abilities: {for (final a in abilitiesOf(role)) a: v},
    );

Tournament _t(Player p, int team, int seed) => playTournament(p,
    teamLevel: team, opponents: const [40, 45, 50, 55, 60], rng: Random(seed));

double _avgAch(Player p, int team) {
  var s = 0.0;
  for (var i = 0; i < 300; i++) {
    s += _t(p, team, i).achievement;
  }
  return s / 300;
}

void main() {
  test('実績は0〜100に収まる', () {
    for (var i = 0; i < 100; i++) {
      for (final role in Role.values) {
        final a = _t(_p(role, 60), 50, i).achievement;
        expect(a, inInclusiveRange(0, 100));
      }
    }
  });

  test('強い選手ほど実績が高い', () {
    expect(_avgAch(_p(Role.batter, 85), 50),
        greaterThan(_avgAch(_p(Role.batter, 30), 50)));
    expect(_avgAch(_p(Role.pitcher, 85), 50),
        greaterThan(_avgAch(_p(Role.pitcher, 30), 50)));
  });

  test('チームが強いほど勝ち上がる', () {
    expect(_avgAch(_p(Role.batter, 60), 80),
        greaterThan(_avgAch(_p(Role.batter, 60), 30)));
  });

  test('打者は投手成績を、投手は打撃成績を持たない。二刀流は両方', () {
    final b = playGame(_p(Role.batter, 60), 50, Random(1));
    final p = playGame(_p(Role.pitcher, 60), 50, Random(1));
    final t = playGame(_p(Role.twoWay, 60), 50, Random(1));
    expect(b.faced, 0);
    expect(p.atBats + p.walks, 0);
    expect(t.faced, greaterThan(0));
    expect(t.atBats + t.walks, greaterThan(0));
  });

  test('スタミナが低い投手は対戦数が少ない', () {
    final lo = Player(
        name: 'a',
        role: Role.pitcher,
        age: 17,
        potential: 50,
        abilities: {
          Ability.stuff: 60,
          Ability.control: 60,
          Ability.stamina: 10
        });
    final hi = Player(
        name: 'a',
        role: Role.pitcher,
        age: 17,
        potential: 50,
        abilities: {
          Ability.stuff: 60,
          Ability.control: 60,
          Ability.stamina: 90
        });
    expect(playGame(lo, 50, Random(1)).faced,
        lessThan(playGame(hi, 50, Random(1)).faced));
  });

  test('実績がドラフトに効く(同じ能力でも優勝した選手のほうが有利)', () {
    final p = _p(Role.batter, 70);
    expect(draftScore(p, 90), greaterThan(draftScore(p, 20)));
  });

  test('負けたらそこで終わる(勝ち上がりは対戦数以下)', () {
    for (var i = 0; i < 50; i++) {
      final t = _t(_p(Role.batter, 20), 20, i);
      expect(t.roundsWon, lessThanOrEqualTo(t.rounds));
    }
  });

  group('指標', () {
    // 500打数150安打(二塁打30・三塁打3・本塁打25)、四球60、三振100、打点90、盗塁15
    const l = Line(
      games: 140,
      atBats: 500,
      hits: 150,
      totalBases: 150 + 30 + 2 * 3 + 3 * 25,
      walks: 60,
      homeRuns: 25,
      doubles: 30,
      triples: 3,
      battingStrikeouts: 100,
      rbi: 90,
      stolenBases: 15,
    );

    test('打者の指標を、式どおりに出す', () {
      expect(l.battingAverage, closeTo(0.300, 1e-9));
      expect(l.onBase, closeTo(210 / 560, 1e-9));
      expect(l.slugging, closeTo(261 / 500, 1e-9));
      expect(l.isolatedPower, closeTo(261 / 500 - 0.3, 1e-9));
      expect(l.walkRate, closeTo(60 / 560, 1e-9));
      expect(l.strikeoutRate, closeTo(100 / 560, 1e-9));
      expect(l.walkPerStrikeout, closeTo(0.6, 1e-9));
      expect(l.opsPlus, (100 * l.ops! / leagueOps).round());
      expect(l.opsPlus, greaterThan(100));
    });

    test('投手の指標を、式どおりに出す', () {
      // 180回(540アウト)、被安打150、与四球50、奪三振200、被本塁打20
      const p = Line(
        faced: 740,
        outs: 540,
        strikeouts: 200,
        walksGiven: 50,
        hitsAllowed: 150,
        homeRunsAllowed: 20,
        wins: 14,
        losses: 6,
        starts: 28,
      );
      expect(p.whip, closeTo((50 + 150) / 180, 1e-9));
      expect(p.strikeoutsPer9, closeTo(200 * 9 / 180, 1e-9));
      expect(p.walksPer9, closeTo(50 * 9 / 180, 1e-9));
      expect(p.homeRunsPer9, closeTo(20 * 9 / 180, 1e-9));
      expect(p.strikeoutPerWalk, closeTo(4.0, 1e-9));
      expect(p.battingAverageAgainst, closeTo(150 / 690, 1e-9));
      expect(p.winRate, closeTo(0.7, 1e-9));
    });

    test('分母が0のときは null(「-」と表示)', () {
      const e = Line();
      expect(e.onBase, isNull);
      expect(e.opsPlus, isNull);
      expect(e.whip, isNull);
      expect(e.eraPlus, isNull);
      expect(e.walkPerStrikeout, isNull);
      expect(e.strikeoutPerWalk, isNull);
      expect(e.winRate, isNull);
    });

    test('足し算・保存・読み直しで、新しい項目も保たれる。古い記録は0', () {
      final sum = l + l;
      expect(sum.rbi, 180);
      expect(sum.stolenBases, 30);
      expect(sum.battingStrikeouts, 200);
      final back = Line.fromJson(l.toJson());
      expect(back.doubles, 30);
      expect(back.triples, 3);
      expect(back.rbi, 90);
      final old = Line.fromJson({'games': 3, 'atBats': 10, 'hits': 3});
      expect(old.rbi, 0);
      expect(old.stolenBases, 0);
      expect(old.doubles, 0);
      expect(l.withDecision(win: true).rbi, 90);
    });

    test('シーズンの成績は現実的: 強いほど指標が良く、俊足は盗塁が多い', () {
      Line season(int v, {int speed = 0}) {
        final p = Player(
            name: 't',
            role: Role.batter,
            age: 27,
            potential: 50,
            abilities: {
              for (final a in batterAbilities)
                a: a == Ability.speed && speed > 0 ? speed : v
            });
        var t = const Line();
        for (var s = 0; s < 40; s++) {
          t += playLeagueSeason(p,
                  teamLevel: 65,
                  opponents: const [55, 60, 66, 72, 78],
                  rng: Random(s))
              .line;
        }
        return t;
      }

      final weak = season(45), strong = season(85);
      expect(strong.opsPlus!, greaterThan(weak.opsPlus!));
      expect(strong.rbi, greaterThan(weak.rbi));
      expect(strong.strikeoutRate!, lessThan(weak.strikeoutRate!));
      final fast = season(60, speed: 95), slow = season(60, speed: 25);
      expect(fast.stolenBases, greaterThan(slow.stolenBases));
      // 1シーズンあたりの打点は現実的な範囲
      expect(strong.rbi / 40, inInclusiveRange(40, 160));
    });
  });
}
