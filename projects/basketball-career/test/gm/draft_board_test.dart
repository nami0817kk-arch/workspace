import 'dart:convert';

import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('次のドラフトの指名の順は、勝率の低い順に1巡目・2巡目で60本。持ち主はトレードで動いた先', () {
    final c = careerAt(5, 12)..startSeason();
    c.playBlock();
    final slots = c.projectedDraftOrder();
    expect(slots, hasLength(c.teams.length * 2));
    for (var k = 1; k < c.teams.length; k++) {
      expect(c.teams[slots[k - 1].$1].winPct, lessThanOrEqualTo(c.teams[slots[k].$1].winPct));
    }
    for (final (from, owner, _) in slots) {
      expect(c.picks.any((p) => p.season == c.season && p.from == from && p.owner == owner), isTrue);
    }
  });

  test('ドラフトが終わると、リーグ全体の指名が過去のドラフトに残り、保存しても残る', () {
    final c = careerAt(5, 12)..startSeason();
    var guard = 0;
    while (!(c.phase == Phase.contracts || c.phase == Phase.preseason) && guard++ < 200) {
      if (c.phase == Phase.seasonEnd) c.fired = false;
      botStep(c);
    }
    expect(c.draftYears(), [1]);
    final h = c.draftHistory;
    expect(h.length, greaterThanOrEqualTo(55));
    expect(h.map((x) => x.no).toSet().length, h.length, reason: '指名の番号は重ならない');
    expect(h.any((x) => x.team == c.mine), isTrue);
    expect(h.any((x) => x.team != c.mine), isTrue);
    final back = Career.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
    expect(back.draftHistory.length, h.length);
    expect(back.draftHistory.first.name, h.first.name);
  });
}
