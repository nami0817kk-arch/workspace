import 'dart:math';

import 'package:baseball_manager/game/career.dart';
import 'package:baseball_manager/game/life.dart';
import 'package:baseball_manager/game/path.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:baseball_manager/game/season.dart';
import 'package:baseball_manager/game/training.dart';
import 'package:baseball_manager/game/traits.dart';
import 'package:flutter_test/flutter_test.dart';

Player _p({int age = 14, Set<Trait> traits = const {}, int v = 40}) => Player(
      name: 't',
      role: Role.batter,
      age: age,
      potential: 60,
      abilities: {for (final a in batterAbilities) a: v},
      traits: traits,
    );

void main() {
  test('同時に持てない組み合わせ・重複・上限', () {
    expect(canGain({Trait.lateBloomer}, Trait.earlyBloomer), isFalse);
    expect(canGain({Trait.sturdy}, Trait.glassBody), isFalse);
    expect(canGain({Trait.clutch}, Trait.nervy), isFalse);
    expect(canGain({Trait.genius}, Trait.genius), isFalse);
    final full = {Trait.genius, Trait.sturdy, Trait.sunny, Trait.ironMan};
    expect(canGain(full, Trait.clutch), isFalse);
    expect(gain(full, Trait.clutch), full);
    expect(gain({Trait.genius}, Trait.sturdy), {Trait.genius, Trait.sturdy});
  });

  test('生まれつきの特性は0〜2個で、矛盾せず、良いものが多い', () {
    var pos = 0, neg = 0;
    for (var s = 0; s < 2000; s++) {
      final t = rollInnateTraits(Random(s));
      expect(t.length, inInclusiveRange(0, 2));
      const bad = [
        {Trait.lateBloomer, Trait.earlyBloomer},
        {Trait.sturdy, Trait.glassBody},
        {Trait.clutch, Trait.nervy},
      ];
      for (final pair in bad) {
        expect(t.containsAll(pair), isFalse, reason: '$t');
      }
      for (final x in t) {
        x.positive ? pos++ : neg++;
      }
    }
    expect(pos, greaterThan(neg));
    expect(neg, greaterThan(0));
  });

  test('大器晩成は若い間は伸びず、19歳以降に伸びる', () {
    double d(Player p) => yearlyDelta(p, Ability.power, Ability.power);
    final base14 = d(_p(age: 14)), late14 = d(_p(age: 14, traits: {Trait.lateBloomer}));
    final base20 = d(_p(age: 20)), late20 = d(_p(age: 20, traits: {Trait.lateBloomer}));
    expect(late14, lessThan(base14));
    expect(late20, greaterThan(base20));
  });

  test('天才肌・努力家は伸びが大きい。長持ちは衰えがゆるやか', () {
    double d(Player p) => yearlyDelta(p, Ability.power, Ability.power);
    expect(d(_p(traits: {Trait.genius})), greaterThan(d(_p())));
    expect(d(_p(traits: {Trait.hardWorker})), greaterThan(d(_p())));
    final old = _p(age: 36);
    expect(d(old.copyWith(traits: {Trait.longevity})), greaterThan(d(old)));
    expect(d(old.copyWith(traits: {Trait.earlyBloomer})), lessThan(d(old)));
  });

  test('頑丈は怪我しにくく、ガラスの肉体はしやすい', () {
    const c = Condition(fatigue: 50);
    final base = injuryChance(c, Plan.train);
    expect(injuryChance(c, Plan.train, {Trait.sturdy}), lessThan(base));
    expect(injuryChance(c, Plan.train, {Trait.glassBody}), greaterThan(base));
  });

  test('鉄人は疲れにくく、前向きは気持ちが上がりやすい', () {
    final plain = playTerm(_p(), const Condition(), Plan.train, Ability.power, Random(1));
    final iron = playTerm(_p(traits: {Trait.ironMan}), const Condition(), Plan.train,
        Ability.power, Random(1));
    expect(iron.condition.fatigue, lessThan(plain.condition.fatigue));
    final a = playTerm(_p(), const Condition(), Plan.social, Ability.power, Random(1));
    final b = playTerm(_p(traits: {Trait.sunny}), const Condition(), Plan.social,
        Ability.power, Random(1));
    expect(b.condition.morale, greaterThan(a.condition.morale));
  });

  test('勝負強いは大会で勝ち上がりやすく、ノミの心臓は逆', () {
    double avg(Set<Trait> t) {
      var s = 0.0;
      for (var i = 0; i < 500; i++) {
        s += playTournament(_p(age: 17, v: 60, traits: t),
                teamLevel: 50, opponents: const [45, 50, 55, 60], rng: Random(i))
            .roundsWon;
      }
      return s / 500;
    }

    expect(avg({Trait.clutch}), greaterThan(avg({})));
    expect(avg({Trait.nervy}), lessThan(avg({})));
  });

  test('華がある選手はドラフトの点数が5高い', () {
    final p = _p(age: 18, v: 60);
    expect(draftScore(p.copyWith(traits: {Trait.starPower}), 50) - draftScore(p, 50), 5);
  });

  test('特性は保存して読み直せる。欠けていれば空、未知の名前は無視', () {
    final p = _p(traits: {Trait.genius, Trait.sturdy});
    expect(Player.fromJson(p.toJson()).traits, {Trait.genius, Trait.sturdy});
    expect(Player.fromJson({'name': 'x'}).traits, isEmpty);
    expect(Player.fromJson({'traits': ['genius', 'nonexistent']}).traits, {Trait.genius});
  });

  test('役割を変えても特性は残る', () {
    final p = _p(age: 22, traits: {Trait.clutch});
    expect(switchRole(p, Role.twoWay, Stage.pro).traits, {Trait.clutch});
  });

  test('特別メニューをやり抜くと努力家になる(矛盾なし)', () {
    final e = events.firstWhere((e) => e.id == 'winter-menu');
    final r = e.choices.first.apply(_p(), const Condition(), Ability.power);
    expect(r.player.traits, {Trait.hardWorker});
    expect(e.choices.last.apply(_p(), const Condition(), Ability.power).player.traits,
        isEmpty);
  });

  test('全特性に名前と説明がある', () {
    for (final t in Trait.values) {
      expect(t.label, isNotEmpty);
      expect(t.description, isNotEmpty);
    }
  });
}
