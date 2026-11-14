import '../l10n/tr.dart';

/// 収支の項目。金額は符号付きで記録する(収入は正、支出は負)。
///
/// 資金が動く場所はすべて、どれかの項目に入れて記録する。項目に入れずに
/// 資金だけ動かすと、損益計算書の合計が実際の資金の増減と合わなくなる。
enum LedgerCategory {
  gate, // 観客収入
  sponsor, // スポンサー収入
  merchandise, // グッズ収入
  prize, // 賞金・ボーナス(リーグ・カップ・大陸・理事会・昇格)
  playerSales, // 選手の売却・ユースの補償金
  playerWages, // 選手の週給
  staffWages, // スタッフの週給
  appearanceFees, // 出場手当
  transfers, // 補強費(獲得・分割払い・ローン料・契約更新・ユース昇格)
  facilities, // 施設・合宿・スカウト
  financing, // 融資・預金の元本(損益には含めない)
  other; // その他(事件・デバッグ・購入資金など)

  String get label => switch (this) {
        gate => Tr.pick('観客収入', 'Gate receipts'),
        sponsor => Tr.pick('スポンサー', 'Sponsorship'),
        merchandise => Tr.pick('グッズ', 'Merchandise'),
        prize => Tr.pick('賞金・ボーナス', 'Prizes & bonuses'),
        playerSales => Tr.pick('選手の売却', 'Player sales'),
        playerWages => Tr.pick('選手の給与', 'Player wages'),
        staffWages => Tr.pick('スタッフの給与', 'Staff wages'),
        appearanceFees => Tr.pick('出場手当', 'Appearance fees'),
        transfers => Tr.pick('補強費', 'Signings'),
        facilities => Tr.pick('施設・合宿・スカウト', 'Facilities & scouting'),
        financing => Tr.pick('融資・預金', 'Loans & deposits'),
        other => Tr.pick('その他', 'Other'),
      };

  /// 毎シーズンの営業から入る収入(売却益は含めない)。
  bool get isOperatingIncome =>
      this == gate || this == sponsor || this == merchandise || this == prize;

  /// 人件費にあたる項目。
  bool get isWageCost =>
      this == playerWages || this == staffWages || this == appearanceFees;
}

/// 1シーズン分の収支の記録。
class SeasonLedger {
  SeasonLedger(this.season, [Map<LedgerCategory, int>? amounts])
      : amounts = amounts ?? {};

  final int season;

  /// 項目ごとの合計(符号付き)。
  final Map<LedgerCategory, int> amounts;

  void add(LedgerCategory category, int delta) {
    amounts[category] = (amounts[category] ?? 0) + delta;
  }

  int of(LedgerCategory category) => amounts[category] ?? 0;

  /// 営業収入の合計(観客・スポンサー・グッズ・賞金)。
  int get operatingIncome => amounts.entries
      .where((e) => e.key.isOperatingIncome)
      .fold(0, (s, e) => s + e.value);

  /// 人件費の合計(正の数で返す)。
  int get wageCost => -amounts.entries
      .where((e) => e.key.isWageCost)
      .fold(0, (s, e) => s + e.value);

  /// 損益(融資・預金の元本は含めない)。資金の増減から借入と預金の出入りを
  /// 除いた、そのシーズンの稼ぎ。
  int get profit => amounts.entries
      .where((e) => e.key != LedgerCategory.financing)
      .fold(0, (s, e) => s + e.value);

  /// 資金そのものの増減(融資・預金の元本を含む)。
  int get cashChange => amounts.values.fold(0, (s, v) => s + v);

  /// 営業収入に対する人件費の割合(0〜)。営業収入が無ければ 0。
  double get wageRatio {
    final income = operatingIncome;
    return income <= 0 ? 0 : wageCost / income;
  }

  Map<String, dynamic> toJson() => {
        'season': season,
        'amounts': {for (final e in amounts.entries) e.key.name: e.value},
      };

  factory SeasonLedger.fromJson(Map<String, dynamic> json) {
    final raw = (json['amounts'] as Map?) ?? const {};
    final amounts = <LedgerCategory, int>{};
    for (final c in LedgerCategory.values) {
      final v = raw[c.name];
      if (v is int) amounts[c] = v;
    }
    return SeasonLedger(json['season'] as int? ?? 1, amounts);
  }
}
