import 'dart:math';

import 'package:baseball_manager/game/skills.dart';
import 'package:baseball_manager/game/achievements.dart';
import 'package:baseball_manager/game/career.dart';
import 'package:baseball_manager/game/exp.dart';
import 'package:baseball_manager/game/game.dart';
import 'package:baseball_manager/game/life.dart';
import 'package:baseball_manager/game/path.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:baseball_manager/game/snapshot.dart';
import 'package:baseball_manager/game/talent.dart';
import 'package:baseball_manager/game/traits.dart';
import 'package:baseball_manager/ui/labels.dart';
import 'package:flutter_test/flutter_test.dart';

PlayerSnapshot _snapshot({
  Map<Ability, int> gifts = const {},
  Set<Trait> traits = const {},
  bool awakened = false,
}) =>
    PlayerSnapshot(
      name: 'p',
      role: Role.batter,
      age: 30,
      stage: Stage.retired,
      potential: 60,
      abilities: {for (final a in batterAbilities) a: 50},
      traits: traits,
      records: const [],
      events: const [],
      overallHistory: const [],
      gifts: gifts,
      awakened: awakened,
    );

void main() {
  group('天賦(才能の偏り)', () {
    test('抽選は-2〜+2で、平均はほぼ0・左右対称', () {
      final rng = Random(1);
      var sum = 0, n = 0;
      final count = <int, int>{};
      for (var i = 0; i < 4000; i++) {
        final g = rollGifts(rng);
        expect(g.length, Ability.values.length);
        for (final v in g.values) {
          expect(v, inInclusiveRange(giftMin, giftMax));
          sum += v;
          n++;
          count[v] = (count[v] ?? 0) + 1;
        }
      }
      expect(sum / n, closeTo(0, 0.05));
      expect((count[2]! - count[-2]!).abs() / n, lessThan(0.01));
      expect(count[0]! / n, closeTo(0.40, 0.02));
    });

    test('得意な能力は経験点が少なく、苦手は多い。平均は変わらない', () {
      expect(expCost(60, 2), lessThan(expCost(60)));
      expect(expCost(60, -2), greaterThan(expCost(60)));
      expect(expCost(60), 6 + 60 ~/ 6);
      for (var v = 0; v < 99; v += 7) {
        expect((expCost(v, 2) + expCost(v, -2)) / 2, closeTo(expCost(v), 1));
        expect(expCost(v, 2), greaterThanOrEqualTo(1));
      }
    });

    test('天賦で、同じ経験点で上がる量が変わる(buyAll)', () {
      final p = Player(
          name: 't',
          role: Role.batter,
          age: 15,
          potential: 60,
          abilities: {for (final a in batterAbilities) a: 60});
      final gifted = p.copyWith(gifts: {Ability.contact: 2});
      final dull = p.copyWith(gifts: {Ability.contact: -2});
      const pool = ExpPool({Category.batting: 60});
      expect(buyAll(gifted, pool, Ability.contact).bought,
          greaterThan(buyAll(dull, pool, Ability.contact).bought));
    });

    test('保存と読み込み。古いセーブ(項目なし)は天賦なし', () {
      final p = Player(
          name: 't',
          role: Role.batter,
          age: 15,
          potential: 60,
          gifts: {Ability.power: 2, Ability.eye: -1});
      final back = Player.fromJson(p.toJson());
      expect(back.gift(Ability.power), 2);
      expect(back.gift(Ability.eye), -1);
      expect(back.gift(Ability.speed), 0);
      final old = p.toJson()..remove('gifts');
      expect(Player.fromJson(old).gifts, isEmpty);
      expect(
          giftsFromJson({'power': 9, 'xx': 1, 'eye': 'a'}), {Ability.power: 2});
    });

    test('新しい選手は天賦を持ち、二世は親の得意を受け継ぐことがある', () {
      final g = Game.newGame(name: 'a', role: Role.batter, rng: Random(3));
      expect(g.player.gifts.length, Ability.values.length);
      var inherited = 0;
      for (var s = 0; s < 200; s++) {
        final parent = _snapshot(gifts: {Ability.contact: 2});
        final c = Game.newGame(
            name: 'b', role: Role.batter, rng: Random(s), parent: parent);
        if (c.player.gift(Ability.contact) >= 1) inherited++;
        for (final v in c.player.gifts.values) {
          expect(v, inInclusiveRange(giftMin, giftMax));
        }
      }
      expect(inherited, greaterThan(40));
    });

    test('ゲームの保存で天賦と覚醒が残る', () {
      final g = Game.newGame(name: 'a', role: Role.pitcher, rng: Random(5));
      final back = Game.fromJson(g.toJson(), Random(1));
      expect(back.player.gifts, g.player.gifts);
      expect(back.awakened, g.awakened);
    });
  });

  group('レア特性', () {
    test('通常の抽選には出ない。生まれつきは約4%', () {
      var rare = 0;
      const n = 6000;
      for (var s = 0; s < n; s++) {
        final t = rollInnateTraits(Random(s));
        expect(t.any((x) => x.rare), isFalse);
        final r = rollBirthRare(Random(s + 99999), const {}, Role.batter);
        if (r.any((x) => x.rare)) rare++;
      }
      expect(rare / n, inInclusiveRange(0.025, 0.06));
    });

    test('レア特性は5種で、役割に合うものだけが選ばれる', () {
      expect(rareTraits.length, 5);
      expect(Trait.monster.rare, isTrue);
      expect(Trait.hardWorker.rare, isFalse);
      for (var s = 0; s < 300; s++) {
        final b = pickRare(Random(s), const {}, Role.batter)!;
        expect(b.appliesTo(Role.batter), isTrue);
        final p = pickRare(Random(s), const {}, Role.pitcher)!;
        expect(p.appliesTo(Role.pitcher), isTrue);
      }
    });

    test('レア特性は通常の特性の枠とは別。通常が4つでも持てるが、レアは2つまで', () {
      final full = {Trait.genius, Trait.sturdy, Trait.sunny};
      expect(full.length, maxTraits);
      expect(canGain(full, Trait.clutch), isFalse);
      expect(canGain(full, Trait.monster), isTrue);
      final two = gain(gain(full, Trait.monster), Trait.fortune);
      expect(two.length, 5);
      expect(canGain(two, Trait.steelBody), isFalse);
    });

    test('矛盾する組み合わせは持てない', () {
      expect(canGain({Trait.glassBody}, Trait.ironWill), isFalse);
      expect(canGain({Trait.nervy}, Trait.stagePresence), isFalse);
      expect(canGain({Trait.earlyBloomer}, Trait.monster), isFalse);
      expect(canGain({Trait.earlyBloomer}, Trait.steelBody), isFalse);
    });

    test('怪物は伸びて衰えにくい・鋼の肉体は衰えず疲れにくい', () {
      expect(growthMultiplier({Trait.monster}, 20),
          greaterThan(growthMultiplier(const {}, 20)));
      expect(declineMultiplier({Trait.monster}), lessThan(1));
      expect(declineMultiplier({Trait.steelBody}), lessThan(0.7));
      expect(fatigueMultiplier({Trait.steelBody}), lessThan(1));
      expect(injuryMultiplier({Trait.ironWill}), lessThan(0.5));
      expect(tournamentBonus({Trait.stagePresence}), 8);
      expect(tournamentBonus({Trait.ironWill}), 5);
    });

    test('金の特殊能力(天才打者・天才投手)は試合中だけ能力が上がる', () {
      final bat = Player(
          name: 't',
          role: Role.batter,
          age: 20,
          potential: 60,
          abilities: {for (final a in batterAbilities) a: 50},
          skills: {Skill.geniusBat});
      expect(traitAdjusted(bat).of(Ability.contact), 58);
      expect(bat.of(Ability.contact), 50);
      final arm = Player(
          name: 't',
          role: Role.pitcher,
          age: 20,
          potential: 60,
          abilities: {for (final a in pitcherAbilities) a: 50},
          skills: {Skill.geniusArm});
      expect(traitAdjusted(arm).of(Ability.stuff), 58);
    });

    test('強運は練習の失敗が減り、大成功が増える', () {
      int count(Set<Trait> t, Outcome o) {
        var c = 0;
        final rng = Random(7);
        for (var i = 0; i < 20000; i++) {
          if (rollOutcome(Plan.train, rng, t) == o) c++;
        }
        return c;
      }

      expect(count({Trait.fortune}, Outcome.bad),
          lessThan(count(const {}, Outcome.bad) * 0.7));
      expect(count({Trait.fortune}, Outcome.great),
          greaterThan(count(const {}, Outcome.great) * 1.3));
    });
  });

  group('覚醒', () {
    test('一生に一度だけ、レア特性に目覚める', () {
      var awakenedCount = 0;
      for (var s = 0; s < 40; s++) {
        final g = Game.newGame(
            name: 'a', role: Role.batter, rng: Random(s), potential: 95);
        var guard = 0;
        while (g.phase != Phase.retired && guard++ < 4000) {
          switch (g.phase) {
            case Phase.event:
              g.resolveEvent(0);
            case Phase.pathChoice:
              g.chooseRoute(Course.values[0]);
            case Phase.term:
              g.autoSpend();
              g.choose(Plan.special, Ability.contact);
            case Phase.retired:
              break;
          }
        }
        final logs = g.log.where((l) => l.contains('に覚醒した')).length;
        expect(logs, lessThanOrEqualTo(1), reason: 'seed=$s');
        expect(g.awakened, logs == 1, reason: 'seed=$s');
        if (g.awakened) {
          awakenedCount++;
          expect(g.player.traits.any((t) => t.rare), isTrue);
        }
        expect(g.player.traits.where((t) => !t.rare).length,
            lessThanOrEqualTo(maxTraits));
        expect(g.player.traits.where((t) => t.rare).length,
            lessThanOrEqualTo(maxRareTraits));
      }
      expect(awakenedCount, greaterThan(0));
    });
  });

  group('継承(周回のやり込み)', () {
    test('継承ポイントは称号が高いほど多い', () {
      expect(legacyPointsOf(madePro: false, title: 'プロにはなれなかった'), 1);
      expect(legacyPointsOf(madePro: true, title: 'レギュラー'), 3);
      expect(legacyPointsOf(madePro: true, title: '一流選手'), 4);
      expect(legacyPointsOf(madePro: true, title: 'レジェンド'), 6);
    });

    test('継承できるのは、役割に合う良い特性。レアは高い', () {
      expect(canCarry(Trait.genius, Role.batter), isTrue);
      expect(canCarry(Trait.glassBody, Role.batter), isFalse);
      expect(legacyCost(Trait.genius), 3);
      expect(legacyCost(Trait.monster), 8);
    });

    test('持たせた特性は生まれつき付く。乱数の並びは変わらない。合わないものは付かない', () {
      final plain = Game.newGame(name: 'a', role: Role.batter, rng: Random(4));
      final carried = Game.newGame(
          name: 'a', role: Role.batter, rng: Random(4), carry: Trait.genius);
      expect(carried.player.traits, contains(Trait.genius));
      // 乱数を使わないので、そのほかの特性・天賦は同じ
      expect(carried.player.gifts, plain.player.gifts);
      expect(carried.player.potential, plain.player.potential);
      final bad = Game.newGame(
          name: 'a', role: Role.pitcher, rng: Random(4), carry: Trait.glassBody);
      expect(bad.player.traits, isNot(contains(Trait.glassBody)));
    });
  });

  group('生まれ持った才能の知らせ', () {
    test('レア特性・天賦+2・不得手(-2)があるときだけ出る', () {
      final plain =
          Player(name: 't', role: Role.batter, age: 6, potential: 50, gifts: {
        Ability.contact: 1,
        Ability.power: -1,
      });
      expect(birthTalentNotes(plain), isEmpty);
      final special = Player(
          name: 't',
          role: Role.batter,
          age: 6,
          potential: 50,
          traits: {Trait.monster},
          gifts: {Ability.contact: 2, Ability.power: -2, Ability.stuff: 2});
      final n = birthTalentNotes(special);
      expect(n.length, 3);
      expect(n[0], contains('怪物'));
      expect(n[1], contains('ミート'));
      expect(n[1], isNot(contains('球威'))); // 打者に投手の能力は出ない
      expect(n[2], contains('パワー'));
    });
  });

  group('実績・スナップショット', () {
    test('レア特性・覚醒・才能の塊', () {
      expect(earnedBy(_snapshot()), isNot(contains('rare-trait')));
      expect(
          earnedBy(_snapshot(traits: {Trait.monster})), contains('rare-trait'));
      expect(earnedBy(_snapshot(awakened: true)), contains('awakening'));
      // 打者(5能力): 合計+4で平均+0.8、合計+3では届かない
      expect(
          earnedBy(_snapshot(gifts: {
            Ability.contact: 2,
            Ability.power: 1,
            Ability.eye: 1,
          })),
          contains('gifted'));
      expect(earnedBy(_snapshot(gifts: {Ability.contact: 2, Ability.power: 1})),
          isNot(contains('gifted')));
      expect(giftAverage(Role.pitcher, {Ability.stuff: 2, Ability.control: 1}),
          closeTo(1.0, 1e-9));
      // 使わない能力(投手の打撃など)の天賦は数えない
      expect(giftAverage(Role.pitcher, {Ability.contact: 2}), 0);
    });

    test('保存で天賦・覚醒が残る。古い記録は空', () {
      final s = _snapshot(gifts: {Ability.speed: -2}, awakened: true);
      final back = PlayerSnapshot.fromJson(s.toJson());
      expect(back.gifts[Ability.speed], -2);
      expect(back.awakened, isTrue);
      final old = s.toJson()
        ..remove('gifts')
        ..remove('awakened');
      final o = PlayerSnapshot.fromJson(old);
      expect(o.gifts, isEmpty);
      expect(o.awakened, isFalse);
    });
  });
}
