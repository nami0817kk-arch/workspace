import 'dart:math';

import 'package:baseball_manager/game/career.dart';
import 'package:baseball_manager/game/characters.dart';
import 'package:baseball_manager/game/game.dart';
import 'package:baseball_manager/game/life.dart';
import 'package:baseball_manager/game/path.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:flutter_test/flutter_test.dart';

Cast _cast({bool lover = false}) {
  final c = Cast.initial(Random(1), Role.batter, const {});
  if (lover) c.rotate(Stage.highSchool, Random(2), Role.batter, const {});
  return c;
}

Player _p() => Player(
      name: 't',
      role: Role.batter,
      age: 16,
      potential: 50,
      abilities: {for (final a in batterAbilities) a: 40},
    );

GameEvent _ev(String id) => events.firstWhere((e) => e.id == id);

void main() {
  test('出来事は20種類以上で、idは重複せず、どれにも2つ以上の選択肢がある', () {
    expect(events.length, greaterThanOrEqualTo(20));
    expect(events.map((e) => e.id).toSet().length, events.length);
    for (final e in events) {
      expect(e.text, isNotEmpty, reason: e.id);
      expect(e.choices.length, greaterThanOrEqualTo(2), reason: e.id);
      for (final c in e.choices) {
        expect(c.label, isNotEmpty, reason: e.id);
      }
    }
  });

  test('追加の出来事(取材・少年野球教室など)は、段階が合うときだけ、低い確率で起きる', () {
    final cast = Cast([]);
    for (final id in ['interview', 'baseball-class']) {
      final e = _ev(id);
      expect(e.weight, lessThan(1));
      expect(e.when!(Stage.pro, cast), isTrue);
      expect(e.when!(Stage.youth, cast), isFalse);
    }
    expect(_ev('school-festival').when!(Stage.juniorHigh, cast), isTrue);
    expect(_ev('school-festival').when!(Stage.pro, cast), isFalse);
    final seen = <String>{};
    final rng = Random(1);
    for (var k = 0; k < 4000; k++) {
      final e = drawEvent(rng, stage: Stage.youth, cast: cast);
      if (e != null) seen.add(e.id);
    }
    expect(seen, isNot(contains('interview')));
  });

  test('どの出来事も、どちらかの選択肢が全面的に有利にならない(特性・コツ・絆の利益があるものを除く)', () {
    // 特性の獲得(winter-menu)やコーチのコツ(coach-extra)は、ここで測れない利益がある。
    const exempt = {'winter-menu', 'coach-extra'};
    final p = _p();
    const c = Condition(fatigue: 50, morale: 50);
    for (final e in events) {
      if (exempt.contains(e.id)) continue;
      final scores = <List<double>>[];
      for (final ch in e.choices) {
        var ab = 0.0, fa = 0.0, mo = 0.0;
        const n = 100;
        for (var i = 0; i < n; i++) {
          final r = ch.risky != null
              ? ch.risky!(p, c, Ability.contact, Random(i))
              : ch.apply(p, c, Ability.contact);
          ab += abilitiesOf(Role.batter)
              .fold<int>(0, (s, a) => s + r.player.of(a) - p.of(a));
          fa += r.condition.fatigue - c.fatigue;
          mo += r.condition.morale - c.morale;
        }
        scores.add([ab / n, -fa / n, mo / n]);
      }
      for (var i = 0; i < scores.length; i++) {
        for (var j = 0; j < scores.length; j++) {
          if (i == j) continue;
          final geq = [
            for (var k = 0; k < 3; k++) scores[i][k] >= scores[j][k]
          ];
          final gt = [for (var k = 0; k < 3; k++) scores[i][k] > scores[j][k]];
          expect(geq.every((x) => x) && gt.any((x) => x), isFalse,
              reason:
                  '${e.id}: 「${e.choices[j].label}」は「${e.choices[i].label}」より全部で劣る');
        }
      }
    }
  });

  test('どの選択肢も、極端な状態でも体調・能力が範囲内に収まる(運しだいの選択肢も)', () {
    for (final e in events) {
      for (final ch in e.choices) {
        for (var s = 0; s < 30; s++) {
          for (final c in const [
            Condition(fatigue: 0, morale: 0),
            Condition(fatigue: 100, morale: 100)
          ]) {
            final r = ch.risky != null
                ? ch.risky!(_p(), c, Ability.contact, Random(s))
                : ch.apply(_p(), c, Ability.contact);
            expect(r.condition.fatigue, inInclusiveRange(0, 100), reason: e.id);
            expect(r.condition.morale, inInclusiveRange(0, 100), reason: e.id);
            expect(r.condition.injuredTerms, inInclusiveRange(0, 2),
                reason: e.id);
            for (final a in abilitiesOf(Role.batter)) {
              expect(r.player.of(a), inInclusiveRange(0, 99), reason: e.id);
            }
          }
        }
      }
    }
  });

  group('運しだいの選択肢', () {
    test('成功も失敗もあり、見積もりに近い確率で起きる', () {
      // 全力でアピール: 6割で成功(能力+2)。
      final ch = _ev('scout-visit').choices.first;
      expect(ch.risky, isNotNull);
      var ok = 0;
      const n = 2000;
      for (var s = 0; s < n; s++) {
        final r = ch.risky!(
            _p(), const Condition(morale: 50), Ability.contact, Random(s));
        if (r.player.of(Ability.contact) == 42) ok++;
      }
      expect(ok / n, inInclusiveRange(0.54, 0.66));
    });

    test('我慢して続けると、ときどき怪我をする', () {
      final ch = _ev('injury-scare').choices.last;
      var hurt = 0;
      for (var s = 0; s < 1000; s++) {
        final r =
            ch.risky!(_p(), const Condition(), Ability.contact, Random(s));
        if (r.condition.injured) hurt++;
      }
      expect(hurt / 1000, inInclusiveRange(0.24, 0.36));
      // 安全な選択肢は怪我しない。
      for (var s = 0; s < 100; s++) {
        final safe = _ev('injury-scare')
            .choices
            .first
            .apply(_p(), const Condition(), Ability.contact);
        expect(safe.condition.injured, isFalse);
      }
    });

    test('ゲームの中でも、乱数で結果が決まる(同じ乱数なら同じ)', () {
      Game g(int seed) {
        final x = Game.newGame(
            name: 't', role: Role.batter, rng: Random(seed), potential: 50);
        x.pendingEvent = _ev('big-chance');
        x.phase = Phase.event;
        x.resolveEvent(0);
        return x;
      }

      expect(g(3).player.abilities, g(3).player.abilities);
      final results = {for (var s = 0; s < 40; s++) g(s).condition.morale};
      expect(results.length, greaterThan(1)); // 成功と失敗の両方
    });
  });

  group('起きる条件', () {
    bool can(String id, Stage s, Cast c) =>
        _ev(id).when == null || _ev(id).when!(s, c);

    test('段階に合う出来事だけ', () {
      final c = _cast();
      expect(can('dad-catch', Stage.youth, c), isTrue);
      expect(can('dad-catch', Stage.pro, c), isFalse);
      expect(can('growth-spurt', Stage.juniorHigh, c), isTrue);
      expect(can('growth-spurt', Stage.highSchool, c), isFalse);
      expect(can('scout-visit', Stage.highSchool, c), isTrue);
      expect(can('scout-visit', Stage.youth, c), isFalse);
      expect(can('veteran-advice', Stage.pro, c), isTrue);
      expect(can('veteran-advice', Stage.highSchool, c), isFalse);
      expect(can('fan-letter', Stage.pro, c), isTrue);
      expect(can('fan-letter', Stage.juniorHigh, c), isFalse);
      expect(can('injury-scare', Stage.youth, c), isTrue); // 誰にでも
      expect(can('injury-scare', Stage.pro, c), isTrue);
    });

    test('相手が居るときだけ(恋人・仲間2人以上)', () {
      expect(can('lover-lunch', Stage.highSchool, _cast()), isFalse);
      expect(can('lover-lunch', Stage.highSchool, _cast(lover: true)), isTrue);
      expect(can('mate-quarrel', Stage.highSchool, _cast()), isTrue);
      final one = _cast()
        ..members
            .removeWhere((m) => m.kind == Kind.teammate && m.id != 'mate0');
      expect(can('mate-quarrel', Stage.highSchool, one), isFalse);
    });
  });

  group('同じ出来事が続かない', () {
    test('除外した出来事は選ばれない(候補が他にあれば)', () {
      final c = _cast();
      for (var s = 0; s < 400; s++) {
        final e = drawEvent(Random(s),
            share: 10, stage: Stage.youth, cast: c, exclude: 'rain-day');
        if (e != null) expect(e.id, isNot('rain-day'));
      }
    });

    test('最近起きた出来事は、他に候補があるうちは選ばれない', () {
      final c = _cast();
      final recent = {'rain-day', 'diet', 'friend', 'coach'};
      for (var s = 0; s < 400; s++) {
        final e = drawEvent(Random(s),
            share: 10, stage: Stage.youth, cast: c, recent: recent);
        if (e != null) expect(recent, isNot(contains(e.id)));
      }
    });

    test('ゲーム中、直近3回のうちに同じ出来事が重ならない(プロ)', () {
      for (var seed = 0; seed < 12; seed++) {
        final g = Game.newGame(
            name: 't', role: Role.batter, rng: Random(seed), potential: 95);
        final seen = <String>[];
        var steps = 0;
        while (g.phase != Phase.retired && steps++ < 4000) {
          g.autoSpend();
          switch (g.phase) {
            case Phase.term:
              g.choose(g.condition.fatigue >= 60 ? Plan.rest : Plan.train,
                  Ability.contact);
              if (g.phase == Phase.event && g.stage == Stage.pro) {
                final id = g.pendingEvent!.id;
                final lastThree =
                    seen.length < 3 ? seen : seen.sublist(seen.length - 3);
                expect(lastThree, isNot(contains(id)), reason: 'seed $seed');
                seen.add(id);
              }
            case Phase.event:
              g.resolveEvent(0);
            case Phase.pathChoice:
              g.chooseRoute(Course.university);
            case Phase.retired:
              break;
          }
        }
      }
    });

    test('ゲーム中、続けて同じ出来事は起きない', () {
      for (var seed = 0; seed < 20; seed++) {
        final g = Game.newGame(
            name: 't', role: Role.batter, rng: Random(seed), potential: 60);
        String? last;
        var steps = 0;
        while (g.phase != Phase.retired && steps++ < 600) {
          g.autoSpend();
          switch (g.phase) {
            case Phase.term:
              if (g.stage == Stage.pro && g.player.age >= 30) {
                g.retire();
              } else {
                g.choose(g.condition.fatigue >= 60 ? Plan.rest : Plan.train,
                    Ability.contact);
              }
            case Phase.event:
              final id = g.pendingEvent!.id;
              expect(id, isNot(last), reason: 'seed=$seed');
              last = id;
              g.resolveEvent(0);
            case Phase.pathChoice:
              g.chooseRoute(Course.university);
            case Phase.retired:
              break;
          }
        }
      }
    });

    test('一生のうちに、いろいろな出来事が起きる(15種類以上)', () {
      final seen = <String>{};
      for (var seed = 0; seed < 8; seed++) {
        final g = Game.newGame(
            name: 't', role: Role.batter, rng: Random(seed), potential: 90);
        var steps = 0;
        while (g.phase != Phase.retired && steps++ < 800) {
          g.autoSpend();
          switch (g.phase) {
            case Phase.term:
              if (g.stage == Stage.pro && g.player.age >= 33) {
                g.retire();
              } else {
                g.choose(g.condition.fatigue >= 60 ? Plan.rest : Plan.train,
                    Ability.contact);
              }
            case Phase.event:
              seen.add(g.pendingEvent!.id);
              g.resolveEvent(0);
            case Phase.pathChoice:
              g.chooseRoute(Course.university);
            case Phase.retired:
              break;
          }
        }
      }
      expect(seen.length, greaterThanOrEqualTo(15), reason: '$seen');
    });
  });
}
