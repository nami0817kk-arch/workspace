import 'package:flutter_test/flutter_test.dart';
import 'package:quadrillion/game/game.dart';

import 'support/bot.dart';

/// 試作と同じ数値になる箇所（期待値は試作の関数を node で動かして得たもの）
void main() {
  test('お金の書き方が試作の yen と同じ', () {
    const cases = <(double, String)>[
      (0, '0円'),
      (5, '5円'),
      (9999, '9999円'),
      (12345, '1万円'),
      (1234567, '123万円'),
      (1.5e8, '1.5億円'),
      (123456789012, '1,235億円'),
      (1.23456e12, '1.23兆円'),
      (999.95e12, '1,000兆円'),
      (2.5e16, '2.5京円'),
      (-5e8, '-5億円'),
      (1.2345e11, '1,235億円'),
      (12.345e8, '12.3億円'),
      (double.nan, '-'),
      (double.infinity, '-'),
      (22050492.87749534, '2,205万円'),
    ];
    for (final c in cases) {
      expect(yen(c.$1), c.$2, reason: '${c.$1}');
    }
  });

  test('割合の書き方が試作の pct と同じ', () {
    const cases = <(double, String)>[
      (0, '0%'),
      (.5, '0.50%'),
      (.004, '0.00%'),
      (1, '1%'),
      (12.34, '12.3%'),
      (50, '50%'),
      (33.35, '33.4%'),
      (-2.25, '-2.2%'),
      (99.99, '100%'),
    ];
    for (final c in cases) {
      expect(pct(c.$1), c.$2, reason: '${c.$1}');
    }
  });

  test('地域の広さ・業種の盛衰・国の市場が試作と同じ', () {
    expect(regFor(1980), [1, 3, 10]);
    expect(regFor(2007.5), [1, 4.5, 16.25]);
    expect(regFor(2025), [1, 6, 25]);
    expect(regFor(2050), [1, 6, 25]);
    final era = [
      eraF(indm['yatai']!, 1950),
      eraF(indm['yatai']!, 1990),
      eraF(indm['ff']!, 1983),
      eraF(indm['ff']!, 1971),
      eraF(indm['depart']!, 2005),
      eraF(indm['ai']!, 2030),
    ];
    const want = [1, 0.30000000000000004, 0.53, 0.06, 0.6266666666666667, 0.5939143501126971];
    for (var i = 0; i < want.length; i++) {
      expect(era[i], closeTo(want[i], 1e-12));
    }
    expect(cw('jp', 2000), closeTo(1, 1e-12));
    expect(cw('us', 2010), closeTo(4.75, 1e-12));
    expect(cw('cn', 1990), closeTo(0.3523500545797774, 1e-12));
    expect(cw('in', 2040), closeTo(2.225448706454414, 1e-12));
  });

  test('定義の数（試作の業種112・シナジー98・大シナジー10に足して、業種200・国24）', () {
    expect(IND_BASE.length, 112);
    expect(SYN_BASE.length, 98);
    expect(BIG_BASE.length, 10);
    expect(IND.length, 200);
    expect(SYN.length, 98 + 43);
    expect(BIG.length, 13);
    expect(CTRY.length, 24);
    expect(TRAITS.length, 10);
    expect(STRAITS.length, 10);
    expect(RIVALS.length, 8);
    for (final s in SYN) {
      expect(indm.containsKey(s.a) && indm.containsKey(s.b), isTrue, reason: s.k);
    }
    for (final g in BIG) {
      for (final x in g.set) {
        expect(indm.containsKey(x), isTrue, reason: x);
      }
    }
  });

  test('はじめの数字: 資金・社長の年齢・宿敵4社・候補3人', () {
    final s = Game.newGame(SetupConfig(year: 1980, traits: ['charm', 'gambler']), rng: ParkMiller(1));
    expect(s.cash, closeTo(4e7 * nomOf(1980), 1e-3));
    expect(s.pres.age, 22);
    expect(s.cos.where((c) => c.rival != null).length, 4);
    expect(s.cands.length, 3);
    expect(s.ap, 3);
    expect(s.culture, 'family'); // 人たらし → 家族的
    final noble = Game.newGame(SetupConfig(year: 2000, traits: ['noble', 'careful']), rng: ParkMiller(1));
    expect(noble.cash, closeTo(4e7 * nomOf(2000) * 4, 1e-3));
    expect(noble.culture, 'steady');
    expect(noble.cands.length, 3);
  });

  test('最初の事業は手を使わず、力は元手の1.5倍', () {
    final s = Game.newGame(SetupConfig(year: 1980, traits: ['charm', 'careful']), rng: ParkMiller(3));
    final ind = indm['yatai']!;
    final c = s.capexOf(ind);
    final cash0 = s.cash;
    s.startBiz('yatai');
    expect(s.ap, 3);
    expect(s.cash, closeTo(cash0 - c, 1e-6));
    expect(s.biz.single.power, closeTo(c * 1.5, 1e-6));
    expect(s.biz.single.crew, closeTo(c * 1.5 * 1.2, 1e-6));
    // 2つ目からは手を1つ使う
    final next = s.liveInds().firstWhere((i) => i.id != 'yatai' && s.capexOf(i) <= s.cash);
    s.startBiz(next.id);
    expect(s.ap, 2);
  });
}
