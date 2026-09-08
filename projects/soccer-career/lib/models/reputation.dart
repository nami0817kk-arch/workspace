/// 通算のマイルストーンと受賞。
///
/// キャリアの節目を記録に残す。引退画面で並ぶのがご褒美になる。
enum Award {
  debut('プロデビュー'),
  firstGoal('初ゴール'),
  hundredMatches('通算100試合'),
  twoHundredMatches('通算200試合'),
  fiftyGoals('通算50ゴール'),
  hundredGoals('通算100ゴール'),
  firstCap('代表デビュー'),
  fiftyCaps('代表50キャップ'),
  youngPlayer('新人王'),
  topScorer('得点王'),
  seasonBest('年間ベストイレブン'),
  leagueTitle('リーグ優勝'),
  promotion('昇格'),
  continentalTitle('大陸カップ優勝'),
  domesticCup('国内カップ優勝'),
  worldCup('ワールドカップ出場'),
  worldCupTitle('ワールドカップ優勝');

  const Award(this.label);

  final String label;
}

/// 評判と市場価値。
///
/// 年俸とは別の「値札」。活躍・年齢・契約残で動き、移籍オファーの質と
/// 労働許可の審査に効く。
class Reputation {
  const Reputation({
    this.marketValue = 300,
    this.fame = 10,
    this.awards = const [],
  });

  /// 市場価値（万円）。
  final int marketValue;

  /// 知名度 0〜100。メディアと代表招集に効く。
  final int fame;

  /// 獲得した称号。
  final List<Award> awards;

  bool has(Award award) => awards.contains(award);

  Reputation earn(Award award) =>
      has(award) ? this : copyWith(awards: [...awards, award]);

  Reputation copyWith({int? marketValue, int? fame, List<Award>? awards}) =>
      Reputation(
        marketValue: marketValue ?? this.marketValue,
        fame: (fame ?? this.fame).clamp(0, 100),
        awards: awards ?? this.awards,
      );

  String get valueLabel => marketValue >= 10000
      ? '${(marketValue / 10000).toStringAsFixed(1)}億円'
      : '$marketValue万円';

  Map<String, dynamic> toJson() => {
        'marketValue': marketValue,
        'fame': fame,
        'awards': awards.map((a) => a.name).toList(),
      };

  factory Reputation.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const Reputation();
    return Reputation(
      marketValue: json['marketValue'] as int? ?? 300,
      fame: json['fame'] as int? ?? 10,
      awards: [
        for (final n in (json['awards'] as List? ?? const []))
          if (Award.values.any((a) => a.name == n))
            Award.values.byName(n as String),
      ],
    );
  }
}

/// 監督とチームメイトとの関係。
class Relations {
  const Relations({this.manager = 50, this.teammates = 50});

  /// 監督の信頼 0〜100。出場機会と目標の甘さに効く。
  final int manager;

  /// ロッカールームでの立場 0〜100。
  final int teammates;

  Relations bump({int manager = 0, int teammates = 0}) => Relations(
        manager: (this.manager + manager).clamp(0, 100),
        teammates: (this.teammates + teammates).clamp(0, 100),
      );

  String get managerLabel => manager >= 75
      ? '厚い信頼'
      : manager >= 50
          ? '普通'
          : manager >= 25
              ? '疑われている'
              : '構想外';

  String get teammatesLabel => teammates >= 75
      ? '中心人物'
      : teammates >= 50
          ? '馴染んでいる'
          : teammates >= 25
              ? '距離がある'
              : '浮いている';

  Map<String, dynamic> toJson() =>
      {'manager': manager, 'teammates': teammates};

  factory Relations.fromJson(Map<String, dynamic>? json) => json == null
      ? const Relations()
      : Relations(
          manager: json['manager'] as int? ?? 50,
          teammates: json['teammates'] as int? ?? 50,
        );
}

/// お金。年俸から税と手数料を引いた手取りが積み上がる。
/// 1シーズンの収支。
///
/// これまで内訳はどこにも出ていなかった。年俸だけを見て世界的なコーチを
/// 雇い、シーズンの終わりに貯蓄が尽きて**黙って全員が離れていく**、
/// という壊れ方をしていた。雇う前に足りるかどうかが分かるようにする。
class SeasonBudget {
  const SeasonBudget({
    required this.salary,
    required this.agentFee,
    required this.tax,
    required this.living,
    required this.staff,
    required this.sponsor,
  });

  /// 年俸（万円）。
  final int salary;

  /// 代理人の手数料。
  final int agentFee;

  /// 税。
  final int tax;

  /// 生活費（生活水準と食事のこだわりを含む）。
  final int living;

  /// 専属スタッフの人件費。
  final int staff;

  /// スポンサー収入。
  final int sponsor;

  /// 手取り。マイナスなら貯蓄を削る。
  int get net => salary + sponsor - agentFee - tax - living - staff;

  /// 出ていくもの。
  int get outgoing => agentFee + tax + living + staff;
}

class Finances {
  const Finances({this.savings = 0, this.lifestyle = 1});

  /// 貯蓄（万円）。
  final int savings;

  /// 生活水準 0〜3。高いほど支出が増える。
  final int lifestyle;

  /// 税率。年俸が高いほど重い。
  static double taxRateFor(int salary) => salary >= 20000
      ? 0.45
      : salary >= 8000
          ? 0.38
          : salary >= 2000
              ? 0.30
              : 0.20;

  /// 1シーズンの生活費。
  int livingCostFor(int salary) =>
      (salary * (0.08 + lifestyle * 0.07)).round();

  /// 1シーズンの収支を出す。
  ///
  /// [afterSeason] はこの結果を貯蓄に足すだけ。画面に出す見込みも
  /// これを使う。別に計算すると、見込みと実際がずれる。
  SeasonBudget budgetFor({
    required int salary,
    required int agentFeePercent,
    int staffCost = 0,
    double extraLivingRate = 0,
    int sponsor = 0,
  }) =>
      SeasonBudget(
        salary: salary,
        agentFee: (salary * agentFeePercent / 100).round(),
        tax: (salary * taxRateFor(salary)).round(),
        living: livingCostFor(salary) + (salary * extraLivingRate).round(),
        staff: staffCost,
        sponsor: sponsor,
      );

  /// そのシーズンの手取りを貯蓄に足す。
  ///
  /// 専属スタッフの人件費と、こだわった食事の費用もここで引く。
  /// 身体への投資は年俸から出ていく。稼ぎの使い道に選択が生まれる。
  ///
  /// スポンサー収入はここには入らない（呼び出し側が別に足している）。
  Finances afterSeason({
    required int salary,
    required int agentFeePercent,
    int staffCost = 0,
    double extraLivingRate = 0,
  }) {
    final budget = budgetFor(
      salary: salary,
      agentFeePercent: agentFeePercent,
      staffCost: staffCost,
      extraLivingRate: extraLivingRate,
    );
    return Finances(savings: savings + budget.net, lifestyle: lifestyle);
  }

  /// 貯蓄から支払う。
  Finances spend(int amount) =>
      Finances(savings: savings - amount, lifestyle: lifestyle);

  Finances withLifestyle(int level) =>
      Finances(savings: savings, lifestyle: level.clamp(0, 3));

  /// 1シーズンぶんの、生活水準からくる気持ちの動き。
  ///
  /// 質素は少し削り、派手なら少し上向く。ここが無いと「質素」が
  /// ただの正解になり、稼ぎの使い道という選択が消える。
  /// 既定（普通）は 0 なので、これまでの数字は動かない。
  int get moraleShift => lifestyle - 1;

  String get savingsLabel => savings >= 10000
      ? '${(savings / 10000).toStringAsFixed(1)}億円'
      : '$savings万円';

  static const List<String> lifestyleLabels = [
    '質素',
    '普通',
    '派手',
    '豪奢',
  ];

  String get lifestyleLabel => lifestyleLabels[lifestyle.clamp(0, 3)];

  Map<String, dynamic> toJson() =>
      {'savings': savings, 'lifestyle': lifestyle};

  factory Finances.fromJson(Map<String, dynamic>? json) => json == null
      ? const Finances()
      : Finances(
          savings: json['savings'] as int? ?? 0,
          lifestyle: json['lifestyle'] as int? ?? 1,
        );
}
