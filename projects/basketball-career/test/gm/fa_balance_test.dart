import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/offseason_show.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('自由契約: 傾いているチームは申し込みの中から選ばれ、終わると勝ち組・負け組が出る', () {
    final c = careerAt(9, 15)..startSeason();
    var guard = 0;
    var sawLeaning = false;
    while (!(c.phase == Phase.preseason && c.season == 2) && guard++ < 300) {
      if (c.phase == Phase.seasonEnd) c.fired = false;
      if (c.phase == Phase.contracts && c.faDay < 3) {
        // 自動で遊ぶ GM は日を一度に進めるので、ここで1日ずつ進めて途中の申し込みを見る
        c.nextFaDay();
        for (final p in c.freeAgents) {
          final t = c.leaningTo(p);
          final bs = c.bids[p.id];
          if (bs == null || bs.isEmpty) {
            expect(t, -1);
          } else {
            expect(bs.map((b) => b.team), contains(t));
            sawLeaning = true;
          }
        }
      }
      botStep(c);
    }
    expect(c.phase, Phase.preseason);
    expect(sawLeaning, isTrue, reason: '申し込みのある選手が一度はいる');
    final (win, lose) = faBalance(c);
    expect(c.faMoves, isNotEmpty);
    expect(win.every((b) => b.net > 0), isTrue);
    expect(lose.every((b) => b.net < 0), isTrue);
    for (var i = 1; i < win.length; i++) {
      expect(win[i - 1].net, greaterThanOrEqualTo(win[i].net));
    }
    expect(win.length, lessThanOrEqualTo(3));
  });
}
