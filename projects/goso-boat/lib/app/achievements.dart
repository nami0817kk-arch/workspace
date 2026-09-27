import 'progress.dart';

/// 実績。名前と説明は lib/l10n の `ach_名前` / `achDesc_名前`。
///
/// 失敗（脱走された回数）にも実績を付けている。「人のやる回数を減らさない」方針
/// （2026-09-27）のもとで、逃げられても楽しみが残るようにするため。
enum Achievement {
  firstClear,
  clears10,
  clears60,
  allClear,
  threeStar30,
  threeStarAll,
  escape10,
  escape100,
  nightmareThree,
  dailyWeek;

  bool earned(Progress p) => switch (this) {
        firstClear => p.clearedCount >= 1,
        clears10 => p.clearedCount >= 10,
        clears60 => p.clearedCount >= 60,
        allClear => p.clearedCount >= p.levels.length,
        threeStar30 => p.threeStarCount >= 30,
        threeStarAll => p.threeStarCount >= p.levels.length,
        escape10 => p.stat('escapes') >= 10,
        escape100 => p.stat('escapes') >= 100,
        nightmareThree => p.levels.any((l) => l.world == 8 && p.stars(l) == 3),
        dailyWeek => p.stat('maxStreak') >= 7,
      };
}

/// 今回はじめて満たした実績を返し、取ったことを記録する。
Future<List<Achievement>> collectNewAchievements(Progress p) async {
  final fresh = <Achievement>[];
  for (final a in Achievement.values) {
    if (!p.hasAchievement(a.name) && a.earned(p)) {
      await p.markAchievement(a.name);
      fresh.add(a);
    }
  }
  return fresh;
}
