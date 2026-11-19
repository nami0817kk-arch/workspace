import 'package:basketball_career/gm/calendar.dart';
import 'package:basketball_career/gm/league.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('暦: 10月21日に開幕し、4月中旬に終わる。日付は毎節進み、締め切りのあとは7日の休み', () {
    for (final season in [1, 2, 5]) {
      final first = roundDate(season, 0), last = roundDate(season, gamesPerSeason - 1);
      expect((first.month, first.day, first.year), (10, 21, seasonYear(season)));
      expect(last.month, 4);
      expect(last.day, inInclusiveRange(8, 16));
      for (var r = 1; r < gamesPerSeason; r++) {
        final gap = roundDate(season, r).difference(roundDate(season, r - 1)).inDays;
        expect(gap, r == blockStart(tradeDeadlineBlock) ? 7 : inInclusiveRange(2, 3), reason: '$r節目');
      }
      expect(deadlineDate(season), roundDate(season, blockStart(tradeDeadlineBlock) - 1));
      expect(allStarDate(season).isAfter(deadlineDate(season)), isTrue);
      expect(allStarDate(season).isBefore(roundDate(season, blockStart(tradeDeadlineBlock))), isTrue);
    }
  });

  test('暦: 曜日つきの見出しと、月の残りの試合数', () {
    // 2026年10月21日は水曜
    expect(roundLabel(1, 0), '10月21日(水)');
    expect(dateShort(roundDate(1, 0)), '10/21');
    var sum = 0;
    for (var r = 0; r < gamesPerSeason; r += roundsLeftInMonth(1, r)) {
      final n = roundsLeftInMonth(1, r);
      expect(n, greaterThan(0));
      sum += n;
    }
    expect(sum, gamesPerSeason);
    expect(roundsLeftInMonth(1, gamesPerSeason), 0);
  });
}
