import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/trade.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('指名権は今年から7回のドラフト分ある', () {
    final c = careerAt(6, 8);
    final seasons = c.picks.map((p) => p.season).toSet();
    expect(seasons.length, pickYears);
    expect(c.picks.length, pickYears * 2 * c.teams.length);
  });

  test('自分の1巡目を2年続けて手放すトレードはできない。1年おきならよい', () {
    final c = careerAt(6, 8);
    int own(int s, int r) => c.picks.indexWhere((p) => p.from == c.mine && p.season == c.season + s && p.round == r);
    final a = own(0, 1), b = own(1, 1), d = own(2, 1);
    expect(stepienProblem(c.teams, c.picks, c.mine, [a, b], []), isNotNull);
    expect(stepienProblem(c.teams, c.picks, c.mine, [a, d], []), isNull);
    expect(stepienProblem(c.teams, c.picks, c.mine, [a], []), isNull);
    // 2巡目は手放してよい
    expect(stepienProblem(c.teams, c.picks, c.mine, [own(0, 2), own(1, 2)], []), isNull);
    // 受け取れば、2年続けて手放したことにならない
    final other = c.picks.indexWhere((p) => p.from != c.mine && p.round == 1);
    expect(stepienProblem(c.teams, c.picks, c.mine, [a, b], [other]), isNotNull, reason: '自分の指名権でなければ数えない');
  });
}
