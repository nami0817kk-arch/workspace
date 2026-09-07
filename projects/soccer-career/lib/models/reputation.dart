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
  continentalTitle('大陸カップ優勝');

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

  /// そのシーズンの手取りを貯蓄に足す。
  Finances afterSeason({required int salary, required int agentFeePercent}) {
    final agentFee = (salary * agentFeePercent / 100).round();
    final tax = (salary * taxRateFor(salary)).round();
    final living = livingCostFor(salary);
    final net = salary - agentFee - tax - living;
    return Finances(savings: savings + net, lifestyle: lifestyle);
  }

  Finances withLifestyle(int level) =>
      Finances(savings: savings, lifestyle: level.clamp(0, 3));

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
