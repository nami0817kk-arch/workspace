import 'dart:math';

import 'package:baseball_manager/game/game.dart';
import 'package:baseball_manager/game/life.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:flutter_test/flutter_test.dart';

Game _g() =>
    Game.newGame(name: 't', role: Role.batter, rng: Random(2), potential: 80);

void main() {
  test('同じ重点で練習を続けると連続が増え、3回で+2%、6回で+4%', () {
    final g = _g();
    expect(g.streakBonus, 1.0);
    var n = 0;
    while (g.focusStreak < 6 && n++ < 40) {
      g.autoSpend();
      if (g.phase == Phase.event) {
        g.resolveEvent(0);
        continue;
      }
      if (g.phase != Phase.term) break;
      g.choose(
          g.condition.fatigue >= 60 ? Plan.rest : Plan.train, Ability.contact);
    }
    expect(g.focusStreak, greaterThanOrEqualTo(3));
    expect(g.streakBonus, greaterThan(1.0));
    expect(g.lastFocus, Ability.contact);
  });
  test('重点を変えると連続は1に戻る', () {
    final g = _g();
    g.choose(Plan.train, Ability.contact);
    if (g.phase == Phase.event) g.resolveEvent(0);
    g.choose(Plan.train, Ability.power);
    expect(g.focusStreak, 1);
    expect(g.lastFocus, Ability.power);
  });
  test('保存と読み込みで連続が残る(古い保存は0)', () {
    final g = _g();
    g.choose(Plan.train, Ability.contact);
    final r = Game.fromJson(g.toJson(), Random(1));
    expect(r.focusStreak, 1);
    expect(r.lastFocus, Ability.contact);
    final j = g.toJson()
      ..remove('focusStreak')
      ..remove('lastFocus');
    expect(Game.fromJson(j, Random(1)).focusStreak, 0);
  });
  test('6回続けた先に、ときどき開眼する(+2)', () {
    var found = false;
    for (var sd = 0; sd < 60 && !found; sd++) {
      final g = Game.newGame(
          name: 't', role: Role.batter, rng: Random(sd), potential: 80);
      var n = 0;
      while (g.phase != Phase.retired && g.slot < 12 && n++ < 60 && !found) {
        g.autoSpend();
        if (g.phase == Phase.event) {
          g.resolveEvent(0);
          continue;
        }
        if (g.phase != Phase.term) break;
        g.choose(g.condition.fatigue >= 60 ? Plan.rest : Plan.train,
            Ability.contact);
        found = g.log.any((l) => l.contains('開眼した'));
      }
    }
    expect(found, isTrue);
  });
}
