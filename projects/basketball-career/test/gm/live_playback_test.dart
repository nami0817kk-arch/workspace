import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/game_sim.dart';
import 'package:basketball_career/gm/rng.dart';
import 'package:basketball_career/ui/gm/live_playback.dart';
import 'package:flutter_test/flutter_test.dart';

/// 2026-11-21: 采配の画面で、コートの10人とボールを動かして試合を流して見せる。
void main() {
  final c = Career.start(seed: 21);
  final teams = c.teams;

  test('攻めごとの記録を取っても、試合の結果は変わらない(乱数を使わない)', () {
    for (var k = 0; k < 40; k++) {
      final h = teams[k % 30], a = teams[(k * 11 + 5) % 30];
      if (h == a) continue;
      final x = simulateGame(h, a, Rng(k + 3), homeStr: h.strength, awayStr: a.strength);
      final y = simulateGame(h, a, Rng(k + 3), homeStr: h.strength, awayStr: a.strength, record: true);
      expect([y.home.pts, y.away.pts], [x.home.pts, x.away.pts]);
      expect(y.flow, x.flow);
      for (var i = 0; i < x.home.order.length; i++) {
        expect(y.home.stat[i], x.home.stat[i]);
      }
      for (var i = 0; i < x.away.order.length; i++) {
        expect(y.away.stat[i], x.away.stat[i]);
      }
      expect(x.events, isEmpty);
      expect(y.events, isNotEmpty);
    }
  });

  test('記録した攻めの点を足すと、試合の点になる', () {
    for (var k = 0; k < 40; k++) {
      final h = teams[(k + 2) % 30], a = teams[(k * 7 + 9) % 30];
      if (h == a) continue;
      final s = simulateGame(h, a, Rng(k + 100), homeStr: h.strength, awayStr: a.strength, record: true);
      var hp = 0, ap = 0;
      for (final e in s.events) {
        expect(e.clockStart, greaterThanOrEqualTo(e.clockEnd));
        expect(e.offCourt.length, 5);
        expect(e.defCourt.length, 5);
        if (e.side == 0) {
          hp += e.points;
        } else {
          ap += e.points;
        }
        expect([e.homePts, e.awayPts], [hp, ap]);
      }
      // 同点のまま上限に来たときだけ1点を足す(起きないはず)ので、ほぼ必ず合う
      expect(hp, s.home.pts);
      expect(ap, s.away.pts);
    }
  });

  test('動きを作ると、点の出来事が攻めの点と合い、10人とボールはコートの中(とベンチ)にいる', () {
    final h = teams[3], a = teams[17];
    final s = simulateGame(h, a, Rng(77), homeStr: h.strength, awayStr: a.strength, record: true);
    final b = PlaybackBuilder(
      events: s.events,
      names: (w) => (w.$1 == 0 ? s.home : s.away).order[w.$2].name,
      poss: (w) => (w.$1 == 0 ? s.home : s.away).order[w.$2].pos,
      share: (side) => (side == 0 ? s.home : s.away).share,
    );
    Map<Who, Offset>? end;
    var lines = 0;
    for (var i = 0; i < s.events.length; i++) {
      final e = s.events[i];
      final p = b.build(i, end);
      expect(p.duration, greaterThan(300));
      final got = p.cues.where((x) => x.kind == CueKind.score).fold(0, (n, x) => n + x.points);
      expect(got, e.points, reason: '攻め $i');
      for (var t = 0; t <= p.duration; t += 90) {
        final f = p.frameAt(t);
        for (final k in [for (final x in e.offCourt) (e.side, x), for (final x in e.defCourt) (1 - e.side, x)]) {
          expect(f.pos.containsKey(k), isTrue);
        }
        for (final o in [...f.pos.values, f.ball]) {
          expect(o.dx, inInclusiveRange(-1.0, courtLen + 1.0));
          expect(o.dy, inInclusiveRange(-1.0, courtWid + 1.5));
        }
      }
      if (p.line.isNotEmpty) lines++;
      end = p.end;
    }
    expect(lines, s.events.length);
  });

  test('ここまでの選手の数字とランの数え方', () {
    final h = teams[5], a = teams[6];
    final s = simulateGame(h, a, Rng(9), homeStr: h.strength, awayStr: a.strength, record: true);
    var pts = 0;
    for (var i = 0; i < s.home.order.length; i++) {
      pts += todayOf(s.events, s.events.length, (0, i)).pts;
    }
    expect(pts, s.home.pts);
    final run = runOf(s.events, s.events.length);
    expect(run.$1, anyOf(0, 1));
    expect(run.$2, greaterThan(0));
  });
}
