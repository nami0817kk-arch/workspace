import 'package:flutter_test/flutter_test.dart';
import 'package:quadrillion/game/game.dart';

import 'support/bot.dart';

/// 1.0.0+11: 「現場の人を増やす」が現金の2割で、会社が大きくなるほど高くなっていた。足りない分だけを補えるようにした。
/// 1.0.0+12: 足りない分を人数（N人）に直し、1人の年の人件費から値段を決めるようにした。
/// 1.1.0+26: 店などの数で売上が頭打ちのときは、売れる分を回せるだけの人（crewWant）が要る人数になった。事業の力までは要らない
void main() {
  Game grown() {
    final s = Game.newGame(SetupConfig(mode: 'endless', year: 1990, traits: ['charm', 'noble']), rng: ParkMiller(5));
    for (var i = 0; i < 48; i++) {
      botMonth(s);
    }
    return s;
  }

  test('足りない分（N人）を雇うと、現場の力が事業の力に届き、1人少なければ届かない', () {
    final s = grown();
    final b = s.biz.firstWhere((x) => x.model != 'fc');
    // わざと人手不足にする
    b.crew = s.crewOf(b) * .05;
    s.calcAll();
    s.cash = 1e15;
    final need = s.crewNeedPeople(b);
    expect(need, greaterThan(0));
    // 1人少ない人数では足りない
    final want = s.crewWant(b);
    expect(s.crewEff(b) + (need - 1) * s.crewPerHead(b) * s.crewMult(b), lessThan(want));
    s.ap = 3;
    final before = s.cash, up0 = b.upkeep;
    s.addCrewNeeded(b);
    expect(before - s.cash, closeTo(s.hireCost(b, need), 1));
    expect(b.upkeep - up0, closeTo(s.payPerMonth(b, need), 1));
    expect(s.crewEff(b), greaterThanOrEqualTo(want * .999));
    expect(s.crewNeedPeople(b), lessThanOrEqualTo(1), reason: '雇ったあと売れる量の見積もりが少し動くので、1人までの差は許す');
  });

  test('crewMult は crewEff の倍と同じ', () {
    final s = grown();
    for (final b in s.biz) {
      expect(s.crewOf(b) * s.crewMult(b), closeTo(s.crewEff(b), s.crewEff(b) * 1e-12));
    }
  });

  test('足りていれば 0 人で、押しても何も起きない', () {
    final s = grown();
    final b = s.biz.firstWhere((x) => x.model != 'fc');
    b.crew = s.crewOf(b) * 10;
    s.calcAll();
    expect(s.crewNeedPeople(b), 0);
    final c = s.cash;
    s.ap = 3;
    s.addCrewNeeded(b);
    expect(s.cash, c);
    expect(s.ap, 3);
  });

  test('お金が足りなければ減らさない', () {
    final s = grown();
    final b = s.biz.firstWhere((x) => x.model != 'fc');
    b.crew = s.crewOf(b) * .05;
    s.calcAll();
    s.cash = s.hireCost(b, s.crewNeedPeople(b)) * .5;
    final c = s.cash;
    s.ap = 3;
    expect(tx(s.addCrewNeeded(b)), 'お金が足りません');
    expect(s.cash, c);
  });
}
