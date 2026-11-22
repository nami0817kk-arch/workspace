import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/combos.dart';
import 'package:basketball_career/gm/eras.dart';
import 'package:flutter_test/flutter_test.dart';

/// 2026-11-21 の作り込み C-3: 時代の流行。
void main() {
  test('優勝チームの型が流行を動かす(少しずつ。合わせて1のまま)', () {
    var w = [0.25, 0.25, 0.25, 0.25];
    final shooters = [Role.shooter, Role.shooter, Role.stretch, Role.shooter, Role.playmaker];
    w = nextWeights(w, shooters);
    expect(w.fold(0.0, (a, b) => a + b), closeTo(1, 1e-9));
    expect(w[Era.three.index], greaterThan(0.25));
    expect(w[Era.three.index], lessThan(0.5), reason: '一度では移りきらない');
    for (var i = 0; i < 4; i++) {
      w = nextWeights(w, shooters);
    }
    expect(currentEra(w), Era.three);
  });

  test('流行に合う型は値打ちが高く、外れた型は安い', () {
    final c = careerAt(3, 12);
    c.eraWeights = [0.7, 0.1, 0.1, 0.1];
    final everyone = [for (final t in c.teams) ...t.roster];
    final shooter = everyone.where((p) => roleOf(p) == Role.shooter).firstOrNull;
    final stopper = everyone.where((p) => roleOf(p) == Role.stopper).firstOrNull;
    if (shooter != null) expect(c.fashion(shooter), greaterThan(1));
    if (stopper != null) expect(c.fashion(stopper), lessThan(1));
  });

  test('季を回すと流行の記録が残り、保存して読み直しても同じ', () {
    final c = careerAt(4, 12);
    var guard = 0;
    while (c.season < 3 && guard++ < 3000) {
      if (c.phase == Phase.seasonEnd) c.fired = false;
      botStep(c);
    }
    expect(c.eraHistory.length, greaterThanOrEqualTo(2));
    final y = Career.fromJson(c.toJson());
    expect(y.eraWeights, c.eraWeights);
    expect(y.eraHistory, c.eraHistory);
    expect(y.era, c.era);
  });

  test('得意なポジションの無い豊作の年は、流行のポジションが豊作になる', () {
    final c = careerAt(5, 12);
    for (var s = 1; s <= 40; s++) {
      final d = c.draftClassFor(s);
      if (d.quality == 1) expect(d.strongPos, isNotNull);
    }
  });
}
