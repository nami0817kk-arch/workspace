/// **強い選手と弱い選手が、はっきり分かれるか。**
///
/// 実測（`test/spread_sim.dart`）で、引退までのピーク総合力の幅
/// （下位1割〜上位1割）は**たった 6**（72〜78）しかなかった。
/// 開始の総合力が幅4、ポテンシャルが幅12あっても、**20年やると
/// 全員が同じところに着く**。
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/game/formulas.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';

void main() {
  group('ポテンシャルの引き', () {
    test('上にも下にも散る', () {
      // **3つ引いて最大を取っていた頃は、高いほうに寄って幅が潰れていた。**
      final engine = CareerEngine(random: Random(9));
      final rolled = [for (var i = 0; i < 3000; i++) engine.rollPotential(55)]
        ..sort();
      int at(double q) => rolled[(rolled.length * q).toInt()];

      // 下位1割と上位1割の幅。以前の引き方だとここが 12 しか無かった。
      expect(
        at(0.9) - at(0.1),
        greaterThanOrEqualTo(18),
        reason: 'ポテンシャルが散っていない',
      );
      // 山型は保つ。一様にすると「稀に凄いのが生まれる」手触りが消える。
      final median = at(0.5);
      expect(median, closeTo(55 + 8 + 17, 3), reason: '中心が動いた');
    });

    test('今の総合力より必ず上で、範囲から出ない', () {
      final engine = CareerEngine(random: Random(4));
      for (var i = 0; i < 500; i++) {
        final p = engine.rollPotential(60);
        expect(p, greaterThan(60));
        expect(
          p,
          inInclusiveRange(Formulas.potentialMin, Formulas.potentialMax),
        );
      }
    });
  });

  group('伸びしろが、伸び方を変える', () {
    test('才能のある選手は、22歳を過ぎても2段ずつ伸びる', () {
      // 成功率は22歳で着いたあと15年ほとんど動かない——能力値自体が
      // そこで伸び止まるから。伸びしろを残している選手だけ、その先も伸びる。
      const past = Formulas.rapidGrowthAge + 4;
      expect(Formulas.growthStep(past, 60, 85), 2);
      expect(Formulas.growthStep(past, 78, 85), 1);
    });

    test('若いうちは、才能に関係なく2段', () {
      const young = Formulas.rapidGrowthAge - 1;
      expect(Formulas.growthStep(young, 60, 90), 2);
      expect(Formulas.growthStep(young, 60, 70), 2);
    });

    test('上限に近づくほど、伸びが遅くなる', () {
      // **近づくほど止まる**ので、誰も上限を突き抜けない。
      expect(
        Formulas.potentialDrive(60, 90),
        greaterThan(Formulas.potentialDrive(85, 90)),
      );
      expect(Formulas.potentialDrive(89, 90), lessThan(1.0));
      // 幅は付けるが、桁は変えない。
      expect(Formulas.potentialDrive(40, 99), lessThanOrEqualTo(1.5));
      expect(Formulas.potentialDrive(99, 99), greaterThanOrEqualTo(0.6));
    });
  });
}
