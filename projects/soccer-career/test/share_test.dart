/// 味方の得点を差し引く割合は、そのポジションが取る点のぶんだけ。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/game/formulas.dart';
import 'package:soccer_career/models/attributes.dart';

void main() {
  test('点を取るポジションほど、味方の得点を多く差し引く', () {
    final st = Formulas.teammateGoalShareFor(Position.st);
    final wg = Formulas.teammateGoalShareFor(Position.wg);
    final cm = Formulas.teammateGoalShareFor(Position.cm);
    final cb = Formulas.teammateGoalShareFor(Position.cb);
    expect(st, lessThan(wg));
    expect(wg, lessThan(cm));
    expect(cm, lessThanOrEqualTo(cb));
  });

  test('ほとんど点を取らない中盤は、クラブを弱くしない', () {
    // 以前は中盤 0.85 で、1試合 0.04点の選手が味方の得点を 15% 削っていた
    // （毎試合 0.18点ぶんクラブが弱く、リーグ優勝が守備の選手の 1/3 だった）。
    for (final p in [Position.dm, Position.cm, Position.am]) {
      expect(Formulas.teammateGoalShareFor(p), greaterThanOrEqualTo(0.95));
    }
  });
}
