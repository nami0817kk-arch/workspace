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
    final calls = [
      const LiveCall(period: 1, clock: 720, timeout: true),
      ...breakCalls(const [null, GameCall.outside]),
      LiveCall.atBreak(2, GameCall.stars),
    ];
    final q1 = c.previewLive(calls, breakStop(0))!;
    expect(q1.finished, isFalse);
    expect(q1.stop, breakStop(0));
    expect(q1.home.periods.length, 1);
    final half = c.previewLive(calls, breakStop(1))!;
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
    final none = c.previewLive(const [], null)!;
    final calls = c.previewLive(breakCalls(const [GameCall.fast, GameCall.fast, GameCall.bench]), null)!;
    expect((none.home.pts, none.away.pts), isNot((calls.home.pts, calls.away.pts)));
    // 何も選ばなければ、最後まで同じ試合
    final again = c.previewLive(const [], null)!;
    expect((again.home.pts, again.away.pts), (none.home.pts, none.away.pts));
  });

  test('主力で押し切ると主力の出場時間が増え、控えに任せると減る', () {
    final c = _started(7);
    int starterSecs(SimResult r) {
      final t = c.nextMyGame!.$1 == c.mine ? r.home : r.away;
      final idx = [for (var i = 0; i < t.order.length; i++) i]..sort((a, b) => t.mins[b].compareTo(t.mins[a]));
      return idx.take(5).fold(0, (n, i) => n + t.secs[i]);
    }

    final base = starterSecs(c.previewLive(const [], null)!);
    final stars = starterSecs(c.previewLive(breakCalls(const [GameCall.stars]), null)!);
    final bench = starterSecs(c.previewLive(breakCalls(const [GameCall.bench]), null)!);
    expect(stars, greaterThan(base));
    expect(bench, lessThan(base));
  });

  test('見るだけではリーグも選手も変わらない', () {
    final c = _started(9);
    final before = c.toJson().toString();
    c.previewLive(const [LiveCall(period: 1, clock: 500, timeout: true), LiveCall(period: 2, clock: 300, timeout: true), LiveCall(period: 3, clock: 100, timeout: true)], null);
    expect(c.toJson().toString(), before);
  });

  test('クォーターの途中でタイムアウトを取って止めても、そこまでの試合は同じで、続きはその采配で進む', () {
    final c = _started(11);
    final full = c.previewLive(const [], null)!;
    final stopped = c.previewLive(const [], (1, 400))!;
    // 止めた時刻は、2Qの残り400秒を過ぎた最初の攻めの前
    expect(stopped.stop!.$1, 1);
    expect(stopped.stop!.$2, lessThanOrEqualTo(400));
    final n = stopped.events.length;
    expect(n, greaterThan(0));
    for (var i = 0; i < n; i++) {
      expect(stopped.events[i].homePts, full.events[i].homePts);
      expect(stopped.events[i].clockEnd, full.events[i].clockEnd);
    }
    expect(stopped.events.last.clockEnd, stopped.stop!.$2);
    // 止めた所でタイムアウトと指示を入れて続けると、確定した試合もその采配のとおり
    final calls = [LiveCall(period: stopped.stop!.$1, clock: stopped.stop!.$2, timeout: true, call: GameCall.fast)];
    final end = c.previewLive(calls, null)!;
    for (var i = 0; i < n; i++) {
      expect(end.events[i].homePts, full.events[i].homePts);
    }
    final mine = c.nextMyGame!.$1 == c.mine ? 0 : 1;
    final after = end.events.where((e) => e.side == mine && (e.period > 1 || (e.period == 1 && e.clockStart <= stopped.stop!.$2)));
    expect(after.every((e) => e.pace == 2), isTrue);
  });

  test('交代: 止めた所で選んだ5人が、そのあとコートに出る(いつもの起用に戻すまで)', () {
    final c = _started(13);
    final stopped = c.previewLive(const [], breakStop(0))!;
    final me = c.nextMyGame!.$1 == c.mine ? stopped.home : stopped.away;
    final mine = c.nextMyGame!.$1 == c.mine ? 0 : 1;
    // 控えから出られる5人を選ぶ(出場時間の少ない順)
    final avail = [for (var i = 0; i < me.order.length; i++) if (me.mins[i] > 0) i]..sort((a, b) => me.mins[a].compareTo(me.mins[b]));
    final five = (avail.take(5).toList()..sort());
    final end = c.previewLive([LiveCall.atBreak(0, null, five: five), LiveCall.atBreak(1, GameCall.plan)], null)!;
    final q2 = end.events.where((e) => e.period == 1);
    for (final e in q2) {
      expect(e.side == mine ? e.offCourt : e.defCourt, five);
    }
    // 前半の終わりに「いつもの起用に戻す」→ 3Q はいつもの5人に戻る
    final q3 = end.events.where((e) => e.period == 2);
    expect(q3.any((e) => !_same(e.side == mine ? e.offCourt : e.defCourt, five)), isTrue);
  });

  test('出られない選手(けが・休み)を入れた5人は、交代として使わない', () {
    final c = _started(15);
    final stopped = c.previewLive(const [], breakStop(0))!;
    final me = c.nextMyGame!.$1 == c.mine ? stopped.home : stopped.away;
    final out = [for (var i = 0; i < me.order.length; i++) if (me.mins[i] == 0) i];
    if (out.isEmpty) return;
    final bad = [...me.court.take(4), out.first]..sort();
    final x = c.previewLive([LiveCall.atBreak(0, null, five: bad)], null)!;
    final y = c.previewLive(const [], null)!;
    expect((x.home.pts, x.away.pts), (y.home.pts, y.away.pts));
  });
}

bool _same(List<int> a, List<int> b) => a.length == b.length && a.toSet().containsAll(b);
