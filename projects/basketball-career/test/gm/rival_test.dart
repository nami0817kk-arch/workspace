import 'dart:convert';

import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('自分の試合のたびに、相手ごとの勝ち負けが数えられ、合計は自分の勝敗に等しい', () {
    final c = careerAt(6, 8)..startSeason();
    c.playBlock();
    c.playBlock();
    var w = 0, l = 0;
    for (final r in c.h2h.values) {
      w += r[0];
      l += r[1];
    }
    expect(w, c.me.wins);
    expect(l, c.me.losses);
  });

  test('プレーオフで当たった相手は宿敵になりやすく、保存しても残る', () {
    final c = careerAt(6, 1);
    var guard = 0;
    while (c.phase != Phase.seasonEnd && guard++ < 200) {
      botStep(c);
    }
    final po = c.h2h.values.fold(0, (a, r) => a + r[2]);
    expect(po, greaterThan(0), reason: '強いチームはプレーオフで誰かと当たる');
    expect(c.rival, isNotNull);
    expect(c.rivalLine(c.rival!), contains('プレーオフで'));
    final back = Career.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
    expect(back.h2h.keys, c.h2h.keys);
    expect(back.rival, c.rival);
  });
}
