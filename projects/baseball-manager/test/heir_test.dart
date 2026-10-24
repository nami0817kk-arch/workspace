import 'dart:math';

import 'package:baseball_manager/game/achievements.dart';
import 'package:baseball_manager/game/career.dart';
import 'package:baseball_manager/game/game.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:baseball_manager/game/snapshot.dart';
import 'package:baseball_manager/game/traits.dart';
import 'package:flutter_test/flutter_test.dart';

PlayerSnapshot _parent({
  int potential = 95,
  Set<Trait> traits = const {Trait.genius, Trait.clutch, Trait.glassBody},
  Role role = Role.batter,
  bool married = true,
  String? ending = 'レジェンド',
  String name = '親',
}) =>
    PlayerSnapshot(
      name: name,
      role: role,
      age: 40,
      stage: Stage.retired,
      potential: potential,
      abilities: const {Ability.contact: 80},
      traits: traits,
      records: const [],
      events: const [],
      overallHistory: const [10, 20],
      endingTitle: ending,
      married: married,
    );

void main() {
  group('二世の始まり', () {
    test('素質は親ゆずり。強い親の子は、ふつうの子より平均で素質が高い', () {
      double mean(PlayerSnapshot? parent) {
        var sum = 0;
        const n = 400;
        for (var s = 0; s < n; s++) {
          final g = Game.newGame(
              name: 'こ', role: Role.batter, rng: Random(s), parent: parent);
          sum += g.player.potential;
        }
        return sum / n;
      }

      final heir = mean(_parent(potential: 95));
      final normal = mean(null);
      expect(heir, greaterThan(normal + 10));
      // 素質は0〜100に収まる
      for (var s = 0; s < 100; s++) {
        final g = Game.newGame(
            name: 'こ',
            role: Role.batter,
            rng: Random(s),
            parent: _parent(potential: 100));
        expect(g.player.potential, inInclusiveRange(0, 100));
      }
    });

    test('良い特性を受け継ぐことがある。悪い特性・役割に合わない特性は受け継がない', () {
      var inherited = 0;
      const n = 300;
      for (var s = 0; s < n; s++) {
        final g = Game.newGame(
            name: 'こ',
            role: Role.pitcher,
            rng: Random(s),
            parent: _parent(traits: {
              Trait.genius, // 受け継げる
              Trait.glassBody, // 悪い特性
            }));
        final t = g.player.traits;
        expect(t, isNot(contains(Trait.glassBody)));
        if (t.contains(Trait.genius)) inherited++;
        for (final x in t) {
          expect(x.appliesTo(Role.pitcher), isTrue);
        }
        expect(t.length, lessThanOrEqualTo(maxTraits));
      }
      // 6割ほどで受け継ぐ(生まれつきの分も含めて、ふつうより明らかに多い)
      expect(inherited / n, greaterThan(0.45));
    });

    test('親の名前を覚え、年表に残る。保存して読み直しても残る', () {
      final g = Game.newGame(
          name: 'こ', role: Role.batter, rng: Random(1), parent: _parent());
      expect(g.parentName, '親');
      expect(g.lifeLog.any((e) => e.text.contains('親の子として生まれた')), isTrue);
      final back = Game.fromJson(g.toJson(), Random(1));
      expect(back.parentName, '親');
      final snap = PlayerSnapshot.fromJson(PlayerSnapshot.fromGame(g).toJson());
      expect(snap.parentName, '親');
      // 二世でなければ null、古いセーブも null
      final plain = Game.newGame(name: 'こ', role: Role.batter, rng: Random(1));
      expect(plain.parentName, isNull);
      final old = g.toJson()..remove('parentName');
      expect(Game.fromJson(old, Random(1)).parentName, isNull);
    });

    test('素質を指定したときは、そちらが優先される(管理者・テスト用)', () {
      final g = Game.newGame(
          name: 'こ',
          role: Role.batter,
          rng: Random(1),
          potential: 10,
          parent: _parent(potential: 100));
      expect(g.player.potential, 10);
    });
  });

  group('実績', () {
    test('二世の誕生・親を超える', () {
      final heir = _parent(ending: '一流選手').parentName;
      expect(heir, isNull); // 親のスナップショットは二世ではない
      PlayerSnapshot snap(String? parentName, String? ending) => PlayerSnapshot(
            name: 't',
            role: Role.batter,
            age: 40,
            stage: Stage.retired,
            potential: 50,
            abilities: const {Ability.contact: 50},
            traits: const {},
            records: const [],
            events: const [],
            overallHistory: const [10, 20],
            endingTitle: ending,
            parentName: parentName,
          );
      expect(earnedBy(snap(null, 'レジェンド')), isNot(contains('heir')));
      expect(earnedBy(snap('親', '一流選手')), contains('heir'));
      expect(earnedBy(snap('親', '一流選手')), isNot(contains('heir-legend')));
      expect(earnedBy(snap('親', 'レジェンド')), contains('heir-legend'));
    });
  });
}
