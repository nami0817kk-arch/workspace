import '../l10n/tr.dart';

/// 収支の項目。金額は符号付きで記録する(収入は正、支出は負)。
///
/// 資金が動く場所はすべて、どれかの項目に入れて記録する。項目に入れずに
/// 資金だけ動かすと、損益計算書の合計が実際の資金の増減と合わなくなる。
///
/// 移籍金は実際の会計に合わせて資産として扱う(2026-11-22)。払ったときは
/// [transferFees](資金は減るが損益には入れない)、毎季の費用は
/// [amortization](契約の年数で割った額。資金は動かない)。
enum LedgerCategory {
  gate, // 観客収入
  sponsor, // スポンサー収入
  merchandise, // グッズ収入
  broadcast, // 放映権料(年4回の入金と季末の分配金)
  prize, // 賞金・ボーナス(リーグ・カップ・大陸・理事会・昇格)
  playerSales, // 選手の売却・ユースの補償金
  playerWages, // 選手の給与
  staffWages, // スタッフの給与
  appearanceFees, // 出場手当
  transfers, // 補強費(獲得・分割払い・ローン料・契約更新・ユース昇格)
  facilities, // 施設・合宿・スカウト
  operations, // 運営費(試合運営・遠征・事務・施設の維持。毎月末)
  infrastructure, // 施設・アカデミーへの投資(規則の判定では赤字に数えない)
  interest, // 融資・オーナーからの借入の利息(支出)と預金の利息(収入)
  amortization, // 移籍金の償却(資金は動かない。売った・去った選手の残りの簿価も)
  transferFees, // 移籍金の支払い(資産。損益には含めず、償却で費用にする)
  financing, // 融資・預金の元本(損益には含めない)
  other; // その他(事件・デバッグ・購入資金など)

  String get label => switch (this) {
        gate => Tr.pick('観客収入', 'Gate receipts'),
        sponsor => Tr.pick('スポンサー', 'Sponsorship'),
        merchandise => Tr.pick('グッズ', 'Merchandise'),
        broadcast => Tr.pick('放映権', 'Broadcasting'),
        prize => Tr.pick('賞金・ボーナス', 'Prizes & bonuses'),
        playerSales => Tr.pick('選手の売却', 'Player sales'),
        playerWages => Tr.pick('選手の給与', 'Player wages'),
        staffWages => Tr.pick('スタッフの給与', 'Staff wages'),
        appearanceFees => Tr.pick('出場手当', 'Appearance fees'),
        transfers => Tr.pick('補強費', 'Signings'),
        facilities => Tr.pick('施設・合宿・スカウト', 'Facilities & scouting'),
        operations => Tr.pick('運営費', 'Running costs'),
        infrastructure =>
          Tr.pick('施設・アカデミーへの投資', 'Facility & academy investment'),
        interest => Tr.pick('利息', 'Interest'),
        amortization => Tr.pick('移籍金の償却', 'Transfer fee amortisation'),
        transferFees => Tr.pick('移籍金の支払い', 'Transfer fees paid'),
        financing => Tr.pick('融資・預金', 'Loans & deposits'),
        other => Tr.pick('その他', 'Other'),
      };

  /// 毎シーズンの営業から入る収入(売却益は含めない)。
  bool get isOperatingIncome =>
      this == gate ||
      this == sponsor ||
      this == merchandise ||
      this == broadcast ||
      this == prize;

  /// 人件費にあたる項目。
  bool get isWageCost =>
      this == playerWages || this == staffWages || this == appearanceFees;

  /// 損益に入れない項目(元本の出入りと、資産になる移籍金の支払い)。
  bool get isOutsideProfit => this == financing || this == transferFees;

  /// 資金が動かない項目(償却)。資金の増減には数えない。
  bool get isNonCash => this == amortization;
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

  /// 損益(融資・預金の元本と、移籍金の支払いは含めない)。移籍金は
  /// 償却([LedgerCategory.amortization])で費用になる。
  int get profit => amounts.entries
      .where((e) => !e.key.isOutsideProfit)
      .fold(0, (s, e) => s + e.value);

  /// 規則の判定に使う損益。施設・アカデミーへの投資は赤字に数えない
  /// (実際の収支規則と同じ)。借入・出資は、もともと損益に入らない。
  int get ruleProfit => profit - of(LedgerCategory.infrastructure);

  /// 選手の人件費(選手の給与・出場手当)と移籍金の償却の合計(正の数)。
  /// スペインの上限と UEFA の比率で数える「選手にかかる費用」。
  int get squadCost => -(of(LedgerCategory.playerWages) +
      of(LedgerCategory.appearanceFees) +
      of(LedgerCategory.amortization));

  /// 資金そのものの増減(融資・預金の元本を含み、償却は含めない)。
  int get cashChange => amounts.entries
      .where((e) => !e.key.isNonCash)
      .fold(0, (s, e) => s + e.value);

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
