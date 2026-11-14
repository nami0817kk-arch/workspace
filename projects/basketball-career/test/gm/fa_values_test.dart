import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/personality.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('自由契約: 勝ちたい選手は勝率で関心が大きく動き、お金の選手は額で動く', () {
    final c = careerAt(4, 12);
    final t = c.teams[(c.mine + 5) % 30];
    final players = [for (final x in c.teams) if (x != t) ...x.roster.where((p) => p.ovr < 60)];
    final win = players.firstWhere((p) => personalityOf(p).value == Value.win);
    final money = players.firstWhere((p) => personalityOf(p).value == Value.money);
    expect(c.faPriority(win), '勝てるチーム');
    expect(c.faPriority(money), '年俸の額');
    int at(int w, p) {
      t
        ..wins = w
        ..losses = 82 - w;
      return c.interest(p, t.index);
    }

    final swingWin = at(55, win) - at(27, win);
    final swingMoney = at(55, money) - at(27, money);
    expect(swingWin, greaterThan(swingMoney + 5));
  });

  test('忠誠の選手は前のチームへの関心が高い', () {
    final c = careerAt(4, 12);
    final p = [for (final x in c.teams) ...x.roster].firstWhere((p) => personalityOf(p).value == Value.loyal && !personalityOf(p).traits.contains(Trait.hometown));
    final other = (c.mine + 7) % 30;
    final before = c.interest(p, other);
    p.career.add([c.season, other, 10, 50, 20, 10]);
    expect(c.lastTeamOf(p), other);
    expect(c.interest(p, other), before + 10);
  });
}
