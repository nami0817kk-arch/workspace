import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/inbox.dart';
import 'package:flutter_test/flutter_test.dart';

/// 2年目のシーズン前まで進める。
Career _atPreseason(int seed) {
  final c = careerAt(seed, 12);
  var guard = 0;
  while (!(c.phase == Phase.preseason && c.season >= 2)) {
    if (c.phase == Phase.seasonEnd) c.fired = false;
    botStep(c);
    if (guard++ > 5000) fail('シーズン前に着かない');
  }
  return c;
}

Message _forecastMsg(Career c) => c.inbox.firstWhere((m) => m.kind == MsgKind.forecast && m.season == c.season);

void main() {
  test('シーズン前に、自分の地区の順位予想が戦力の順で出る', () {
    final c = _atPreseason(1);
    expect(c.forecastSeason, c.season);
    expect(c.forecast.length, 15);
    expect(c.forecast.every((i) => c.teams[i].east == c.me.east), isTrue);
    for (var i = 1; i < c.forecast.length; i++) {
      expect(c.strengthRank(c.forecast[i - 1]), lessThanOrEqualTo(c.strengthRank(c.forecast[i])));
    }
    expect(c.forecastRank, c.forecast.indexOf(c.mine) + 1);
    expect(_forecastMsg(c).needsAnswer, isTrue);
  });

  test('「覆してみせる」と答えると、結果で人気と信頼が動く。答えなければ動かない', () {
    var beatSeen = false, missSeen = false;
    for (final seed in [1, 2, 3, 4, 5, 6, 7, 8]) {
      final a = _atPreseason(seed);
      final b = _atPreseason(seed);
      a.answer(_forecastMsg(a).id, 0);
      expect(a.forecastBet, 1);
      final rank = a.forecastRank;
      while (a.phase != Phase.seasonEnd) {
        botStep(a);
      }
      while (b.phase != Phase.seasonEnd) {
        botStep(b);
      }
      // 答えたほうと答えないほうで、試合の結果は同じ(予想は乱数を使わない)
      expect(a.me.wins, b.me.wins);
      expect(a.confRank, b.confRank);
      final beat = a.confRank < rank;
      if (beat) {
        beatSeen = true;
        expect(a.hype, greaterThan(b.hype));
      } else {
        missSeen = true;
        expect(a.hype, lessThanOrEqualTo(b.hype));
      }
      expect(a.inbox.any((m) => m.title == '予想は$rank位、結果は${a.confRank}位'), isTrue);
    }
    expect(beatSeen || missSeen, isTrue);
  });
}
