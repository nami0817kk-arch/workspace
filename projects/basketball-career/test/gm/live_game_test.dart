import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/game_sim.dart';
import 'package:flutter_test/flutter_test.dart';

Career _started(int seed) {
  final c = careerAt(seed, 15);
  while (c.phase != Phase.season) {
    botStep(c);
  }
  return c;
}

void main() {
  test('途中で止めて見ても、確定した試合は見たとおりの点になる', () {
    final c = _started(3);
    final calls = <GameCall?>[GameCall.timeout, null, GameCall.outside, GameCall.stars];
    final q1 = c.previewLive(calls, 0)!;
    expect(q1.finished, isFalse);
    expect(q1.home.periods.length, 1);
    final half = c.previewLive(calls, 1)!;
    expect(half.home.periods.length, 2);
    // 1Qの点は、止める位置で変わらない
    expect(half.home.periods.first, q1.home.periods.first);
    final end = c.previewLive(calls, null)!;
    expect(end.finished, isTrue);
    final g = c.nextMyGame!;
    final rounds = c.roundAt;
    c.playLiveDay(calls);
    expect(c.roundAt, rounds + 1);
    final got = c.lastGames.last;
    expect(got.home, g.$1);
    expect((got.homePts, got.awayPts), (end.home.pts, end.away.pts));
  });

  test('采配はその試合に効く(同じ乱数でも、采配が違えば点が変わる)', () {
    final c = _started(5);
    final none = c.previewLive(const [null, null, null, null], null)!;
    final calls = c.previewLive(const [GameCall.fast, GameCall.fast, GameCall.bench, GameCall.bench], null)!;
    expect((none.home.pts, none.away.pts), isNot((calls.home.pts, calls.away.pts)));
    // 何も選ばなければ、最後まで同じ試合
    final again = c.previewLive(const [null, null, null, null], null)!;
    expect((again.home.pts, again.away.pts), (none.home.pts, none.away.pts));
  });

  test('主力で押し切ると主力の出場時間が増え、控えに任せると減る', () {
    final c = _started(7);
    int starterSecs(SimResult r) {
      final t = c.nextMyGame!.$1 == c.mine ? r.home : r.away;
      final idx = [for (var i = 0; i < t.order.length; i++) i]..sort((a, b) => t.mins[b].compareTo(t.mins[a]));
      return idx.take(5).fold(0, (n, i) => n + t.secs[i]);
    }

    final base = starterSecs(c.previewLive(const [null, null, null, null], null)!);
    final stars = starterSecs(c.previewLive(const [GameCall.stars, null, null, null], null)!);
    final bench = starterSecs(c.previewLive(const [GameCall.bench, null, null, null], null)!);
    expect(stars, greaterThan(base));
    expect(bench, lessThan(base));
  });

  test('見るだけではリーグも選手も変わらない', () {
    final c = _started(9);
    final before = c.toJson().toString();
    c.previewLive(const [GameCall.timeout, GameCall.timeout, GameCall.timeout, null], null);
    expect(c.toJson().toString(), before);
  });
}
