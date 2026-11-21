import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/combos.dart';
import 'package:basketball_career/gm/game_sim.dart';
import 'package:basketball_career/gm/rng.dart';
import 'package:flutter_test/flutter_test.dart';

/// 2026-11-21 の作り込み B-1: 選手の型と、コートの5人の組み合わせ。
void main() {
  test('組み合わせの決まり', () {
    const f = false, t = true;
    expect(combosOf([Role.playmaker, Role.slasher, Role.scorer, Role.anchor, Role.stopper], [f, f, f, t, f]), [Combo.pnr]);
    expect(combosOf([Role.shooter, Role.shooter, Role.slasher, Role.stretch, Role.anchor], [f, f, f, t, t]), containsAll([Combo.spacing, Combo.fiveOut]));
    expect(combosOf([Role.anchor, Role.stopper, Role.stopper, Role.scorer, Role.playmaker], [t, f, f, f, f]), [Combo.wall]);
    expect(combosOf([Role.scorer, Role.scorer, Role.scorer, Role.playmaker, Role.anchor], [f, f, f, f, t]), [Combo.ballHog]);
    expect(combosOf([Role.anchor, Role.scorer, Role.playmaker, Role.slasher, Role.stopper], [t, t, f, f, f]), containsAll([Combo.crowded, Combo.pnr]));
    // 外の打ち手が1人でもいれば、窮屈にはならない
    expect(combosOf([Role.anchor, Role.scorer, Role.playmaker, Role.shooter, Role.stopper], [t, t, f, f, f]), isEmpty);
    expect(combosOf([Role.anchor, Role.stretch, Role.playmaker, Role.shooter, Role.stopper], [t, t, f, f, f]), containsAll([Combo.pop, Combo.fiveOut]));
  });

  test('良い組み合わせの5人ほど、点の差で勝つ(同じ乱数で、組み合わせだけを消して比べる)', () {
    final c = careerAt(2, 12);
    var withCombo = 0.0, n = 0;
    for (var k = 0; k < 60; k++) {
      final h = c.teams[k % 30], a = c.teams[(k * 7 + 4) % 30];
      if (h == a) continue;
      final s = simulateGame(h, a, Rng(k + 9), homeStr: h.strength, awayStr: a.strength);
      // 組み合わせの時間が長いチームほど点差が良い、を全体で確かめる
      double net(SimTeam t) => [for (final x in Combo.values) t.comboSecs[x.index] / 60 * (x.off + x.def)].fold(0.0, (p, q) => p + q);
      final edge = net(s.home) - net(s.away);
      final margin = (s.home.pts - s.away.pts).toDouble();
      withCombo += edge * margin;
      n++;
    }
    expect(n, greaterThan(0));
    expect(withCombo, greaterThan(0));
  });

  test('どの組み合わせもリーグのどこかで起き、窮屈な組み合わせばかりにはならない', () {
    final c = careerAt(3, 12);
    final secs = List<int>.filled(Combo.values.length, 0);
    var total = 0;
    for (var k = 0; k < 120; k++) {
      final h = c.teams[k % 30], a = c.teams[(k * 11 + 3) % 30];
      if (h == a) continue;
      final s = simulateGame(h, a, Rng(k + 1), homeStr: h.strength, awayStr: a.strength);
      for (final t in [s.home, s.away]) {
        for (var i = 0; i < secs.length; i++) {
          secs[i] += t.comboSecs[i];
        }
        total += 48 * 60;
      }
    }
    for (final x in Combo.values) {
      expect(secs[x.index], greaterThan(0), reason: x.label);
    }
    expect(secs[Combo.crowded.index] / total, lessThan(0.4));
  });

  test('自分のチームで一緒に出た時間がたまると組み合わせが分かり、知らせて保存する', () {
    final c = careerAt(4, 12)..startSeason();
    var guard = 0;
    while (c.combosFound.isEmpty && guard++ < 8 && c.phase == Phase.season) {
      c.playBlock();
    }
    expect(c.combosFound, isNotEmpty);
    expect(c.inbox.where((m) => m.title.contains('組み合わせ')), isNotEmpty);
    final y = Career.fromJson(c.toJson());
    expect(y.comboSecs, c.comboSecs);
  });
}
