/// クラブを手放したときに殿堂へ残す、オーナーとしての1球団ぶんの実績。
///
/// 売却後も消えない。数字は手放した時点の成績アーカイブから集める。
class OwnerLegacy {
  /// 手放したクラブ名。
  final String clubName;

  /// 持っていたシーズン数。
  final int seasons;

  /// リーグ優勝の回数。
  final int leagueTitles;

  /// 国内カップなどの優勝の回数。
  final int cupTitles;

  /// そのクラブでの最高順位(1が最高)。シーズンが無ければ 0。
  final int bestRank;

  /// 手放した理由。
  final SaleReason reason;

  const OwnerLegacy({
    required this.clubName,
    required this.seasons,
    required this.leagueTitles,
    required this.cupTitles,
    required this.bestRank,
    required this.reason,
  });

  Map<String, dynamic> toJson() => {
        'clubName': clubName,
        'seasons': seasons,
        'leagueTitles': leagueTitles,
        'cupTitles': cupTitles,
        'bestRank': bestRank,
        'reason': reason.name,
      };

  factory OwnerLegacy.fromJson(Map<String, dynamic> json) => OwnerLegacy(
        clubName: json['clubName'] as String? ?? '',
        seasons: json['seasons'] as int? ?? 0,
        leagueTitles: json['leagueTitles'] as int? ?? 0,
        cupTitles: json['cupTitles'] as int? ?? 0,
        bestRank: json['bestRank'] as int? ?? 0,
        reason: SaleReason.values.firstWhere(
          (r) => r.name == json['reason'],
          orElse: () => SaleReason.supporters,
        ),
      );
}

/// クラブを手放すことになった理由。
enum SaleReason {
  /// サポーターの期待が尽きた(成績不振)。
  supporters,

  /// 株主の期待が尽きた(収支の悪化)。
  shareholders,
}
