import 'package:flutter_test/flutter_test.dart';

import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/trade.dart';

void main() {
  test('足りない申し込みに、1つ足せば受けてもらえるものを出す(出せば受ける・元は受けない)', () {
    final c = Career.start(seed: 11);
    var found = 0;
    for (var t = 0; t < c.teams.length && found < 3; t++) {
      if (t == c.mine) continue;
      final star = ([...c.teams[t].roster]..sort((a, b) => b.ovr.compareTo(a.ovr))).first;
      final cheap = ([...c.me.roster]..sort((a, b) => a.ovr.compareTo(b.ovr))).first;
      final o = TradeOffer(partner: t, give: [cheap.id], get: [star.id]);
      if (c.judge(o).ok) continue;
      final s = c.suggestAddition(o);
      if (s == null) continue;
      expect(c.judge(s).ok, isTrue);
      expect(s.give.length + s.givePicks.length, o.give.length + o.givePicks.length + 1);
      expect(s.give, containsAll(o.give));
      found++;
    }
    expect(found, greaterThan(0), reason: '足せば受ける例が1つも無い');
  });
}
