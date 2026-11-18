import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('自分のトレードを記録し、今の力で評価する。保存される', () {
    final c = careerAt(5, 15);
    while (c.phase != Phase.season) {
      botStep(c);
    }
    // 自分の選手を欲しがるチームの申し込みを受ける
    for (final p in [...c.me.order]) {
      final offers = c.blockOffers(p.id);
      if (offers.isNotEmpty && c.acceptBlockOffer(offers.first)) break;
    }
    expect(c.myTrades, isNotEmpty);
    final t = c.myTrades.first;
    expect(t.give.isNotEmpty || t.givePicks > 0, isTrue);
    final score = c.tradeScore(t);
    expect(tradeGradeOf(score), isIn(['A+', 'A', 'B', 'C', 'D', 'F']));
    final back = Career.fromJson(c.toJson());
    expect(back.myTrades.length, c.myTrades.length);
    expect(back.myTrades.first.give, t.give);
    expect(back.tradeScore(back.myTrades.first), score);
  });

  test('評価の文字は点の高い順に A+ から F', () {
    expect(tradeGradeOf(40), 'A+');
    expect(tradeGradeOf(20), 'A');
    expect(tradeGradeOf(8), 'B');
    expect(tradeGradeOf(0), 'C');
    expect(tradeGradeOf(-10), 'D');
    expect(tradeGradeOf(-30), 'F');
  });

  test('シーズンの終わりに、年ごとの成績へその年の OVR を残す', () {
    final c = careerAt(3, 15);
    var guard = 0;
    while (c.season < 2 && guard++ < 4000) {
      if (c.phase == Phase.seasonEnd) c.fired = false;
      botStep(c);
    }
    final rows = [for (final t in c.teams) for (final p in t.roster) ...p.career];
    expect(rows, isNotEmpty);
    expect(rows.every((r) => r.length == 7), isTrue);
    // 保存して戻しても、OVR の入った行が残る
    final back = Career.fromJson(c.toJson());
    final backRows = [for (final t in back.teams) for (final p in t.roster) ...p.career];
    expect(backRows.length, rows.length);
  });
}
