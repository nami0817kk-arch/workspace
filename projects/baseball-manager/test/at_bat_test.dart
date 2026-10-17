import 'dart:math';

import 'package:baseball_manager/game/at_bat.dart';
import 'package:flutter_test/flutter_test.dart';

Map<AtBatResult, int> _run(Pitcher p, Batter b, {int n = 20000}) {
  final rng = Random(42);
  final m = <AtBatResult, int>{};
  for (var i = 0; i < n; i++) {
    m.update(simulateAtBat(p, b, rng), (v) => v + 1, ifAbsent: () => 1);
  }
  return m;
}

void main() {
  const avgP = Pitcher(control: 50, stuff: 50);
  const avgB = Batter(contact: 50, power: 50, eye: 50);

  test('平均同士: 三振率は15〜30%', () {
    final m = _run(avgP, avgB);
    final k = (m[AtBatResult.strikeout] ?? 0) / 20000;
    expect(k, inInclusiveRange(0.15, 0.30));
  });

  test('強打者のほうが本塁打が多い', () {
    final weak = _run(avgP, const Batter(contact: 50, power: 20, eye: 50));
    final strong = _run(avgP, const Batter(contact: 50, power: 90, eye: 50));
    expect(strong[AtBatResult.homeRun]!, greaterThan(weak[AtBatResult.homeRun]!));
  });

  test('球威の高い投手のほうが三振が多い', () {
    final low = _run(const Pitcher(control: 50, stuff: 20), avgB);
    final high = _run(const Pitcher(control: 50, stuff: 90), avgB);
    expect(high[AtBatResult.strikeout]!, greaterThan(low[AtBatResult.strikeout]!));
  });
}
