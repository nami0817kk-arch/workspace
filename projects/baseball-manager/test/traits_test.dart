import 'dart:math';

import 'package:baseball_manager/game/career.dart';
import 'package:baseball_manager/game/characters.dart';
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
    final base14 = d(_p(age: 14)),
        late14 = d(_p(age: 14, traits: {Trait.lateBloomer}));
    final base20 = d(_p(age: 20)),
        late20 = d(_p(age: 20, traits: {Trait.lateBloomer}));
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
    final plain =
        playTerm(_p(), const Condition(), Plan.train, Ability.power, Random(1));
    final iron = playTerm(_p(traits: {Trait.ironMan}), const Condition(),
        Plan.train, Ability.power, Random(1));
    expect(iron.condition.fatigue, lessThan(plain.condition.fatigue));
    final a = playTerm(
        _p(), const Condition(), Plan.social, Ability.power, Random(1));
    final b = playTerm(_p(traits: {Trait.sunny}), const Condition(),
        Plan.social, Ability.power, Random(1));
    expect(b.condition.morale, greaterThan(a.condition.morale));
  });

  test('勝負強いは大会で勝ち上がりやすく、ノミの心臓は逆', () {
    double avg(Set<Trait> t) {
      var s = 0.0;
      for (var i = 0; i < 500; i++) {
        s += playTournament(_p(age: 17, v: 60, traits: t),
                teamLevel: 50,
                opponents: const [45, 50, 55, 60],
                rng: Random(i))
            .roundsWon;
      }
      return s / 500;
    }

    expect(avg({Trait.clutch}), greaterThan(avg({})));
    expect(avg({Trait.nervy}), lessThan(avg({})));
  });

  test('華がある選手はドラフトの点数が5高い', () {
    final p = _p(age: 18, v: 60);
    expect(
        draftScore(p.copyWith(traits: {Trait.starPower}), 50) -
            draftScore(p, 50),
        5);
  });

  test('特性は保存して読み直せる。欠けていれば空、未知の名前は無視', () {
    final p = _p(traits: {Trait.genius, Trait.sturdy});
    expect(Player.fromJson(p.toJson()).traits, {Trait.genius, Trait.sturdy});
    expect(Player.fromJson({'name': 'x'}).traits, isEmpty);
    expect(
        Player.fromJson({
          'traits': ['genius', 'nonexistent']
        }).traits,
        {Trait.genius});
  });

  test('役割を変えても特性は残る', () {
    final p = _p(age: 22, traits: {Trait.clutch});
    expect(switchRole(p, Role.twoWay, Stage.pro).traits, {Trait.clutch});
  });

  test('特別メニューをやり抜くと努力家になる(矛盾なし)', () {
    final e = events.firstWhere((e) => e.id == 'winter-menu');
    final r = e.choices.first.apply(_p(), const Condition(), Ability.power);
    expect(r.player.traits, {Trait.hardWorker});
    expect(
        e.choices.last
            .apply(_p(), const Condition(), Ability.power)
            .player
            .traits,
        isEmpty);
  });

  test('全特性に名前と説明がある', () {
    for (final t in Trait.values) {
      expect(t.label, isNotEmpty);
      expect(t.description, isNotEmpty);
    }
  });

  group('増えた特性', () {
    test('特性は24個以上。名前は重複せず、説明がある', () {
      expect(Trait.values.length, greaterThanOrEqualTo(24));
      expect(
          Trait.values.map((t) => t.label).toSet().length, Trait.values.length);
      for (final t in Trait.values) {
        expect(t.label, isNotEmpty);
        expect(t.description, isNotEmpty);
        expect(RegExp(r'[a-z]{4,}').hasMatch(t.label + t.description), isFalse,
            reason: t.name);
      }
    });

    test('打者の特性は投手に、投手の特性は打者に与えない。二刀流は両方', () {
      for (final t in Trait.values) {
        if (t.forRole == TraitFor.batter) {
          expect(t.appliesTo(Role.batter), isTrue);
          expect(t.appliesTo(Role.pitcher), isFalse, reason: t.name);
          expect(t.appliesTo(Role.twoWay), isTrue);
        }
        if (t.forRole == TraitFor.pitcher) {
          expect(t.appliesTo(Role.pitcher), isTrue);
          expect(t.appliesTo(Role.batter), isFalse, reason: t.name);
          expect(t.appliesTo(Role.twoWay), isTrue);
        }
      }
      for (var seed = 0; seed < 300; seed++) {
        for (final role in Role.values) {
          for (final t in rollInnateTraits(Random(seed), role)) {
            expect(t.appliesTo(role), isTrue, reason: '${t.name} $role');
          }
        }
      }
    });

    test('矛盾する組み合わせは同時に持てない', () {
      expect(canGain({Trait.slugger}, Trait.contactHitter), isFalse);
      expect(canGain({Trait.fireballer}, Trait.finesse), isFalse);
      expect(canGain({Trait.quickRecovery}, Trait.slowRecovery), isFalse);
      expect(canGain({Trait.moodMaker}, Trait.lonely), isFalse);
      expect(canGain({Trait.leader}, Trait.lonely), isFalse);
      expect(canGain({Trait.sunny}, Trait.moody), isFalse);
      expect(canGain({Trait.slugger}, Trait.patient), isTrue);
    });

    test('試合用の能力: 特性ぶんだけ上がり下がりし、元の選手は変わらない', () {
      final p = Player(
        name: 't',
        role: Role.batter,
        age: 20,
        potential: 50,
        abilities: {for (final a in batterAbilities) a: 50},
        traits: {Trait.slugger, Trait.speedster},
      );
      final adj = traitAdjusted(p);
      expect(adj.of(Ability.power), 59);
      expect(adj.of(Ability.contact), 48);
      expect(adj.of(Ability.speed), 58);
      expect(p.of(Ability.power), 50);
      // 能力が99でも、試合の間は特性の上乗せが消えない(上限は試合用の120)
      final top = p.copyWith(abilities: {
        for (final a in batterAbilities) a: 99,
      });
      expect(traitAdjusted(top).of(Ability.power), 108);
      expect(traitAdjusted(top).of(Ability.contact), 97);
      expect(top.of(Ability.power), 99); // 元の選手は変えない
      // 特性が無ければ同じもの
      expect(identical(traitAdjusted(p.copyWith(traits: {})), p), isFalse);
      expect(traitAdjusted(p.copyWith(traits: {})).of(Ability.power), 50);
    });

    test('試合で実際に効く: 長距離砲は本塁打が増え、剛腕は三振が増える', () {
      Player bat(Set<Trait> t) => Player(
          name: 't',
          role: Role.batter,
          age: 22,
          potential: 50,
          abilities: {for (final a in batterAbilities) a: 55},
          traits: t);
      int hr(Player p) {
        final rng = Random(5);
        var n = 0;
        for (var i = 0; i < 3000; i++) {
          n += playGame(traitAdjusted(p), 60, rng).homeRuns;
        }
        return n;
      }

      expect(hr(bat({Trait.slugger})), greaterThan(hr(bat({}))));

      Player pit(Set<Trait> t) => Player(
          name: 't',
          role: Role.pitcher,
          age: 22,
          potential: 50,
          abilities: {for (final a in pitcherAbilities) a: 55},
          traits: t);
      int k(Player p) {
        final rng = Random(5);
        var n = 0;
        for (var i = 0; i < 3000; i++) {
          n += playGame(traitAdjusted(p), 60, rng).strikeouts;
        }
        return n;
      }

      expect(k(pit({Trait.fireballer})), greaterThan(k(pit({}))));
    });

    test('そのほかの効き方', () {
      expect(traitTeamBonus({Trait.leader}), 3);
      expect(traitTeamBonus({}), 0);
      expect(recoveryMultiplier({Trait.quickRecovery}), 1.5);
      expect(recoveryMultiplier({Trait.slowRecovery}), 0.6);
      expect(recoveryMultiplier({}), 1.0);
      expect(tagTraitMultiplier({Trait.moodMaker}), 1.5);
      expect(tagTraitMultiplier({Trait.lonely}), 0.6);
      expect(studyMultiplier({Trait.studious}), 1.4);
      expect(worldBonus({Trait.worldStage}), 10);
      expect(moraleGainMultiplier({Trait.moody}), greaterThan(1));
      expect(moraleLossMultiplier({Trait.moody}), greaterThan(1));
      // 一匹狼は練習の伸びが1割増える
      expect(growthMultiplier({Trait.lonely}, 20), closeTo(1.1, 1e-9));
    });

    test('コーチは基本の特性を先に教え、覚えきったあとに個性派を教える', () {
      final first =
          teachableTrait(Stage.highSchool, {}, Random(1), Role.batter);
      expect({Trait.clutch, Trait.genius, Trait.starPower}, contains(first));
      // 基本の特性を3つとも持っていれば、個性派(長距離砲など)になる(上限4個の範囲で)
      final later = teachableTrait(
          Stage.highSchool,
          {Trait.clutch, Trait.genius, Trait.starPower},
          Random(1),
          Role.batter);
      expect(later, isNotNull);
      expect({Trait.slugger, Trait.leader, Trait.moodMaker}, contains(later));
    });

    test('コーチは、役割に合わない特性を教えない', () {
      for (var seed = 0; seed < 200; seed++) {
        for (final stage in [
          Stage.youth,
          Stage.juniorHigh,
          Stage.highSchool,
          Stage.pathChoice,
          Stage.pro
        ]) {
          final t = teachableTrait(stage, {}, Random(seed), Role.pitcher);
          if (t != null) expect(t.appliesTo(Role.pitcher), isTrue);
          final b = teachableTrait(stage, {}, Random(seed), Role.batter);
          if (b != null) expect(b.appliesTo(Role.batter), isTrue);
        }
      }
    });
  });

  test('能力が全部99でも、打者の特性は試合で上乗せされる(アベレージヒッターは打率が上がる)', () {
    double avg(Set<Trait> t) {
      final p = Player(
          name: 't',
          role: Role.batter,
          age: 26,
          potential: 50,
          abilities: {for (final a in batterAbilities) a: 99},
          traits: t);
      final rng = Random(7);
      var line = const Line();
      for (var i = 0; i < 20000; i++) {
        line += playGame(traitAdjusted(p), 65, rng);
      }
      return line.battingAverage!;
    }

    expect(avg({Trait.contactHitter}), greaterThan(avg({}) + 0.02));
    expect(avg({Trait.patient}), greaterThan(avg({})));
  });
}
