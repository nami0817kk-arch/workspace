import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/game_sim.dart';
import 'package:basketball_career/gm/league.dart';
import 'package:basketball_career/gm/rng.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final c = Career.start(seed: 11);
  final teams = c.teams;

  test('個人の数字の合計がチームの点と合い、出場時間は1試合240分(延長は+25分ずつ)前後になる', () {
    for (var k = 0; k < 200; k++) {
      final h = teams[k % 30], a = teams[(k * 7 + 3) % 30];
      if (h == a) continue;
      final s = simulateGame(h, a, Rng(k + 1), homeStr: h.strength, awayStr: a.strength, record: true);
      expect(s.home.pts, isNot(s.away.pts));
      for (final t in [s.home, s.away]) {
        final lines = boxLinesOf(t);
        expect(lines.fold(0, (n, l) => n + l.pts), t.pts);
        expect(t.periods.fold(0, (n, x) => n + x), t.pts);
        for (final l in lines) {
          expect(l.pts, 2 * (l.fgm - l.tpm) + 3 * l.tpm + l.ftm);
          expect(l.fgm, lessThanOrEqualTo(l.fga));
          expect(l.tpm, lessThanOrEqualTo(l.tpa));
          expect(l.ftm, lessThanOrEqualTo(l.fta));
        }
        final secs = t.secs.fold(0, (n, x) => n + x);
        expect(secs, (48 + 5 * s.overtimes) * 60 * 5);
      }
      expect(s.flow.length, 48 + 5 * s.overtimes);
      expect(s.flow.last, s.home.pts - s.away.pts);
      expect(s.plays, isNotEmpty);
    }
  });

  test('同じ種なら同じ試合になる', () {
    final h = teams[0], a = teams[1];
    final x = simulateGame(h, a, Rng(5), homeStr: h.strength, awayStr: a.strength);
    final y = simulateGame(h, a, Rng(5), homeStr: h.strength, awayStr: a.strength);
    expect([x.home.pts, x.away.pts], [y.home.pts, y.away.pts]);
  });

  test('強いチームほど勝ち、勝率は試合前の見込み(winChance)とおおむね合う', () {
    var wins = 0.0, expected = 0.0, n = 0;
    final r = Rng(3);
    for (var k = 0; k < 1500; k++) {
      final h = teams[r.nextInt(30)], a = teams[r.nextInt(30)];
      if (h == a) continue;
      final hs = h.strength, as_ = a.strength;
      if ((hs - as_).abs() < 3) continue;
      final s = simulateGame(h, a, Rng(r.next()), homeStr: hs, awayStr: as_);
      final strongHome = hs > as_;
      if ((s.home.pts > s.away.pts) == strongHome) wins++;
      final p = winChance(hs, as_);
      expected += strongHome ? p : 1 - p;
      n++;
    }
    expect(n, greaterThan(300));
    expect(wins / n, greaterThan(0.6));
    expect((wins - expected).abs() / n, lessThan(0.06));
  });

  test('試合の結果に流れと見せ場が残り、保存して読み直しても同じ', () {
    final car = Career.start(seed: 21);
    car
      ..startSeason()
      ..playBlock();
    final g = car.lastGames.first;
    expect(g.flow.length, greaterThanOrEqualTo(48));
    expect(g.plays, isNotEmpty);
    final back = GameResult.fromJson(g.toJson());
    expect(back.flow, g.flow);
    expect(back.plays, g.plays);
    expect(back.leadChanges, g.leadChanges);
    expect(back.overtime, g.overtime);
    expect(back.box.fold(0, (n, l) => n + l.pts), g.ptsOf(car.mine));
  });
}
