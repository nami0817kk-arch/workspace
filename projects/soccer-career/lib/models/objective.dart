import 'season.dart';

/// 監督から与えられるシーズンの目標。
///
/// 数字が示されることで、シーズン中の選択に基準ができる。
/// 「無難に安全な手」を選び続けると出場は足りても得点関与が足りない、
/// という形で判断に効く。
class SeasonObjective {
  const SeasonObjective({
    required this.appearances,
    required this.contributions,
    required this.rating,
  });

  /// 出場試合数。
  final int appearances;

  /// ゴール＋アシストの合計。
  final int contributions;

  /// 平均評価点。
  final double rating;

  /// 3つのうちいくつ達成したか。
  int achievedCount(SeasonStats stats) {
    var count = 0;
    if (stats.appearances >= appearances) count++;
    if (stats.goals + stats.assists >= contributions) count++;
    if (stats.averageRating >= rating) count++;
    return count;
  }

  bool achieved(SeasonStats stats) => achievedCount(stats) >= 2;

  Map<String, dynamic> toJson() => {
        'appearances': appearances,
        'contributions': contributions,
        'rating': rating,
      };

  static SeasonObjective? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    return SeasonObjective(
      appearances: json['appearances'] as int,
      contributions: json['contributions'] as int,
      rating: (json['rating'] as num).toDouble(),
    );
  }
}
