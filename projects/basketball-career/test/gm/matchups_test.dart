import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/game_sim.dart';
import 'package:basketball_career/gm/policy.dart';
import 'package:basketball_career/gm/rng.dart';
import 'package:flutter_test/flutter_test.dart';

/// 2026-11-21 の作り込み B-2: 方針どうしの相性(じゃんけん)・AIの方針・慣れ・切り替え・プレーオフの対策。
void main() {
  test('相性の決まり', () {
    final c = careerAt(1, 12);
    final s = simulateGame(c.teams[0], c.teams[1], Rng(3), homeStr: 70, awayStr: 70);
    final o = s.home, d = s.away;
    o
      ..focus = 2
      ..share = 1
      ..pace = 1;
    d
      ..press = 0
      ..pace = 1;
    expect(matchupsOf(o, d), [Matchup.packVsInside]);
    o.focus = 0;
    expect(matchupsOf(o, d), [Matchup.packVsOutside]);
    d.press = 2;
    o
      ..focus = 1
      ..share = 0;
    expect(matchupsOf(o, d), [Matchup.pressVsAce]);
    o.share = 2;
    expect(matchupsOf(o, d), [Matchup.pressVsPass]);
    d.press = 1;
    o
      ..share = 1
      ..pace = 2;
    d.pace = 0;
    expect(matchupsOf(o, d).single, anyOf(Matchup.runVsSlow, Matchup.runBack));
  });

  test('有利な相性の側が、同じ乱数で点を取る(相手が中を固めるなら外から攻める方が良い)', () {
    final c = careerAt(2, 12);
    var outside = 0, inside = 0;
    for (var k = 0; k < 40; k++) {
      final h = c.teams[k % 30], a = c.teams[(k + 9) % 30];
      final keepH = List.of(h.policy), keepA = List.of(a.policy);
      a.policy[PolicyAxis.defense.index] = 0;
      h.policy[PolicyAxis.focus.index] = 0;
      outside += simulateGame(h, a, Rng(k + 1), homeStr: h.strength, awayStr: a.strength).home.pts;
      h.policy[PolicyAxis.focus.index] = 2;
      inside += simulateGame(h, a, Rng(k + 1), homeStr: h.strength, awayStr: a.strength).home.pts;
      h.policy = keepH;
      a.policy = keepA;
    }
    expect(outside, greaterThan(inside));
  });

  test('AIの監督は選手に合う方針を選ぶ(全部「ふつう」のままではない)。自分のチームは変えない', () {
    final c = careerAt(3, 12);
    final mine = List.of(c.me.policy);
    c.startSeason();
    expect(c.me.policy, mine);
    final changed = c.teams.where((t) => t.index != c.mine && t.policy.any((x) => x != 1)).length;
    expect(changed, greaterThan(5));
  });

  test('方針を変えずに続けると慣れで強くなり、変えるとゼロに戻る。保存もする', () {
    final c = careerAt(4, 12)..startSeason();
    final before = c.me.strength;
    c.playBlock();
    expect(c.policyGames, greaterThan(5));
    expect(c.me.familiar, closeTo(c.familiarity, 1e-9));
    expect(c.me.strength, greaterThan(before - 5));
    final y = Career.fromJson(c.toJson());
    expect(y.policyGames, c.policyGames);
    expect(y.me.familiar, closeTo(c.familiarity, 1e-9));
    final cur = c.me.policy[PolicyAxis.focus.index];
    c.setPolicy(PolicyAxis.focus.index, (cur + 1) % 3);
    expect(c.policyGames, 0);
    expect(c.me.familiar, 0);
  });

  test('負けているAIは、前半か3Qの終わりに方針を切り替える(遊ぶ人のチームは切り替えない)', () {
    final c = careerAt(5, 12);
    var seen = 0;
    for (var k = 0; k < 60 && seen == 0; k++) {
      final h = c.teams[k % 30], a = c.teams[(k * 7 + 2) % 30];
      if (h == a) continue;
      final s = simulateGame(h, a, Rng(k + 5), homeStr: h.strength, awayStr: a.strength, userSide: 0);
      for (final (q, side, _) in s.switches) {
        expect(q, anyOf(2, 3));
        expect(side, 1);
        seen++;
      }
    }
    expect(seen, greaterThan(0));
  });

  test('方針の相性は、試合で確かめるとたまって分かり、保存する', () {
    final c = careerAt(6, 12);
    c.setPolicy(PolicyAxis.focus.index, 0);
    c.startSeason();
    for (var i = 0; i < 4 && c.phase == Phase.season; i++) {
      c.playBlock();
    }
    expect(c.matchupSeen.any((x) => x > 0), isTrue);
    final y = Career.fromJson(c.toJson());
    expect(y.matchupSeen, c.matchupSeen);
  });
}
