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
  dailyWeek,
  perfect1,
  perfect2,
  perfect3,
  perfect4,
  perfect5,
  perfect6,
  perfect7,
  perfect8,
  firstTryThree,
  nightmareNoUndo;

  /// 舞台 [w] の全面を星3で解いたか。
  static bool _worldPerfect(Progress p, int w) => p.levels.where((l) => l.world == w).every((l) => p.stars(l) == 3);

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
        perfect1 => _worldPerfect(p, 1),
        perfect2 => _worldPerfect(p, 2),
        perfect3 => _worldPerfect(p, 3),
        perfect4 => _worldPerfect(p, 4),
        perfect5 => _worldPerfect(p, 5),
        perfect6 => _worldPerfect(p, 6),
        perfect7 => _worldPerfect(p, 7),
        perfect8 => _worldPerfect(p, 8),
        firstTryThree => p.stat('firstTryThree') >= 1,
        nightmareNoUndo => p.stat('nightmareNoUndo') >= 1,
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
