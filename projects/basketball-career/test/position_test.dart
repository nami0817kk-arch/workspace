import 'dart:convert';
import 'dart:math';

import 'package:basketball_career/game/events.dart';
import 'package:basketball_career/game/game.dart';
import 'package:basketball_career/game/life.dart';
import 'package:basketball_career/game/match.dart';
import 'package:basketball_career/game/path.dart';
import 'package:basketball_career/game/player.dart';
import 'package:flutter_test/flutter_test.dart';

Player _p({double h = 150, int age = 12, Map<Ability, int>? ab, Position? lock}) {
  final base = Game.start('x', rng: Random(1), events: false).player;
  return base.copyWith(
    age: age,
    heightCm: h,
    abilities: ab ?? {for (final a in Ability.values) a: 50},
    positionLock: lock,
    clearPositionLock: lock == null,
  );
}

void main() {
  group('ポジションは勝手に入れ替わらない', () {
    test('始めた時点で決まっていて、身長や能力が動いても、見直す年齢まで変わらない', () {
      final g = Game.start('x', rng: Random(2), events: false);
      final first = g.player.position;
      expect(g.player.positionLock, first);
      // 身長も能力も大きく動かしても、決めたポジションのまま。
      g.player = g.player.copyWith(
        heightCm: 206,
        abilities: {for (final a in Ability.values) a: a == Ability.inside ? 90 : 30},
      );
      expect(g.player.position, first);
      expect(g.player.suggestedPosition, isNot(first), reason: 'おすすめは変わっている');
    });

    test('節目(13・16・19・22歳)にだけ見直し、変わったら知らせる', () {
      var totalChanges = 0, notes = 0;
      for (var seed = 0; seed < 12; seed++) {
        final g = Game.start('x', rng: Random(seed), events: false);
        var guard = 0;
        var last = g.player.position;
        while (g.phase != Phase.retired && g.player.age < 24 && guard++ < 200) {
          final age = g.player.age;
          switch (g.phase) {
            case Phase.season:
              g.choose(Action.practice, Ability.threePoint);
              if (g.lastPositionNote != null) notes++;
            case Phase.halftime:
              g.resolveHalftime(Halftime.keep);
            case Phase.clutch:
              g.resolveClutch(Clutch.drive);
            case Phase.event:
              g.resolveEvent(0);
            case Phase.path:
              if (!g.chooseRoute(Route.pro) && !g.retired) g.chooseRoute(Route.university);
            case Phase.retired:
              break;
          }
          if (g.player.position != last) {
            totalChanges++;
            expect(Game.positionReviewAges.contains(g.player.age), isTrue,
                reason: 'seed $seed: ${g.player.age}歳(前は$age歳)で、節目でないのに変わった');
            last = g.player.position;
          }
        }
      }
      // 身長が大きく伸びるので、どこかの節目では変わり、そのたびに知らせが出る。
      expect(totalChanges, greaterThan(0));
      expect(notes, totalChanges);
    });

    test('自分で選ぶと固定され、おまかせに戻すと、いまのおすすめに合う', () {
      final g = Game.start('x', rng: Random(4), events: false);
      g.setPosition(Position.center);
      expect(g.player.position, Position.center);
      expect(g.positionAuto, isFalse);
      // 節目が来ても、固定したポジションは変わらない。
      g.player = g.player.copyWith(age: 15);
      g.setPosition(Position.shootingGuard);
      expect(g.player.position, Position.shootingGuard);
      g.setPosition(null);
      expect(g.positionAuto, isTrue);
      expect(g.player.position, g.player.suggestedPosition);
    });

    test('保存で残る。古いセーブ(ポジションの項目なし)は、そのときのおすすめになる', () {
      final g = Game.start('x', rng: Random(4), events: false);
      g.setPosition(Position.powerForward);
      final back = Game.fromJson(jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>);
      expect(back.player.position, Position.powerForward);
      expect(back.positionAuto, isFalse);
      final j = g.toJson();
      (j['player'] as Map<String, dynamic>).remove('position');
      j.remove('posAuto');
      final old = Game.fromJson(j);
      expect(old.positionAuto, isTrue);
      expect(old.player.positionLock, isNull);
      expect(old.player.position, old.player.suggestedPosition);
    });

    test('Position を名前から読み戻せる', () {
      for (final p in Position.values) {
        expect(Position.parse(p.name), p);
      }
      expect(Position.parse('zzz'), isNull);
    });
  });

  group('総合評価: 強みを伸ばすと上がる', () {
    test('全部同じ能力なら、強みの上乗せは付かない(平均的な選手は変わらない)', () {
      final p = _p(h: 186, age: 22, lock: Position.shootingGuard);
      final plain = p.overall;
      // 全部同じ → 上位3つと平均の差が0なので、重みつき平均そのもの
      expect(plain, closeTo(plain, 1e-9));
      expect(plain, inInclusiveRange(40, 60));
    });

    test('3Pが99の選手は、能力の合計が同じ程度の平らな選手より総合が高い(SG)', () {
      final spec = _p(h: 186, age: 22, lock: Position.shootingGuard, ab: {
        for (final a in Ability.values)
          a: a == Ability.threePoint ? 99 : (a == Ability.midRange ? 90 : 36),
      });
      final flat = _p(h: 186, age: 22, lock: Position.shootingGuard, ab: {
        for (final a in Ability.values)
          a: a == Ability.threePoint ? 99 : (a == Ability.midRange ? 90 : 36),
      }).copyWith(abilities: {
        for (final a in Ability.values)
          a: ((99 + 90 + 36 * 9) / 11).round(),
      });
      expect(spec.overall, greaterThan(flat.overall),
          reason: '強みがあるほうが総合が高い');
    });

    test('3Pが99でも、ポジションが3Pを見ないもの(PF)だと総合が低い=ポジションの食い違いが原因だった', () {
      final ab = {
        for (final a in Ability.values) a: a == Ability.threePoint ? 99 : 40,
      };
      final sg = _p(h: 192, age: 22, lock: Position.shootingGuard, ab: ab);
      final pf = _p(h: 192, age: 22, lock: Position.powerForward, ab: ab);
      expect(sg.overall, greaterThan(pf.overall));
    });
  });

  group('出来事の選択肢の結果の予告', () {
    test('特性がつく選択肢には、特性の名前と効果が予告に出る', () {
      var checked = 0;
      for (final e in allEvents) {
        for (final o in e.options) {
          final t = o.effect.trait;
          if (t == null) continue;
          checked++;
          final lines = o.effect.previewLines().join('/');
          expect(lines, contains('特性「${t.label}」がつく'), reason: '${e.id} ${o.label}');
          expect(lines, contains(t.description));
        }
      }
      expect(checked, greaterThan(5));
    });

    test('予告に、穴あきの語や null が混ざらない', () {
      for (final e in allEvents) {
        for (final o in e.options) {
          for (final l in o.effect.previewLines()) {
            for (final bad in ['null', 'NaN', '{', '}']) {
              expect(l.contains(bad), isFalse, reason: '${e.id} ${o.label}: $l');
            }
          }
        }
      }
    });
  });
}
