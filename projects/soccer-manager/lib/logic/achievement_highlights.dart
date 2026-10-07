import '../models/achievement.dart';
import '../models/save_game.dart';
import '../models/team.dart';

/// 未達成の実績と、その進み具合。
class AchievementProgress {
  final Achievement achievement;
  final int current;
  final int target;

  const AchievementProgress({
    required this.achievement,
    required this.current,
    required this.target,
  });

  /// 0.0〜1.0。目標が0以下なら0として扱う。
  double get ratio =>
      target <= 0 ? 0 : (current / target).clamp(0.0, 1.0).toDouble();

  /// あと何回・何件で届くか。
  int get remaining => (target - current).clamp(0, target);
}

/// 実績のうち「あと少しで届くもの」を選び出す。
///
/// 実績は33件あり、5つのカテゴリに分かれて達成済みと未達成が混ざって
/// 並んでいる。どれが手の届く位置にあるのかは、全部のバーを目で追って
/// 比べないと分からない。次に狙えるものが分かれば、そのシーズンの
/// 過ごし方が変わる。
class AchievementHighlights {
  /// 「あと少し」に出す下限。半分にも達していないものを並べると、
  /// 見出しの意味が無くなる。
  static const double nearThreshold = 0.5;

  /// 出す件数の上限。多いと結局「全部を見る」のと同じになる。
  static const int maxHighlights = 3;

  /// 達成に近い未達成の実績を、近い順に返す。
  ///
  /// 進み具合を数値で表せない実績(連覇・無敗優勝など)は対象外。
  /// 比べる基準が無いので、並べても近いかどうかが言えない。
  static List<AchievementProgress> almostThere(
    List<Achievement> all,
    SaveGame save,
    Team userTeam, {
    required bool Function(String id) isUnlocked,
  }) {
    final candidates = <AchievementProgress>[];
    for (final a in all) {
      if (a.progress == null) continue;
      if (isUnlocked(a.id)) continue;
      final (current, target) = a.progress!(save, userTeam);
      if (target <= 0) continue;
      final p =
          AchievementProgress(achievement: a, current: current, target: target);
      if (p.ratio < nearThreshold) continue;
      candidates.add(p);
    }
    candidates.sort((a, b) {
      final byRatio = b.ratio.compareTo(a.ratio);
      if (byRatio != 0) return byRatio;
      // 同じ割合なら、残りが少ない方が先。1/2 と 50/100 では前者が近い。
      final byRemaining = a.remaining.compareTo(b.remaining);
      if (byRemaining != 0) return byRemaining;
      // 並び順が実行ごとに変わらないようにする。
      return a.achievement.id.compareTo(b.achievement.id);
    });
    return candidates.take(maxHighlights).toList();
  }
}
