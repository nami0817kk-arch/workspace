import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/league.dart';

void main() {
  test('直近10試合の点差が残り、保存して読み直しても同じ。見どころは試合の点から', () {
    final c = Career.start(seed: 5);
    c.ownerMeeting(2);
    c.startSeason();
    expect(c.form, isEmpty);
    c.playBlock();
    expect(c.form.length, Career.formLength);
    final mineGames = c.lastGames;
    final last = mineGames.last;
    expect(c.form.last, last.ptsOf(c.mine) - last.ptsAgainst(c.mine));
    final back = Career.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
    expect(back.form, c.form);
    // 見どころ: 20点差の勝ちは「大勝」
    final big = GameResult(home: c.mine, away: (c.mine + 1) % 30, homePts: 130, awayPts: 100);
    expect(c.highlightsOf([big]).single, startsWith('大勝'));
    final close = GameResult(home: c.mine, away: (c.mine + 1) % 30, homePts: 100, awayPts: 101);
    expect(c.highlightsOf([close]).single, startsWith('接戦を落とした'));
  });
}
