import 'package:basketball_career/game/match.dart';
import 'package:basketball_career/ui/labels.dart';
import 'package:flutter_test/flutter_test.dart';

MatchResult _m({
  bool won = true,
  int team = 80,
  int opp = 70,
  int pts = 12,
  int reb = 4,
  int ast = 3,
  int stl = 1,
  int blk = 0,
  int threes = 1,
  int ot = 0,
  bool fouledOut = false,
  BoxScore box = const BoxScore(),
}) =>
    MatchResult(
      won: won,
      teamScore: team,
      oppScore: opp,
      points: pts,
      rebounds: reb,
      assists: ast,
      steals: stl,
      blocks: blk,
      threes: threes,
      overtimes: ot,
      fouledOut: fouledOut,
      box: box,
    );

void main() {
  group('試合の見どころ', () {
    test('ふつうの試合では何も出ない', () {
      expect(matchHighlights(_m()), isEmpty);
    });

    test('延長の勝ち・負けを語る(2回以上なら回数も)', () {
      expect(matchHighlights(_m(ot: 1)).first, contains('延長の末に勝ち切った'));
      expect(matchHighlights(_m(won: false, team: 70, opp: 72, ot: 2)).first,
          contains('2度の延長の末に力尽きた'));
    });

    test('ダブルダブルとトリプルダブル', () {
      expect(matchHighlights(_m(pts: 18, reb: 11)).join(), contains('ダブルダブル'));
      expect(matchHighlights(_m(pts: 18, reb: 11, ast: 10)).join(), contains('トリプルダブル'));
    });

    test('チームの4割以上を一人で取ると、その割合を語る(リーグの点数の規模によらない)', () {
      final h = matchHighlights(_m(team: 50, pts: 22));
      expect(h.join(), contains('44%'));
      expect(matchHighlights(_m(team: 110, pts: 22)), isEmpty, reason: '最高峰の110点中の22点は目立たない');
    });

    test('3Pの量・退場・スティール・ブロック・高確率', () {
      expect(matchHighlights(_m(threes: 6)).join(), contains('3Pを6本'));
      expect(matchHighlights(_m(fouledOut: true)).join(), contains('退場'));
      expect(matchHighlights(_m(stl: 5)).join(), contains('5スティール'));
      expect(matchHighlights(_m(blk: 4)).join(), contains('4ブロック'));
      expect(
          matchHighlights(_m(box: const BoxScore(fgMade: 9, fgAttempts: 12, minutes: 30))).join(),
          contains('12本中9本'));
    });

    test('見どころは多くても2つまで', () {
      final h = matchHighlights(_m(ot: 1, pts: 30, team: 70, reb: 12, ast: 11, threes: 6, stl: 5, blk: 4, fouledOut: true));
      expect(h, hasLength(2));
    });
  });
}
