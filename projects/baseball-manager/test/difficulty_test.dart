import 'dart:convert';
import 'dart:math';

import 'package:baseball_manager/game/career.dart';
import 'package:baseball_manager/game/difficulty.dart';
import 'package:baseball_manager/game/game.dart';
import 'package:baseball_manager/game/life.dart';
import 'package:baseball_manager/game/path.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:baseball_manager/game/snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

Player _p(int v) => Player(
      name: 't',
      role: Role.batter,
      age: 18,
      potential: 50,
      abilities: {for (final a in batterAbilities) a: v},
    );

void main() {
  test('やさしいほど経験点が多く、ドラフトの合格ラインが低い(順序が逆転しない)', () {
    expect(Difficulty.easy.expMultiplier,
        greaterThan(Difficulty.normal.expMultiplier));
    expect(Difficulty.normal.expMultiplier,
        greaterThan(Difficulty.hard.expMultiplier));
    expect(Difficulty.easy.draftShift, lessThan(Difficulty.normal.draftShift));
    expect(Difficulty.normal.draftShift, lessThan(Difficulty.hard.draftShift));
    expect(Difficulty.normal.expMultiplier, 1.0);
    expect(Difficulty.normal.draftShift, 0);
    for (final d in Difficulty.values) {
      expect(d.label, isNotEmpty);
      expect(d.description, isNotEmpty);
    }
  });

  test('名前から読める。知らない名前・null はふつう', () {
    expect(Difficulty.parse('hard'), Difficulty.hard);
    expect(Difficulty.parse('easy'), Difficulty.easy);
    expect(Difficulty.parse('zzz'), Difficulty.normal);
    expect(Difficulty.parse(null), Difficulty.normal);
  });

  test('ドラフトの指名されやすさが、難しさで変わる', () {
    final p = _p(58); // ふつうの境目あたり
    double rate(double shift) {
      var n = 0;
      for (var s = 0; s < 2000; s++) {
        if (isDrafted(p, 40, Random(s), lineShift: shift)) n++;
      }
      return n / 2000;
    }

    expect(rate(Difficulty.easy.draftShift),
        greaterThan(rate(Difficulty.normal.draftShift)));
    expect(rate(Difficulty.normal.draftShift),
        greaterThan(rate(Difficulty.hard.draftShift)));
    expect(draftChance(p, 40, lineShift: -10),
        greaterThan(draftChance(p, 40, lineShift: 10)));
  });

  test('同じ操作でも、やさしいほど経験点が多く貯まる(平均)', () {
    double mean(Difficulty d) {
      var t = 0.0;
      for (var s = 0; s < 60; s++) {
        final g = Game.newGame(
            name: 't',
            role: Role.batter,
            rng: Random(s),
            potential: 60,
            difficulty: d);
        g.choose(Plan.train, Ability.contact);
        t += g.lastGain.values.fold(0, (a, b) => a + b);
      }
      return t / 60;
    }

    expect(mean(Difficulty.easy), greaterThan(mean(Difficulty.normal)));
    expect(mean(Difficulty.normal), greaterThan(mean(Difficulty.hard)));
  });

  test('一生ずっと変わらず、保存して読み直せる。古いセーブはふつう。写しにも残る', () {
    final g = Game.newGame(
        name: 't',
        role: Role.batter,
        rng: Random(1),
        difficulty: Difficulty.hard);
    expect(g.difficulty, Difficulty.hard);
    for (var i = 0; i < 8; i++) {
      g.phase == Phase.event
          ? g.resolveEvent(0)
          : g.choose(Plan.rest, Ability.contact);
    }
    expect(g.difficulty, Difficulty.hard);
    final q = Game.fromJson(
        jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>, Random(1));
    expect(q.difficulty, Difficulty.hard);
    expect(Game.fromJson({}, Random(1)).difficulty, Difficulty.normal);
    final s = PlayerSnapshot.fromGame(g);
    expect(s.difficulty, Difficulty.hard);
    expect(PlayerSnapshot.fromJson(s.toJson()).difficulty, Difficulty.hard);
    expect(PlayerSnapshot.fromJson({}).difficulty, Difficulty.normal);
  });

  test('一生を通した結果も、やさしい > ふつう > むずかしい の順にプロへ入りやすい', () {
    double proRate(Difficulty d) {
      var n = 0;
      const total = 60;
      for (var seed = 0; seed < total; seed++) {
        final g = Game.newGame(
            name: 't',
            role: Role.batter,
            rng: Random(seed),
            potential: 60,
            difficulty: d);
        var steps = 0;
        while (g.phase != Phase.retired) {
          if (++steps > 4000) fail('終わらない');
          g.autoSpend();
          switch (g.phase) {
            case Phase.term:
              if (g.stage == Stage.pro) {
                g.retire();
              } else {
                g.choose(g.condition.fatigue >= 60 ? Plan.rest : Plan.train,
                    Ability.contact);
              }
            case Phase.event:
              g.resolveEvent(0);
            case Phase.pathChoice:
              g.chooseRoute(Course.university);
            case Phase.retired:
              break;
          }
        }
        if (g.ending!.madePro) n++;
      }
      return n / total;
    }

    final e = proRate(Difficulty.easy),
        n = proRate(Difficulty.normal),
        h = proRate(Difficulty.hard);
    expect(e, greaterThan(n));
    expect(n, greaterThan(h));
  });
}
