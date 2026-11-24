import '../l10n/tr.dart';

/// 地域貢献の活動(2026-11-25 の第6段)。
///
/// 以前は「地域貢献 Lv1〜5」を一度払って上げるだけだった。現実のクラブの
/// 地域活動は毎年の取り組みなので、季ごとに活動を選び、その季の費用を払う
/// 形にした。選んだ活動は次の季にも続ける(費用は季の切り替えで払う。
/// 払えなければ止まる)。
enum CommunityActivity {
  /// 子どものサッカー教室。
  clinics,

  /// 地域の清掃・募金。
  cleanup,

  /// 地元の招待デー(ホームの試合に地元の人を招く)。
  invitation,

  /// 病院・施設の訪問。
  visits,

  /// 商店街・地元企業との連携。
  localBusiness,
}

extension CommunityActivityInfo on CommunityActivity {
  String get label => switch (this) {
        CommunityActivity.clinics =>
          Tr.pick('子どものサッカー教室', 'Kids\' coaching clinics'),
        CommunityActivity.cleanup =>
          Tr.pick('地域の清掃・募金', 'Clean-ups and fundraising'),
        CommunityActivity.invitation =>
          Tr.pick('地元の招待デー', 'Local invitation days'),
        CommunityActivity.visits =>
          Tr.pick('病院・施設の訪問', 'Hospital and care-home visits'),
        CommunityActivity.localBusiness =>
          Tr.pick('商店街・地元企業との連携', 'Ties with local shops and firms'),
      };

  /// 1季の費用(5部の物差しの万円。部の倍率を掛けて払う)。
  int get seasonCost => switch (this) {
        CommunityActivity.clinics => 150,
        CommunityActivity.cleanup => 80,
        CommunityActivity.invitation => 200,
        CommunityActivity.visits => 80,
        CommunityActivity.localBusiness => 120,
      };

  /// 毎月のサポーターの期待への上乗せ。
  int get supporterMonthly => switch (this) {
        CommunityActivity.clinics => 1,
        CommunityActivity.visits => 1,
        _ => 0,
      };

  /// 季の終わりに起きうる不祥事の傷を浅くする量(期待の下がり幅を減らす)。
  int get scandalCushion => switch (this) {
        CommunityActivity.cleanup => 2,
        CommunityActivity.visits => 1,
        CommunityActivity.localBusiness => 1,
        _ => 0,
      };

  /// 選んだ季の、来たいファンの数への上乗せ(%)。一度だけ。
  int get demandPercent => switch (this) {
        CommunityActivity.invitation => 3,
        CommunityActivity.clinics => 1,
        _ => 0,
      };

  /// 季の終わりに入る、地元からの協賛(費用に対する割合%)。
  int get sponsorBackPercent => switch (this) {
        CommunityActivity.localBusiness => 60,
        _ => 0,
      };

  /// 効き目の1行。
  String get effectLabel {
    final parts = <String>[
      if (supporterMonthly > 0)
        Tr.pick('期待 毎月+$supporterMonthly',
            'Expectation +$supporterMonthly a month'),
      if (demandPercent > 0)
        Tr.pick(
            '来たいファン+$demandPercent%', 'Fans wanting to come +$demandPercent%'),
      if (scandalCushion > 0)
        Tr.pick('不祥事の傷-$scandalCushion', 'Scandal damage -$scandalCushion'),
      if (sponsorBackPercent > 0)
        Tr.pick('地元の協賛(費用の$sponsorBackPercent%)',
            'Local backing ($sponsorBackPercent% of cost)'),
    ];
    return parts.join(Tr.pick('・', ', '));
  }

  /// 旧セーブの「地域貢献 Lv」を活動へ移す。以前の効き目(Lv1以上で毎月
  /// +1・Lv の数だけ不祥事の傷が浅い)にできるだけ合わせる。
  static List<CommunityActivity> fromLegacyLevel(int level) => switch (level) {
        <= 0 => const [],
        1 => const [CommunityActivity.visits],
        2 => const [CommunityActivity.visits, CommunityActivity.localBusiness],
        3 => const [CommunityActivity.visits, CommunityActivity.cleanup],
        4 => const [
            CommunityActivity.visits,
            CommunityActivity.cleanup,
            CommunityActivity.localBusiness,
          ],
        _ => const [
            CommunityActivity.visits,
            CommunityActivity.cleanup,
            CommunityActivity.localBusiness,
            CommunityActivity.clinics,
          ],
      };
}

/// 前の季の地域活動の結果(画面の「前の季の結果」)。
class CommunityReport {
  CommunityReport({
    required this.season,
    required this.activities,
    required this.spent,
    required this.supporterGain,
    required this.backing,
  });

  /// どの季か(リーグの季の番号)。
  final int season;
  final List<CommunityActivity> activities;

  /// 払った費用(その季の物差しの万円)。
  final int spent;

  /// 地域活動でサポーターの期待が上がった合計。
  final int supporterGain;

  /// 地元から入った協賛(万円)。
  final int backing;

  Map<String, dynamic> toJson() => {
        'season': season,
        'activities': [for (final a in activities) a.name],
        'spent': spent,
        'supporterGain': supporterGain,
        'backing': backing,
      };

  static CommunityReport? fromJson(Object? json) {
    if (json is! Map) return null;
    return CommunityReport(
      season: json['season'] as int? ?? 0,
      activities: [
        for (final n in (json['activities'] as List?) ?? const [])
          if (CommunityActivity.values.where((a) => a.name == n).firstOrNull
              case final CommunityActivity a)
            a,
      ],
      spent: json['spent'] as int? ?? 0,
      supporterGain: json['supporterGain'] as int? ?? 0,
      backing: json['backing'] as int? ?? 0,
    );
  }
}
