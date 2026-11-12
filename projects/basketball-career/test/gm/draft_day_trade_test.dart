import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/trade.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ドラフトの最中にもトレードができ、指名権を渡すとその指名は相手のものになる', () {
    final c = careerAt(6, 25);
    var guard = 0;
    while (c.phase != Phase.draft && guard++ < 100) {
      if (c.phase == Phase.seasonEnd) c.fired = false;
      botStep(c);
    }
    expect(c.phase, Phase.draft);
    expect(c.canTrade, isTrue);
    // 今年の自分の2巡目をほかのチームの選手と交換する(ステピエンに当たらない2巡目)
    final mine2 = c.picks.indexWhere((p) => p.from == c.mine && p.owner == c.mine && p.season == c.season && p.round == 2);
    expect(mine2, isNonNegative);
    final partner = (c.mine + 1) % c.teams.length;
    final partnerPick = c.picks.indexWhere((p) => p.owner == partner && p.round == 2 && p.season == c.season + 1);
    final o = TradeOffer(partner: partner, give: const [], get: const [], givePicks: [mine2], getPicks: [partnerPick]);
    final v = c.judge(o);
    if (v.ok) {
      expect(c.propose(o), isTrue);
      expect(c.picks[mine2].owner, partner);
    } else {
      // 釣り合わなくても、「今はトレードできない」ではないこと
      expect(v.reason, isNot(contains('今はトレードできない')));
    }
  });
}
