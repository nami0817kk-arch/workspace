import 'dart:math';

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
      expect(giftsFromJson({'power': 9, 'xx': 1, 'eye': 'a'}),
          {Ability.power: 2});
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

    test('レア特性は7種で、役割に合うものだけが選ばれる', () {
      expect(rareTraits.length, 7);
      expect(Trait.monster.rare, isTrue);
      expect(Trait.hardWorker.rare, isFalse);
      for (var s = 0; s < 300; s++) {
        final b = pickRare(Random(s), const {}, Role.batter)!;
        expect(b.appliesTo(Role.batter), isTrue);
        expect(b, isNot(Trait.prodigyArm));
        final p = pickRare(Random(s), const {}, Role.pitcher)!;
        expect(p.appliesTo(Role.pitcher), isTrue);
        expect(p, isNot(Trait.prodigyBat));
      }
    });

    test('レア特性は通常の特性の枠とは別。通常が4つでも持てるが、レアは2つまで', () {
      final full = {Trait.genius, Trait.sturdy, Trait.sunny, Trait.ironMan};
      expect(canGain(full, Trait.clutch), isFalse);
      expect(canGain(full, Trait.monster), isTrue);
      final two = gain(gain(full, Trait.monster), Trait.fortune);
      expect(two.length, 6);
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

    test('打撃・投球の天才は試合中だけ能力が上がる', () {
      final bat = Player(
          name: 't',
          role: Role.batter,
          age: 20,
          potential: 60,
          abilities: {for (final a in batterAbilities) a: 50},
          traits: {Trait.prodigyBat});
      expect(traitAdjusted(bat).of(Ability.contact), 60);
      expect(bat.of(Ability.contact), 50);
      final arm = Player(
          name: 't',
          role: Role.pitcher,
          age: 20,
          potential: 60,
          abilities: {for (final a in pitcherAbilities) a: 50},
          traits: {Trait.prodigyArm});
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

  group('実績・スナップショット', () {
    test('レア特性・覚醒・才能の塊', () {
      expect(earnedBy(_snapshot()), isNot(contains('rare-trait')));
      expect(earnedBy(_snapshot(traits: {Trait.monster})),
          contains('rare-trait'));
      expect(earnedBy(_snapshot(awakened: true)), contains('awakening'));
      expect(
          earnedBy(_snapshot(gifts: {
            Ability.contact: 2,
            Ability.power: 2,
            Ability.eye: 2,
          })),
          contains('gifted'));
      expect(
          earnedBy(_snapshot(gifts: {Ability.contact: 2, Ability.power: 2})),
          isNot(contains('gifted')));
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
