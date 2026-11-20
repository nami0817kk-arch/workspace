import 'dart:convert';

import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('41試合のあとにカップ戦が行われ、8チームから優勝と準優勝が決まる。82試合の勝敗は変わらない', () {
    final c = careerAt(6, 8)..startSeason();
    c.playBlock();
    expect(c.cupHistory, isEmpty);
    c.playBlock();
    expect(c.cupHistory, hasLength(1));
    final r = c.cupHistory.single;
    expect(r[0], c.season);
    expect(c.cupField, hasLength(8));
    expect(c.cupField.toSet().length, 8);
    expect(c.cupField, contains(r[1]));
    expect(c.cupField, contains(r[2]));
    expect(r[1], isNot(r[2]));
    // 地区の上位4チームずつ
    expect(c.cupField.where((t) => c.teams[t].east).length, 4);
    // 勝敗はカップ戦で増えない(全チーム、ここまでの試合数と一致)
    for (final t in c.teams) {
      expect(t.wins + t.losses, c.roundAt * 1, reason: t.def.short);
    }
    expect(c.log.any((l) => l.contains('カップ戦')), isTrue);
  });

  test('カップ戦に出た自分のチームには賞金が入り、保存して読み直しても結果が残る', () {
    final c = careerAt(6, 1)..startSeason();
    c.playBlock();
    c.playBlock();
    if (c.cupField.contains(c.mine)) {
      expect(c.incomeBy[Income.cup.index], greaterThan(0));
    } else {
      expect(c.incomeBy[Income.cup.index], 0);
    }
    final back = Career.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
    expect(back.cupHistory, c.cupHistory);
    expect(back.cupField, c.cupField);
    expect(back.cupRounds, c.cupRounds);
  });

  test('カップ戦の結果は同じ局面なら同じ(専用の乱数)', () {
    List<int> run() {
      final c = careerAt(6, 8)..startSeason();
      c.playBlock();
      c.playBlock();
      return c.cupHistory.single;
    }

    expect(run(), run());
  });
}
