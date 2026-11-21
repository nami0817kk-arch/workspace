import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/game_review.dart';
import 'package:basketball_career/gm/game_sim.dart';
import 'package:basketball_career/gm/rng.dart';
import 'package:flutter_test/flutter_test.dart';

/// 2026-11-21: 采配した試合のあとの「ふりかえり」(勝因・敗因、采配の効き目、主役)。
void main() {
  final c = Career.start(seed: 31);
  final teams = c.teams;

  test('勝ったら有利だったもの、負けたら不利だったものを、差の大きい順に3つまで', () {
    var seen = 0;
    for (var k = 0; k < 30; k++) {
      final h = teams[k % 30], a = teams[(k * 13 + 7) % 30];
      if (h == a) continue;
      final s = simulateGame(h, a, Rng(k + 50), homeStr: h.strength, awayStr: a.strength, record: true);
      for (final side in [0, 1]) {
        final won = (side == 0 ? s.home.pts > s.away.pts : s.away.pts > s.home.pts);
        final rs = reasonsOf(s, side);
        expect(rs.length, lessThanOrEqualTo(3));
        for (final x in rs) {
          expect(won ? x.value > 0 : x.value < 0, isTrue, reason: x.text);
        }
        for (var i = 1; i < rs.length; i++) {
          expect(rs[i - 1].value.abs(), greaterThanOrEqualTo(rs[i].value.abs()));
        }
        seen += rs.length;
      }
    }
    expect(seen, greaterThan(0));
  });

  test('采配の効き目は、その時刻から3分の両チームの点', () {
    final h = teams[2], a = teams[3];
    const call = LiveCall(period: 1, clock: 720, call: GameCall.fast);
    final s = simulateGame(h, a, Rng(7), homeStr: h.strength, awayStr: a.strength, record: true, calls: const [call], side: 0);
    final e = callEffectsOf(s, const [call], 0).single;
    var mine = 0, theirs = 0;
    for (final x in s.events) {
      final at = elapsedOf(x.period, x.clockStart);
      if (at >= 720 && at < 900) {
        if (x.side == 0) {
          mine += x.points;
        } else {
          theirs += x.points;
        }
      }
    }
    expect((e.mine, e.theirs), (mine, theirs));
    expect(mine + theirs, greaterThan(0));
  });

  test('主役と、ボックススコア用の結果(点の合計が合う)', () {
    final h = teams[4], a = teams[5];
    final s = simulateGame(h, a, Rng(9), homeStr: h.strength, awayStr: a.strength, record: true);
    final st = starsOf(s, 0);
    expect(st.$1.$1, isNotEmpty);
    expect(st.$2.$1, isNotEmpty);
    final g = reviewResultOf(s, h, a, h.index);
    expect(g.box.fold(0, (n, l) => n + l.pts), s.home.pts);
    expect(g.oppBox.fold(0, (n, l) => n + l.pts), s.away.pts);
    expect((g.homePts, g.awayPts), (s.home.pts, s.away.pts));
  });

  test('流れの線の印: 采配の数だけ金の印、3Q以降の逆転は白の印', () {
    final h = teams[6], a = teams[7];
    final calls = breakCalls(const [GameCall.outside, null, GameCall.stars]);
    final s = simulateGame(h, a, Rng(13), homeStr: h.strength, awayStr: a.strength, record: true, calls: calls, side: 0);
    final m = flowMarksOf(s, calls, (c) => '${c.period}');
    expect(m.where((x) => x.$3).length, 2);
    expect(m.where((x) => x.$3).map((x) => x.$1), [12, 36]);
    expect(m.where((x) => !x.$3).length, lessThanOrEqualTo(s.leadChanges));
  });
}
