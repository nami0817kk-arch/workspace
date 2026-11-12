import 'dart:convert';

import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/league.dart';
import 'package:basketball_career/gm/player.dart';
import 'package:basketball_career/gm/policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('全部「ふつう」なら強さは変わらない。方針の上乗せは ±1.5 に収まる', () {
    final c = careerAt(6, 12);
    expect(c.me.policy.every((x) => x == 1), isTrue);
    expect(c.me.policyEffect, 0);
    final base = c.me.strength;
    var maxAbs = 0.0;
    for (var a = 0; a < PolicyAxis.values.length; a++) {
      for (var v = 0; v < 3; v++) {
        c.setPolicy(a, v);
        maxAbs = maxAbs > c.me.policyEffect.abs() ? maxAbs : c.me.policyEffect.abs();
      }
      c.setPolicy(a, 1);
    }
    expect(maxAbs, lessThanOrEqualTo(1.5));
    expect(c.me.strength, base);
  });

  test('選手の持ち味に合う選択ほど強さが上がる。外が得意な選手ばかりなら「外のシュート」が合う', () {
    final c = careerAt(6, 12);
    for (final p in c.me.roster) {
      p.attrs[Attr.outside.index] = 9;
      p.attrs[Attr.inside.index] = -9;
    }
    c.setPolicy(PolicyAxis.focus.index, 0);
    final good = c.me.policyEffect;
    c.setPolicy(PolicyAxis.focus.index, 2);
    final bad = c.me.policyEffect;
    expect(good, greaterThan(bad));
    expect(good, greaterThan(0));
    expect(bad, lessThan(0));
    // 合う選手には ◎、合わない選手には △
    final p = c.me.roster.first;
    c.setPolicy(PolicyAxis.focus.index, 0);
    expect(fitMark(p, c.me.policy), '◎');
    c.setPolicy(PolicyAxis.focus.index, 2);
    expect(fitMark(p, c.me.policy), '△');
  });

  test('ヘッドコーチの得意な方針は名前から決まり、同じ選択には少し上乗せされる', () {
    final c = careerAt(6, 12);
    final hc = c.me.coachOf(Staff.coach)!;
    final fav = coachFavorite(hc);
    expect(coachFavorite(hc), fav);
    expect(fav.length, PolicyAxis.values.length);
    expect(fav.every((x) => x >= 0 && x <= 2), isTrue);
  });

  test('方針は保存して読み直しても残る', () {
    final c = careerAt(6, 12);
    c.setPolicy(0, 2);
    c.setPolicy(3, 0);
    final back = Career.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
    expect(back.me.policy, c.me.policy);
    expect(back.me.policyEffect, c.me.policyEffect);
  });
}
