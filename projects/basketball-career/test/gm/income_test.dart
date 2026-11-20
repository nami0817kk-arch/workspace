import 'dart:convert';

import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/league.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('市場の大きさは30チーム分あり、平均はほぼ1', () {
    expect(marketSizes.length, teamDefs.length);
    final mean = marketSizes.reduce((a, b) => a + b) / marketSizes.length;
    expect(mean, inInclusiveRange(0.97, 1.05));
  });

  test('収入の内訳の合計は、収入の合計に等しい。シーズンを進めると各項目が増える', () {
    final c = careerAt(6, 12);
    var guard = 0;
    while (c.phase != Phase.seasonEnd && guard++ < 200) {
      botStep(c);
      expect(c.incomeBy.fold(0, (a, b) => a + b), c.revenue);
    }
    for (final i in Income.values) {
      expect(c.incomeBy[i.index], greaterThanOrEqualTo(0), reason: i.label);
    }
    expect(c.incomeBy[Income.tv.index], greaterThan(0));
    expect(c.incomeBy[Income.gate.index], greaterThan(0));
    expect(c.incomeBy[Income.concession.index], greaterThan(0));
    expect(c.incomeBy[Income.sponsor.index], greaterThan(0));
    expect(c.incomeBy[Income.merch.index], greaterThan(0));
  });

  test('売店の値段を上げると売店の収入は増えるが、客の入りは少し減る。市場が大きいほどスポンサーとグッズが多い', () {
    final c = careerAt(6, 12);
    c.setConcession(0);
    final lowAtt = c.attendance, lowShop = c.concessionPerGame;
    c.setConcession(2);
    expect(c.attendance, lessThan(lowAtt));
    expect(c.concessionPerGame, greaterThan(lowShop));
    final big = Career.start(seed: 6, team: 10); // ニューヨーク(1.5倍)
    final small = Career.start(seed: 6, team: 9); // ミルウォーキー(0.7倍)
    expect(big.baseIncomeParts[Income.sponsor]!, greaterThan(small.baseIncomeParts[Income.sponsor]!));
    expect(big.baseIncomeParts[Income.tv], small.baseIncomeParts[Income.tv]);
  });

  test('保存して読み直しても、収入の内訳と売店の値段が残る', () {
    final c = careerAt(6, 12);
    c.setConcession(2);
    var guard = 0;
    while (c.revenue == 0 && guard++ < 50) {
      botStep(c);
    }
    final back = Career.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
    expect(back.incomeBy, c.incomeBy);
    expect(back.concessionLevel, 2);
  });
}
