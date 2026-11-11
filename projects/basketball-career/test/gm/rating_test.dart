import 'dart:convert';

import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/difficulty.dart';
import 'package:basketball_career/gm/profile.dart';
import 'package:basketball_career/gm/rating.dart';
import 'package:flutter_test/flutter_test.dart';

/// [n] シーズン、解任されずに進める(botStep は careerSeasons 年で打ち切るので、ここでは自分で回す)。
Career _play(Career c, int n) {
  var guard = 0;
  while (c.history.length < n && guard++ < 3000) {
    if (c.phase == Phase.seasonEnd) {
      c.fired = false;
      if (c.history.length >= n) break;
      c.toOffseason();
    } else {
      botStep(c);
    }
  }
  return c;
}

void main() {
  group('GM の格', () {
    test('通算の点から10段階。次の段階までの点が分かる', () {
      expect(ratingFloors, hasLength(10));
      expect(ratingNames, hasLength(10));
      expect(ratingLevelOf(0), 1);
      expect(ratingLevelOf(49), 1);
      expect(ratingLevelOf(50), 2);
      expect(ratingLevelOf(3599), 9);
      expect(ratingLevelOf(3600), 10);
      expect(ratingLevelOf(99999), 10);
      expect(nextRatingFloor(0), 50);
      expect(nextRatingFloor(3600), isNull);
      for (var i = 1; i < ratingFloors.length; i++) {
        expect(ratingFloors[i], greaterThan(ratingFloors[i - 1]));
      }
    });

    test('任期に上限は無い。10年を超えて続き、自分で終えるか解任されるまで終わらない', () {
      final c = _play(careerAt(6, 8), 11);
      expect(c.history.length, 11);
      expect(c.phase, Phase.seasonEnd);
      c.toOffseason();
      expect(c.phase, Phase.draft, reason: '11年目のあとも、オフに進んで続く');
      // 自分で終えられるのは、シーズンの結果を見ているときだけ
      c.endCareer();
      expect(c.phase, isNot(Phase.over));
      final d = _play(careerAt(6, 8), 2);
      d.endCareer();
      expect(d.phase, Phase.over);
    });

    test('解任されたら、任期は終わる(続きはできない)', () {
      final c = careerAt(6, 28);
      var guard = 0;
      while (c.phase != Phase.seasonEnd && guard++ < 50) {
        botStep(c);
      }
      c.fired = true;
      c.toOffseason();
      expect(c.phase, Phase.over);
    });

    test('シーズンの点は内訳の合計で、通算に足される。最初の10シーズンの点はそこで止まる', () {
      final c = careerAt(6, 0);
      var before = 0, before10 = 0, late = 0;
      for (var n = 1; n <= 12; n++) {
        _play(c, n);
        final sum = c.lastRating.fold(0, (s, x) => s + x.points);
        expect(c.gmPoints - before, sum, reason: '$n シーズン目');
        expect(c.gmPointsFirst10 - before10, n <= 10 ? sum : 0, reason: '$n シーズン目');
        if (n > 10) late += sum;
        before = c.gmPoints;
        before10 = c.gmPointsFirst10;
        if (c.phase == Phase.seasonEnd) c.toOffseason();
      }
      expect(c.gmPoints, greaterThan(0));
      expect(c.gmPoints - c.gmPointsFirst10, late, reason: '11・12シーズン目の点は、通算だけに入る');
    });

    test('優勝すると100点が入る(ふつう)。やさしいほど少なく、きびしいほど多い', () {
      // 優勝するシーズンを探す(強いチームで種を変える)
      for (var seed = 1; seed < 80; seed++) {
        final base = careerAt(seed, 0);
        base.startSeason();
        while (base.phase == Phase.season) {
          base.playBlock();
        }
        List<RatingPart> parts(Difficulty d) {
          final c = Career.fromJson(jsonDecode(jsonEncode(base.toJson())) as Map<String, dynamic>)..difficulty = d;
          c.playPlayoffs();
          return c.lastRating;
        }

        final normal = parts(Difficulty.normal);
        final champ = normal.any((x) => x.label == '優勝');
        if (!champ) continue;
        expect(normal.firstWhere((x) => x.label == '優勝').points, 100);
        expect(parts(Difficulty.easy).firstWhere((x) => x.label == '優勝').points, 70);
        expect(parts(Difficulty.hard).firstWhere((x) => x.label == '優勝').points, 150);
        return;
      }
      fail('優勝する種が見つからない');
    });

    test('保存に残り、読み直しても同じ。前の版の保存(点が無い)は0点から', () {
      final c = _play(careerAt(6, 8), 2);
      final copy = Career.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
      expect(copy.gmPoints, c.gmPoints);
      expect(copy.gmPointsFirst10, c.gmPointsFirst10);
      expect(copy.lastRating.map((x) => x.toJson()).toList(), c.lastRating.map((x) => x.toJson()).toList());
      final old = c.toJson()
        ..remove('gp')
        ..remove('gp10')
        ..remove('rp');
      final loaded = Career.fromJson(jsonDecode(jsonEncode(old)) as Map<String, dynamic>);
      expect(loaded.gmPoints, 0);
      expect(loaded.lastRating, isEmpty);
    });

    test('実績: 格が5になる・10年を解任されずに務める。記録に最高の格が残る', () {
      final c = _play(careerAt(6, 8), 10);
      final p = Profile();
      p.recordSeason(c);
      expect(p.has(Achievement.fullTerm), isTrue);
      expect(p.has(Achievement.longHaul), isFalse);
      expect(p.has(Achievement.level5), c.gmLevel >= 5);
      c.gmPoints = ratingFloors[4];
      final got = p.recordSeason(c);
      expect(got, contains(Achievement.level5));
      expect(p.bestLevel, 5);
      c.gmPoints = ratingFloors[9];
      expect(p.recordSeason(c), contains(Achievement.level10));
      expect(p.bestLevel, 10);
      // 保存
      final back = Profile.fromJson(jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>);
      expect(back.bestLevel, 10);
      expect(back.has(Achievement.level10), isTrue);
    });
  });
}
