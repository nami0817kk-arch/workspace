import 'dart:math';

import 'package:baseball_manager/game/exp.dart';
import 'package:baseball_manager/game/life.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:baseball_manager/game/season.dart';
import 'package:baseball_manager/game/training.dart';
import 'package:flutter_test/flutter_test.dart';

Player _p([int v = 40]) => Player(
      name: 't',
      role: Role.batter,
      age: 14,
      potential: 60,
      abilities: {for (final a in batterAbilities) a: v},
    );

/// 1年(4季節)を同じ過ごし方で n 回回して、貯まった経験点(全種類)の平均。
double _gain(Plan act, {int n = 300}) {
  var tot = 0.0;
  for (var s = 0; s < n; s++) {
    final rng = Random(s);
    var c = const Condition();
    for (var t = 0; t < 4; t++) {
      final r = playTerm(_p(), c, act, Ability.power, rng);
      c = r.condition;
      tot += r.exp.values.fold(0, (a, b) => a + b);
    }
  }
  return tot / n;
}

void main() {
  balanceChecks();
  injuryChecks();
  _outcomeTests();
  test('特訓は練習より伸びるが、疲れる', () {
    expect(_gain(Plan.special), greaterThan(_gain(Plan.train)));
    final t =
        playTerm(_p(), const Condition(), Plan.train, Ability.power, Random(1));
    final s = playTerm(
        _p(), const Condition(), Plan.special, Ability.power, Random(1));
    expect(s.condition.fatigue, greaterThan(t.condition.fatigue));
  });

  test('休養と交流は疲れ・気持ちを回復させる', () {
    const tired = Condition(fatigue: 80, morale: 30);
    final r = playTerm(_p(), tired, Plan.rest, Ability.power, Random(1));
    expect(r.condition.fatigue, lessThan(80));
    final s = playTerm(_p(), tired, Plan.social, Ability.power, Random(1));
    expect(s.condition.morale, greaterThan(30));
  });

  test('練習試合は重点を決めず、全体に経験点が貯まる', () {
    final r =
        playTerm(_p(), const Condition(), Plan.match, Ability.power, Random(3));
    expect(r.exp[Category.batting], greaterThan(0));
    expect(r.exp[Category.running], greaterThan(0));
  });

  test('月単位(share=1/3)は効果・疲労が3分の1ぶんになる', () {
    final season =
        playTerm(_p(), const Condition(), Plan.train, Ability.power, Random(1));
    final month = playTerm(
        _p(), const Condition(), Plan.train, Ability.power, Random(1),
        share: 1 / 3);
    expect(month.condition.fatigue, season.condition.fatigue ~/ 3);
    expect(month.exp[Category.batting]!,
        lessThan(season.exp[Category.batting]! / 2));
  });

  test('やる気が高いほど経験点が多く貯まる', () {
    int exp(int morale) => playTerm(_p(), Condition(morale: morale), Plan.train,
            Ability.power, Random(1))
        .exp[Category.batting]!;
    expect(exp(90), greaterThan(exp(50)));
    expect(exp(50), greaterThan(exp(10)));
  });

  test('疲れが溜まるほど怪我しやすく、特訓はさらに高い', () {
    const lo = Condition(fatigue: 0), hi = Condition(fatigue: 90);
    expect(injuryChance(hi, Plan.train),
        greaterThan(injuryChance(lo, Plan.train)));
    expect(injuryChance(lo, Plan.special),
        greaterThan(injuryChance(lo, Plan.train)));
  });

  test('怪我中は選択に関わらず伸びず、季節が進むと治る', () {
    const hurt = Condition(injuredTerms: 2);
    final r = playTerm(_p(), hurt, Plan.special, Ability.power, Random(1));
    expect(r.player.abilities, _p().abilities);
    expect(r.condition.injuredTerms, 1);
    expect(r.gotInjured, isFalse);
  });

  test('体調は疲れ・気持ち・怪我で決まる', () {
    expect(const Condition(fatigue: 0, morale: 100).value, 100);
    expect(const Condition(fatigue: 100, morale: 0).value, 0);
    expect(const Condition(fatigue: 0, morale: 100, injuredTerms: 1).value, 50);
  });

  test('体調が良いほど大会で勝ち上がる(平均)', () {
    double avg(int cond) {
      var s = 0.0;
      for (var i = 0; i < 400; i++) {
        s += playTournament(_p(60),
                teamLevel: 50,
                opponents: const [45, 50, 55, 60],
                rng: Random(i),
                condition: cond)
            .roundsWon;
      }
      return s / 400;
    }

    expect(avg(100), greaterThan(avg(0)));
  });

  test('出来事はどれも選択肢が2つ以上あり、選ぶと状態が範囲内で動く', () {
    for (final e in events) {
      expect(e.choices.length, greaterThanOrEqualTo(2), reason: e.id);
      for (final ch in e.choices) {
        final r = ch.apply(
            _p(), const Condition(fatigue: 95, morale: 95), Ability.eye);
        expect(r.condition.fatigue, inInclusiveRange(0, 100), reason: e.id);
        expect(r.condition.morale, inInclusiveRange(0, 100), reason: e.id);
        expect(r.player.of(Ability.eye), inInclusiveRange(0, abilityCap));
      }
    }
  });

  test('出来事は毎季節ではなく、ときどき起きる', () {
    var n = 0;
    for (var s = 0; s < 1000; s++) {
      if (drawEvent(Random(s)) != null) n++;
    }
    expect(n, inExclusiveRange(250, 550));
  });

  test('年の終わりに年齢が進み、疲れが抜ける', () {
    expect(endOfYear(_p()).age, 15);
    expect(endOfYearCondition(const Condition(fatigue: 50)).fatigue, 30);
  });

  test('体調は保存して読み直せる。欠けた項目は既定値', () {
    const c = Condition(fatigue: 12, morale: 80, injuredTerms: 1);
    final q = Condition.fromJson(c.toJson());
    expect((q.fatigue, q.morale, q.injuredTerms), (12, 80, 1));
    expect(Condition.fromJson({}).morale, 50);
  });
}

void _outcomeTests() {
  test('練習の出来: 失敗・好調・大成功がときどき出る。休養・交流・研究は毎回ふつう', () {
    final seen = <Outcome, int>{};
    for (var s = 0; s < 3000; s++) {
      final o = rollOutcome(Plan.train, Random(s));
      seen.update(o, (v) => v + 1, ifAbsent: () => 1);
    }
    for (final o in Outcome.values) {
      expect(seen[o], greaterThan(0), reason: o.name);
    }
    expect(seen[Outcome.normal]!, greaterThan(seen[Outcome.good]!));
    for (final p in [Plan.rest, Plan.social, Plan.study]) {
      expect(hasOutcome(p), isFalse);
      expect(rollOutcome(p, Random(1)), Outcome.normal);
    }
  });

  test('出来の倍率の平均は1前後(全体のバランスを変えない)。特訓は振れ幅が大きい', () {
    double mean(Plan p) {
      var t = 0.0;
      for (var s = 0; s < 8000; s++) {
        t += rollOutcome(p, Random(s)).multiplier;
      }
      return t / 8000;
    }

    double spread(Plan p) {
      final m = mean(p);
      var t = 0.0;
      for (var s = 0; s < 8000; s++) {
        final d = rollOutcome(p, Random(s)).multiplier - m;
        t += d * d;
      }
      return t / 8000;
    }

    expect(mean(Plan.train), inInclusiveRange(0.97, 1.10));
    expect(mean(Plan.special), inInclusiveRange(0.97, 1.10));
    expect(spread(Plan.special), greaterThan(spread(Plan.train)));
  });

  test('大成功は経験点が多く気持ちが上がり、失敗は少なく疲れが増える', () {
    PlayTermResult find(Outcome want) {
      for (var s = 0; s < 500; s++) {
        final r = playTerm(_p(), const Condition(morale: 50), Plan.train,
            Ability.power, Random(s));
        if (r.outcome == want) return PlayTermResult(r, s);
      }
      fail('${want.name} が出ない');
    }

    final great = find(Outcome.great);
    final bad = find(Outcome.bad);
    final normal = find(Outcome.normal);
    int total(TermResult r) => r.exp.values.fold(0, (a, b) => a + b);
    expect(total(great.r), greaterThan(total(normal.r)));
    expect(total(bad.r), lessThan(total(normal.r)));
    expect(great.r.condition.morale, greaterThan(normal.r.condition.morale));
    expect(bad.r.condition.fatigue, greaterThan(normal.r.condition.fatigue));
  });
}

class PlayTermResult {
  PlayTermResult(this.r, this.seed);
  final TermResult r;
  final int seed;
}

void balanceChecks() {
  test('練習試合は、特訓より経験点が少なく、練習より疲れる(特訓の上位互換にならない)', () {
    expect(effectOf(Plan.match).scale, lessThan(effectOf(Plan.special).scale));
    expect(effectOf(Plan.match).scale, lessThan(effectOf(Plan.train).scale));
    expect(effectOf(Plan.match).fatigue,
        greaterThan(effectOf(Plan.train).fatigue));
  });
}

void injuryChecks() {
  test('特訓は、練習より怪我の確率がはっきり高い(特訓ばかりが最善にならない)', () {
    const c = Condition(fatigue: 30);
    expect(injuryChance(c, Plan.special),
        greaterThan(injuryChance(c, Plan.train) + 0.2));
  });
}
