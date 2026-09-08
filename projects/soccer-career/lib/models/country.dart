/// 連盟。大陸カップと、外国人ルールの「連盟内自由移動」の単位。
enum Confederation {
  // 実在の連盟の名前と略称は商標なので使わない。地域名で足りる。
  vesta('欧州'),
  oriens('アジア'),
  austral('南米');

  const Confederation(this.label);

  final String label;
}

/// リーグの暦。移籍の窓とシーズンの切れ目がずれる。
enum LeagueCalendar {
  autumnSpring('秋春制'),
  springAutumn('春秋制');

  const LeagueCalendar(this.label);

  final String label;
}

/// 外国人枠の規則。国ごとに組み合わせが違う。
///
/// 実在の制度を型として写したもの。名称は架空だが、
/// 「連盟内は自由」「登録枠」「同時出場枠」「提携国」「ホームグロウン」は
/// 現実のリーグが実際に使っている仕組み。
class ForeignRule {
  const ForeignRule({
    this.squadLimit,
    this.pitchLimit,
    this.confederationFree = false,
    this.homegrownRequired = 0,
    this.partnerCountries = const [],
  });

  /// 登録メンバーに入れる外国人の上限。null なら無制限。
  final int? squadLimit;

  /// 同時にピッチに立てる外国人の上限。null なら無制限。
  final int? pitchLimit;

  /// 同じ連盟の選手を外国人に数えないか。
  final bool confederationFree;

  /// 登録メンバーに必要な自国育ちの最低人数。
  final int homegrownRequired;

  /// 外国人枠から除外される提携国。
  final List<String> partnerCountries;

  /// 制限が緩いほど、若い外国人が入り込みやすい。
  bool get isLenient => squadLimit == null || squadLimit! >= 6;

  String get summary {
    final parts = <String>[];
    if (confederationFree) parts.add('連盟内は自由');
    if (squadLimit != null) parts.add('登録枠 $squadLimit');
    if (pitchLimit != null) parts.add('同時出場 $pitchLimit');
    if (homegrownRequired > 0) parts.add('自国育ち $homegrownRequired人以上');
    if (partnerCountries.isNotEmpty) parts.add('提携国は枠外');
    return parts.isEmpty ? '制限なし' : parts.join('・');
  }
}

/// 労働許可の要件（ポイント制）。
///
/// 若い選手がいきなり最上位リーグへ行けない現実を作る。
/// 足りなければ、規制の緩いリーグを経由してポイントを貯めることになる。
class PermitRule {
  const PermitRule({
    required this.required,
    this.capsRatioPoints = 4,
    this.leaguePrestigePoints = 3,
    this.feePoints = 3,
    this.continentalPoints = 2,
    this.minLeaguePrestige = 4,
    this.minCapsRatio = 0.3,
  });

  /// 必要な合計点。
  final int required;

  final int capsRatioPoints;
  final int leaguePrestigePoints;
  final int feePoints;
  final int continentalPoints;

  /// 加点される出身リーグの最低の格。
  final int minLeaguePrestige;

  /// 加点される代表出場率（キャップ / 在籍年数×10 の概算）。
  final double minCapsRatio;

  static const PermitRule none = PermitRule(required: 0);

  bool get isRequired => required > 0;
}

/// 国。リーグのピラミッドと規則を持つ。
class Country {
  const Country({
    required this.id,
    required this.name,
    required this.demonym,
    required this.confederation,
    required this.prestige,
    required this.calendar,
    required this.tierSizes,
    required this.foreignRule,
    this.permitRule = PermitRule.none,
    required this.clubStems,
    required this.clubPatterns,
  });

  final String id;
  final String name;

  /// 「イングランド人」のような呼び方。
  final String demonym;

  final Confederation confederation;

  /// リーグの格 1〜5。年俸水準・クラブの強さ・大陸カップ枠に効く。
  final int prestige;

  final LeagueCalendar calendar;

  /// 各部のクラブ数。長さがそのまま部の数。
  final List<int> tierSizes;

  final ForeignRule foreignRule;
  final PermitRule permitRule;

  /// クラブ名の元になる地名。
  final List<String> clubStems;

  /// クラブ名の型。`{}` が地名に置き換わる。
  ///
  /// 国ごとの命名の癖（「〜シティ」「FC〜」「アル＝〜」）が、
  /// リーグの雰囲気をいちばん安く作る。
  final List<String> clubPatterns;

  int get tiers => tierSizes.length;

  int clubsInTier(int tier) =>
      tier >= 1 && tier <= tierSizes.length ? tierSizes[tier - 1] : 20;

  /// その部のリーグ戦の試合数（2回戦総当たり）。
  int matchesInTier(int tier) => (clubsInTier(tier) - 1) * 2;

  /// 上位大陸カップの出場枠。格が高いほど多い。
  int get continentalSlots => switch (prestige) {
        5 => 4,
        4 => 3,
        3 => 2,
        _ => 1,
      };
}
