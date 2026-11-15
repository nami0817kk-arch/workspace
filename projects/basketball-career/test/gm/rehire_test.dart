import 'dart:convert';

import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:flutter_test/flutter_test.dart';

/// 1シーズン目の終わりに解任されたところまで進める(目標を届かない勝ち数にして、信頼を1にしておく)。
Career _fired() {
  final c = careerAt(8, 10)..startSeason();
  var guard = 0;
  while (c.phase != Phase.playoffs && guard++ < 60) {
    botStep(c);
  }
  c
    ..trust = 1
    ..target = 82;
  guard = 0;
  while (c.phase != Phase.seasonEnd && guard++ < 60) {
    botStep(c);
  }
  return c;
}

void main() {
  test('解任されると、ほかのチームから誘いが届き、受けるとそのチームの GM としてオフから続けられる', () {
    final c = _fired();
    expect(c.fired, isTrue);
    expect(c.canTakeJob, isTrue);
    expect(c.jobOffers, hasLength(2), reason: 'GM の格が低いうちは2つ');
    expect(c.jobOffers, isNot(contains(c.mine)));
    final old = c.mine;
    final to = c.jobOffers.first;
    final points = c.gmPoints;
    c.takeJob(to);
    expect(c.mine, to);
    expect(c.fired, isFalse);
    expect(c.trust, 40);
    expect(c.gmPoints, points, reason: '格の点は持っていく');
    expect(c.stints, [
      [old, 1],
      [to, 2],
    ]);
    expect(c.teamOfSeason(1), old);
    expect(c.teamOfSeason(2), to);
    expect(c.canTakeJob, isFalse);
    // 経歴の表は2行。1行目は前のチームの成績
    final rows = c.gmCareer();
    expect(rows, hasLength(2));
    expect(rows.first.team, old);
    expect(rows.first.wins, c.history.first.wins);
    // そのままオフへ進める(任期は終わらない)
    c.toOffseason();
    expect(c.phase, isNot(Phase.over));
    // 保存しても残る
    final back = Career.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
    expect(back.mine, to);
    expect(back.stints, c.stints);
  });

  test('誘いを受けずに任期を終えることもできる。誘いの外のチームには移れない', () {
    final c = _fired();
    final outside = [for (var t = 0; t < c.teams.length; t++) if (t != c.mine && !c.jobOffers.contains(t)) t].first;
    final before = c.mine;
    c.takeJob(outside);
    expect(c.mine, before);
    c.toOffseason();
    expect(c.phase, Phase.over);
  });

  test('解任されていなければ誘いは届かない', () {
    final c = careerAt(8, 10)..startSeason();
    var guard = 0;
    while (c.phase != Phase.seasonEnd && guard++ < 60) {
      botStep(c);
    }
    if (c.fired) return;
    expect(c.jobOffers, isEmpty);
    expect(c.canTakeJob, isFalse);
  });

  test('GM の格がどの段階でも、誘いの選び方は止まり、重ならない(候補の数が7の倍数でも)', () {
    final c = _fired();
    for (var pts = 0; pts <= 3000; pts += 50) {
      c.gmPoints = pts;
      final offers = c.debugMakeOffers();
      expect(offers.toSet().length, offers.length);
      expect(offers.length, c.gmLevel >= 3 ? 3 : 2);
      expect(offers, isNot(contains(c.mine)));
    }
  });
}
