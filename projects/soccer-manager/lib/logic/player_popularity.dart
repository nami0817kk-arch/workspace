import 'dart:math';

import '../l10n/tr.dart';
import '../models/player.dart';

/// 選手の人気(0〜100)とグッズの売上。保存はせず、力・通算の出場と得点・
/// 生え抜きかどうかから毎回出す。人気の高い選手がいるほどグッズが売れ、
/// 売ればその分の売上が消える。
class PlayerPopularityEngine {
  static int popularity(Player p) {
    final v = (p.overall - 45) * 1.5 +
        min(p.careerGoals, 100) * 0.3 +
        min(p.careerAppearances, 300) * 0.05 +
        (p.isHomegrown ? 10 : 0);
    return v.round().clamp(0, 100);
  }

  /// 人気の言葉。
  static String label(int pop) => pop >= 80
      ? Tr.pick('看板選手', 'Club icon')
      : pop >= 60
          ? Tr.pick('人気者', 'Fan favourite')
          : pop >= 35
              ? Tr.pick('知られている', 'Well known')
              : Tr.pick('まだ無名', 'Little known');

  /// 人気の上位3人の平均から出す、週のグッズの上乗せ(5部の物差しの万円)。
  static int weeklyMerchBonus(Iterable<Player> squad) {
    final pops = [for (final p in squad) popularity(p)]
      ..sort((a, b) => b.compareTo(a));
    if (pops.isEmpty) return 0;
    final top = pops.take(3).toList();
    final avg = top.reduce((a, b) => a + b) / top.length;
    return (avg * 0.4).round();
  }
}
