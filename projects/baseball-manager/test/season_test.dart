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
    expect(_avgAch(_p(Role.batter, 85), 50), greaterThan(_avgAch(_p(Role.batter, 30), 50)));
    expect(_avgAch(_p(Role.pitcher, 85), 50), greaterThan(_avgAch(_p(Role.pitcher, 30), 50)));
  });

  test('チームが強いほど勝ち上がる', () {
    expect(_avgAch(_p(Role.batter, 60), 80), greaterThan(_avgAch(_p(Role.batter, 60), 30)));
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
    final lo = Player(name: 'a', role: Role.pitcher, age: 17, potential: 50,
        abilities: {Ability.stuff: 60, Ability.control: 60, Ability.stamina: 10});
    final hi = Player(name: 'a', role: Role.pitcher, age: 17, potential: 50,
        abilities: {Ability.stuff: 60, Ability.control: 60, Ability.stamina: 90});
    expect(playGame(lo, 50, Random(1)).faced, lessThan(playGame(hi, 50, Random(1)).faced));
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
}
