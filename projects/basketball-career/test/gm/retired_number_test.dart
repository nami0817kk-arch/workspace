import 'dart:convert';

import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/player.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Career setup(int seasonsWithMe) {
    final c = careerAt(6, 8);
    final p = c.me.roster.first;
    p.career
      ..clear()
      ..addAll([for (var i = 0; i < seasonsWithMe; i++) [i + 1, c.mine, 82, 2400, 700, 500]]);
    for (var i = 0; i < 4; i++) {
      c.awards.add(Award(season: i + 1, kind: AwardKind.mvp, player: p.id, name: p.name, team: c.mine, line: ''));
    }
    p.allStars = 10;
    return c;
  }

  test('背番号は選手の id から決まる(0〜99)', () {
    final c = careerAt(6, 8);
    for (final t in c.teams) {
      for (final p in t.roster) {
        expect(jerseyOf(p), inInclusiveRange(0, 99));
        expect(jerseyOf(p), jerseyOf(p));
      }
    }
  });

  test('自分のチームで4シーズン以上プレーした殿堂入りの選手は永久欠番になる', () {
    final c = setup(6);
    final p = c.me.roster.first;
    c.toHallForTest(p, c.mine);
    expect(c.hall, isNotEmpty);
    expect(c.retiredNumbers, hasLength(1));
    expect(c.retiredNumbers.single[0], jerseyOf(p));
    expect(c.retiredNames.single, p.name);
    expect(c.log.any((l) => l.contains('永久欠番')), isTrue);
    final back = Career.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
    expect(back.retiredNumbers, c.retiredNumbers);
    expect(back.retiredNames, c.retiredNames);
  });

  test('在籍が3シーズン以下なら、殿堂入りしても永久欠番にならない', () {
    final c = setup(3);
    c.toHallForTest(c.me.roster.first, c.mine);
    expect(c.hall, isNotEmpty);
    expect(c.retiredNumbers, isEmpty);
  });
}
