import 'dart:math';

import 'package:basketball_career/game/game.dart';
import 'package:basketball_career/game/life.dart';
import 'package:basketball_career/game/player.dart';
import 'package:basketball_career/ui/controller.dart';
import 'package:flutter_test/flutter_test.dart';

Player _p({int age = 12}) {
  final base = Game.start('x', rng: Random(1), events: false).player;
  return base.copyWith(
    age: age,
    abilities: {for (final a in Ability.values) a: 30},
  );
}

void main() {
  group('重点の配分(自分で決めた能力が、はっきり伸びる)', () {
    test('第1重点 > 第2重点 > それ以外の順に、1年の伸びが大きい', () {
      final p = _p();
      final f1 = yearlyDelta(p, Ability.threePoint, Ability.threePoint,
          focus2: Ability.pass);
      final f2 = yearlyDelta(p, Ability.pass, Ability.threePoint,
          focus2: Ability.pass);
      final other = yearlyDelta(p, Ability.rebound, Ability.threePoint,
          focus2: Ability.pass);
      expect(f1, greaterThan(f2));
      expect(f2, greaterThan(other));
      expect(other, greaterThan(0), reason: '選ばなくてもゼロにはならない');
      expect(f1 / other, closeTo(focusShare / otherShare, 1e-6));
    });

    test('選ばなかった能力は、ほとんど伸びない(ターンで見ても第1重点の数倍の差)', () {
      var focusGain = 0.0, otherGain = 0.0;
      const n = 400;
      for (var i = 0; i < n; i++) {
        final p = _p();
        final r = playTerm(p, const Condition(), Action.practice,
            Ability.threePoint, Random(i),
            focus2: Ability.pass);
        focusGain += r.player.of(Ability.threePoint) - p.of(Ability.threePoint);
        otherGain += r.player.of(Ability.rebound) - p.of(Ability.rebound);
      }
      expect(focusGain / n, greaterThan(otherGain / n * 5));
      expect(focusGain / n, greaterThan(1.5), reason: '1回の練習で、はっきり上がる');
    });

    test('第2重点は、第1重点より小さく、それ以外より大きく伸びる', () {
      var f1 = 0.0, f2 = 0.0, o = 0.0;
      const n = 400;
      for (var i = 0; i < n; i++) {
        final p = _p();
        final r = playTerm(p, const Condition(), Action.practice,
            Ability.threePoint, Random(i),
            focus2: Ability.pass);
        f1 += r.player.of(Ability.threePoint) - p.of(Ability.threePoint);
        f2 += r.player.of(Ability.pass) - p.of(Ability.pass);
        o += r.player.of(Ability.rebound) - p.of(Ability.rebound);
      }
      expect(f1, greaterThan(f2));
      expect(f2, greaterThan(o));
    });

    test('おすすめの第2重点は、第1重点と別の能力', () {
      for (var seed = 0; seed < 30; seed++) {
        final p = Game.start('x', rng: Random(seed), events: false).player;
        final f = recommendedFocus(p);
        expect(recommendedFocus2(p, f), isNot(f));
      }
    });

    test('社会人の年代(24〜27歳)でも、重点にした能力は伸びる', () {
      final p = _p(age: 25);
      expect(yearlyDelta(p, Ability.threePoint, Ability.threePoint), greaterThan(0));
    });
  });

  group('直前に動いた能力', () {
    test('練習したあと、動いた能力と量が lastGains に入る(重点が上がっている)', () {
      final g = Game.start('x', rng: Random(2), events: false);
      g.choose(Action.practice, Ability.threePoint, focus2: Ability.pass);
      expect(g.lastGains[Ability.threePoint], greaterThan(0));
      expect(g.lastGains.values.every((v) => v != 0), isTrue);
    });
  });

  group('重点の選び方(コントローラ)', () {
    GameController newC() {
      final c = GameController(rng: Random(3), events: false);
      c.newGame('テスト');
      return c;
    }

    test('始めた時点は、おすすめの組(第1・第2)に合っている', () {
      final c = newC();
      expect(c.focusAuto, isTrue);
      expect(c.focus, recommendedFocus(c.game!.player));
      expect(c.focus2, recommendedFocus2(c.game!.player, c.focus));
    });

    test('自分で選ぶとおすすめの自動追従が止まり、「おすすめに戻す」で戻る', () {
      final c = newC();
      final other = Ability.values.firstWhere((a) => a != c.focus && a != c.focus2);
      c.setFocus(other);
      expect(c.focus, other);
      expect(c.focusAuto, isFalse);
      c.useRecommendedFocus();
      expect(c.focusAuto, isTrue);
      expect(c.focus, recommendedFocus(c.game!.player));
    });

    test('第1重点を第2重点と同じにすると、第2重点は外れる。第1と同じものは第2にできない', () {
      final c = newC();
      final second = c.focus2!;
      c.setFocus(second);
      expect(c.focus, second);
      expect(c.focus2, isNull);
      c.setFocus2(second);
      expect(c.focus2, isNull, reason: '第1重点と同じ能力は第2にできない');
      final x = Ability.values.firstWhere((a) => a != c.focus);
      c.setFocus2(x);
      expect(c.focus2, x);
      c.setFocus2(null);
      expect(c.focus2, isNull);
    });

    test('選んだ重点で練習すると、その能力が上がり、選ばなかった能力は平均でずっと小さい', () {
      var picked = 0.0, untouchedAvg = 0.0;
      const n = 60;
      for (var seed = 0; seed < n; seed++) {
        final c = GameController(rng: Random(seed), events: false);
        c.newGame('テスト');
        c.setFocus(Ability.rebound);
        c.setFocus2(Ability.pass);
        final before = Map<Ability, int>.of(c.game!.player.abilities);
        c.act(Action.practice);
        final g = c.game!;
        picked += g.player.of(Ability.rebound) - before[Ability.rebound]!;
        final others = Ability.values
            .where((a) => a != Ability.rebound && a != Ability.pass);
        untouchedAvg +=
            others.fold(0, (s, a) => s + g.player.of(a) - before[a]!) / others.length;
      }
      expect(picked / n, greaterThan(1.0));
      expect(untouchedAvg / n, lessThan(picked / n / 4));
    });
  });
}
