import 'package:flutter_test/flutter_test.dart';
import 'package:quadrillion/game/game.dart';

import 'support/bot.dart';

/// 1.0.0+11: 「現場の人を増やす」が現金の2割で、会社が大きくなるほど高くなっていた。
/// 足りない分だけを、その分の値段で補えるようにした。
void main() {
  Game grown() {
    final s = Game.newGame(SetupConfig(mode: 'endless', year: 1990, traits: ['charm', 'noble']), rng: ParkMiller(5));
    for (var i = 0; i < 48; i++) {
      botMonth(s);
    }
    return s;
  }

  test('足りない分を補うと、現場の力が事業の力に届き、値段は現金の2割より安い', () {
    final s = grown();
    final b = s.biz.firstWhere((x) => x.model != 'fc');
    // わざと人手不足にする
    b.crew = s.crewOf(b) * .5;
    s.calcAll();
    s.cash = 1e15;
    final need = s.crewNeedCost(b);
    expect(need, greaterThan(0));
    expect(need, lessThan(s.cash * .2));
    s.ap = 3;
    final before = s.cash;
    s.addCrewNeeded(b);
    expect(before - s.cash, closeTo(need, need * 1e-9));
    expect(s.crewEff(b), greaterThanOrEqualTo(b.power * .999));
    expect(s.crewNeedCost(b), lessThan(need * 1e-6));
  });

  test('足りていれば 0 で、押しても何も起きない', () {
    final s = grown();
    final b = s.biz.firstWhere((x) => x.model != 'fc');
    b.crew = s.crewOf(b) * 10;
    s.calcAll();
    expect(s.crewNeedCost(b), 0);
    final c = s.cash;
    s.ap = 3;
    s.addCrewNeeded(b);
    expect(s.cash, c);
    expect(s.ap, 3);
  });

  test('お金が足りなければ減らさない', () {
    final s = grown();
    final b = s.biz.firstWhere((x) => x.model != 'fc');
    b.crew = s.crewOf(b) * .5;
    s.calcAll();
    s.cash = s.crewNeedCost(b) * .5;
    final c = s.cash;
    s.ap = 3;
    s.addCrewNeeded(b);
    expect(s.cash, c);
  });
}
