/// 出た試合と出なかった試合の成績。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/game/impact.dart';
import 'package:soccer_career/models/season.dart';

MatchResult _result({
  required Appearance appearance,
  required int scored,
  required int conceded,
  bool international = false,
}) => MatchResult(
  matchday: 1,
  opponentName: 'X',
  home: true,
  scored: scored,
  conceded: conceded,
  appearance: appearance,
  rating: appearance.played ? 7.0 : null,
  goals: 0,
  assists: 0,
  international: international,
);

void main() {
  test('出た試合と出なかった試合を分けて数える', () {
    final impact = Impact.of([
      _result(appearance: Appearance.start, scored: 2, conceded: 0),
      _result(appearance: Appearance.sub, scored: 1, conceded: 1),
      _result(appearance: Appearance.benched, scored: 0, conceded: 3),
      _result(appearance: Appearance.injured, scored: 1, conceded: 2),
    ]);
    expect(impact.with_.label, '1勝1分0敗');
    expect(impact.without.label, '0勝0分2敗');
    expect(impact.with_.pointsPerGame, 2.0);
    expect(impact.without.pointsPerGame, 0.0);
    expect(impact.comparable, isTrue);
  });

  test('出なかった試合が少ないうちは、比べない', () {
    final impact = Impact.of([
      _result(appearance: Appearance.start, scored: 1, conceded: 0),
      _result(appearance: Appearance.benched, scored: 0, conceded: 1),
    ]);
    expect(impact.comparable, isFalse);
  });
}
