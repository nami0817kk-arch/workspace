import 'dart:convert';

import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/records.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('試合を重ねると記録帳に1試合の記録と連勝が載り、保存しても残る', () {
    final c = careerAt(6, 8)..startSeason();
    var guard = 0;
    while (c.phase == Phase.season && guard++ < 10) {
      c.playBlock();
    }
    expect(c.records['g_pts'], isNotNull);
    expect(c.records['g_pts']!.value, greaterThan(10));
    expect(c.records['g_reb'], isNotNull);
    final back = Career.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
    expect(back.records.keys, c.records.keys);
    expect(back.records['g_pts']!.value, c.records['g_pts']!.value);
  });

  test('シーズンの終わりにシーズンの記録が載り、破ると知らせが出る', () {
    final c = careerAt(6, 8);
    var guard = 0;
    while (c.phase != Phase.seasonEnd && guard++ < 200) {
      botStep(c);
    }
    expect(c.records['s_wins'], isNotNull);
    expect(c.records['s_ppg'], isNotNull);
    expect(recordText('s_ppg', 21.46), '21.5');
    expect(recordText('g_pts', 41), '41');
  });

  test('前の記録を破ると、記録更新の知らせがニュースに残る', () {
    final c = careerAt(6, 8)..startSeason();
    c.records['g_pts'] = const RecordEntry(1, 'だれか', 1);
    final before = c.log.length;
    c.playBlock();
    expect(c.records['g_pts']!.value, greaterThan(1));
    expect(c.log.length, greaterThan(before));
    expect(c.log.any((l) => l.contains('記録更新') && l.contains('1試合の得点')), isTrue);
  });
}
