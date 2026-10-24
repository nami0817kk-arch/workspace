import 'dart:math';

import 'package:basketball_career/game/events.dart';
import 'package:basketball_career/game/life.dart';
import 'package:basketball_career/game/match.dart';
import 'package:basketball_career/game/player.dart';
import 'package:basketball_career/game/traits.dart';
import 'package:flutter_test/flutter_test.dart';

Player _p({Set<Trait> traits = const {}, double h = 190, int a = 60}) => Player(
      name: 'a',
      age: 15,
      potential: 70,
      heightCm: h,
      heightGenes: 0.5,
      abilities: {for (final x in Ability.values) x: a},
      traits: traits,
    );

void main() {
  group('バスケ特有の特性', () {
    const basket = [
      Trait.wingspan,
      Trait.lefty,
      Trait.basketballIq,
      Trait.shooterBorn,
      Trait.lockdown,
      Trait.athletic,
      Trait.captain,
      Trait.gameSmart,
    ];

    test('8つあり、説明があり、どれも良い特性(抽選に出る)', () {
      expect(Trait.values.length, greaterThanOrEqualTo(20));
      for (final t in basket) {
        expect(t.label, isNotEmpty);
        expect(t.description, isNotEmpty);
        expect(t.positive, isTrue);
        expect(Trait.parse(t.name), t);
      }
    });

    test('能力ごとの伸びの倍率: 該当する能力にだけ効き、無い特性は1倍', () {
      expect(abilityGrowthMultiplier({}, Ability.pass), 1.0);
      expect(abilityGrowthMultiplier({Trait.basketballIq}, Ability.pass), 1.25);
      expect(abilityGrowthMultiplier({Trait.basketballIq}, Ability.threePoint), 1.0);
      expect(abilityGrowthMultiplier({Trait.shooterBorn}, Ability.freeThrow), 1.3);
      expect(abilityGrowthMultiplier({Trait.lockdown}, Ability.speed), 1.2);
      expect(abilityGrowthMultiplier({Trait.athletic}, Ability.physical), 1.2);
      expect(abilityGrowthMultiplier({Trait.athletic}, Ability.pass), 1.0);
    });

    test('実際の伸び(yearlyDelta)に反映される', () {
      final base = _p();
      final shooter = _p(traits: {Trait.shooterBorn});
      expect(yearlyDelta(shooter, Ability.threePoint, Ability.threePoint),
          closeTo(yearlyDelta(base, Ability.threePoint, Ability.threePoint) * 1.3, 1e-9));
      expect(yearlyDelta(shooter, Ability.pass, Ability.pass),
          yearlyDelta(base, Ability.pass, Ability.pass));
    });

    test('ウイングスパンはリバウンドとディフェンスの実効値が+4', () {
      final base = _p();
      final w = _p(traits: {Trait.wingspan});
      expect(w.effective(Ability.rebound) - base.effective(Ability.rebound), 4);
      expect(w.effective(Ability.defense) - base.effective(Ability.defense), 4);
      expect(w.effective(Ability.pass), base.effective(Ability.pass));
    });

    test('左利きはドライブと3Pの勝負どころ成功率が上がり、パスは変わらない', () {
      final base = _p();
      final l = _p(traits: {Trait.lefty});
      double c(Player p, Clutch k) => clutchChance(p, k, 60, 1.0);
      expect(c(l, Clutch.drive) - c(base, Clutch.drive), closeTo(0.04, 1e-9));
      expect(c(l, Clutch.threePoint) - c(base, Clutch.threePoint), closeTo(0.04, 1e-9));
      expect(c(l, Clutch.pass), c(base, Clutch.pass));
    });

    test('守備の鬼はスティール、ウイングスパンはブロックが増える(平均)', () {
      double avg(Player p, int Function(MatchHalf) pick) {
        var s = 0;
        for (var i = 0; i < 400; i++) {
          s += pick(playFirstHalf(p,
              teamStrength: 55, oppStrength: 55, form: 1, rng: Random(i)));
        }
        return s / 400;
      }

      final base = _p(h: 198, a: 70);
      expect(avg(_p(h: 198, a: 70, traits: {Trait.lockdown}), (h) => h.steals),
          greaterThan(avg(base, (h) => h.steals)));
      expect(avg(_p(h: 198, a: 70, traits: {Trait.wingspan}), (h) => h.blocks),
          greaterThan(avg(base, (h) => h.blocks)));
    });

    test('キャプテンシー: チームワークが薄れにくく、味方の強さに+0.5', () {
      expect(teamworkDecay({}), 2);
      expect(teamworkDecay({Trait.captain}), 1);
      expect(traitTeamBonus({}), 0);
      expect(traitTeamBonus({Trait.captain}), 0.5);
    });

    test('試合巧者はハーフタイムの相性の効きが1.3倍', () {
      expect(halftimeFitMultiplier({}), 1.0);
      expect(halftimeFitMultiplier({Trait.gameSmart}), 1.3);
      // 相性の良い作戦が、通常より点差を伸ばす(平均)。
      double mean(Set<Trait> t) {
        final p = _p(traits: t, a: 60);
        var sum = 0;
        for (var i = 0; i < 600; i++) {
          final f = playFirstHalf(p,
              teamStrength: 55, oppStrength: 55, form: 1, rng: Random(i), style: OppStyle.fastBreak);
          final s = playSecondHalf(p, f, Halftime.defense, Random(8000 + i));
          sum += (s.team - s.opp) - f.margin;
        }
        return sum / 600;
      }

      expect(mean({Trait.gameSmart}), greaterThan(mean({}) + 0.3));
    });

    test('生まれつきの特性の抽選に、新しい特性も出る', () {
      final seen = <Trait>{};
      for (var seed = 0; seed < 3000; seed++) {
        seen.addAll(rollInnateTraits(Random(seed)));
      }
      for (final t in basket) {
        expect(seen, contains(t), reason: t.name);
      }
    });

    test('新しい特性を得る出来事が6つあり、どれも選択肢で特性を得られる', () {
      final ids = [
        'video_study',
        'shooting_camp',
        'defense_clinic',
        'jump_training',
        'captain_named',
        'bench_learning',
      ];
      final gained = <Trait>{};
      for (final id in ids) {
        final e = eventById(id)!;
        expect(e.options.length, 2, reason: id);
        final withTrait = e.options.where((o) => o.effect.trait != null).toList();
        expect(withTrait, hasLength(1), reason: id);
        gained.add(withTrait.first.effect.trait!);
        expect(events.map((x) => x.id), contains(id));
      }
      expect(gained, {
        Trait.basketballIq,
        Trait.shooterBorn,
        Trait.lockdown,
        Trait.athletic,
        Trait.captain,
        Trait.gameSmart,
      });
    });

    test('特性は保存・復元で変わらない', () {
      final p = _p(traits: {Trait.wingspan, Trait.lefty, Trait.gameSmart});
      final back = Player.fromJson(p.toJson());
      expect(back.traits, p.traits);
    });
  });
}
