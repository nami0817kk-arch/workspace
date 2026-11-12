import 'dart:convert';

import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('相性は50がふつうで、強さに足されるのは ±1.5 まで。保存して読み直しても残る', () {
    final c = careerAt(6, 12);
    expect(c.me.chem, 50);
    expect(c.me.chemEffect, 0);
    c.me.chem = 100;
    expect(c.me.chemEffect, 1.5);
    c.me.chem = 0;
    expect(c.me.chemEffect, -1.5);
    c.me.chem = 70;
    final back = Career.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
    expect(back.me.chem, 70);
  });

  test('新しい選手ばかり・不満が多いと下がり、続けて一緒にいる選手が多く気持ちが高いと上がる', () {
    final up = careerAt(6, 12)..startSeason();
    for (final p in up.me.roster) {
      p
        ..tenure = 3
        ..morale = 85;
    }
    final down = careerAt(6, 12)..startSeason();
    for (final p in down.me.roster) {
      p
        ..tenure = 0
        ..morale = 20;
    }
    for (final c in [up, down]) {
      c.playBlock();
    }
    expect(up.me.chem, greaterThan(down.me.chem));
    expect(down.me.chem, lessThan(50));
    expect(up.chemFactors.unhappy, 0);
    expect(down.chemFactors.unhappy, greaterThan(5));
  });

  test('自由契約の選手の関心は、相性が高いほど上がる', () {
    final c = careerAt(6, 12);
    botStep(c);
    final low = <int>[], high = <int>[];
    for (final p in c.teams[(c.mine + 1) % c.teams.length].roster.take(12)) {
      c.me.chem = 0;
      low.add(c.interest(p, c.mine));
      c.me.chem = 100;
      high.add(c.interest(p, c.mine));
    }
    for (var i = 0; i < low.length; i++) {
      expect(high[i], greaterThanOrEqualTo(low[i]));
    }
    expect(high.fold<int>(0, (a, b) => a + b), greaterThan(low.fold<int>(0, (a, b) => a + b)));
  });
}
