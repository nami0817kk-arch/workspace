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
    expect(
        strong[AtBatResult.homeRun]!, greaterThan(weak[AtBatResult.homeRun]!));
  });

  test('球威の高い投手のほうが三振が多い', () {
    final low = _run(const Pitcher(control: 50, stuff: 20), avgB);
    final high = _run(const Pitcher(control: 50, stuff: 90), avgB);
    expect(
        high[AtBatResult.strikeout]!, greaterThan(low[AtBatResult.strikeout]!));
  });

  test('力の差が大きく開くと圧倒する(S級の投手は小学生にほとんど打たれない)', () {
    const weak = Batter(contact: 30, power: 30, eye: 30);
    final r = _run(const Pitcher(control: 90, stuff: 90), weak);
    final n = r.values.fold<int>(0, (a, b) => a + b);
    final hits = r[AtBatResult.single]! +
        r[AtBatResult.double]! +
        r[AtBatResult.triple]! +
        r[AtBatResult.homeRun]!;
    expect(hits / n, lessThan(0.10));
    expect(r[AtBatResult.strikeout]! / n, greaterThan(0.40));
  });

  test('力の差が大きく開くと圧倒する(オールSの打者は小学生の投手をほとんど打ち取らせない)', () {
    const star = Batter(contact: 95, power: 95, eye: 95);
    final r = _run(const Pitcher(control: 30, stuff: 30), star);
    final n = r.values.fold<int>(0, (a, b) => a + b);
    final walks = r[AtBatResult.walk] ?? 0;
    final hits = r[AtBatResult.single]! +
        r[AtBatResult.double]! +
        r[AtBatResult.triple]! +
        r[AtBatResult.homeRun]!;
    expect(hits / (n - walks), greaterThan(0.65)); // 打率6割5分以上
    expect((r[AtBatResult.strikeout] ?? 0) / n, lessThan(0.08));
  });

  test('同じくらいの力の対戦は、従来どおり(打率2割台〜3割)', () {
    final r = _run(avgP, avgB);
    final n = r.values.fold<int>(0, (a, b) => a + b);
    final walks = r[AtBatResult.walk] ?? 0;
    final hits = r[AtBatResult.single]! +
        r[AtBatResult.double]! +
        r[AtBatResult.triple]! +
        r[AtBatResult.homeRun]!;
    expect(hits / (n - walks), inInclusiveRange(0.22, 0.31));
  });

  test('99と10のように力が桁違いなら、強いほうが必ず勝つ', () {
    // 打者99 vs 投手10: 凡退も三振もない(四球かヒット)
    final bat = _run(const Pitcher(control: 10, stuff: 10),
        const Batter(contact: 99, power: 99, eye: 99));
    expect(bat[AtBatResult.out] ?? 0, 0);
    expect(bat[AtBatResult.strikeout] ?? 0, 0);
    // 投手99 vs 打者10: 四球もヒットもない(三振かアウト)
    final pit = _run(const Pitcher(control: 99, stuff: 99),
        const Batter(contact: 10, power: 10, eye: 10));
    expect(pit[AtBatResult.walk] ?? 0, 0);
    for (final r in [
      AtBatResult.single,
      AtBatResult.double,
      AtBatResult.triple,
      AtBatResult.homeRun
    ]) {
      expect(pit[r] ?? 0, 0, reason: r.name);
    }
    // 差が小さければ、結果は混ざる(必ず勝つわけではない)
    final close = _run(const Pitcher(control: 60, stuff: 60),
        const Batter(contact: 55, power: 55, eye: 55));
    expect(close[AtBatResult.out]!, greaterThan(1000));
    expect(close[AtBatResult.single]!, greaterThan(1000));
  });
}
