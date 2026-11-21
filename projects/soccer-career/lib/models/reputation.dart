// 名前（`_label` ほか）は private だが、**`this._label` には書けない**
// ——Dart は名前付き引数を `_` で始められない。
// ignore_for_file: prefer_initializing_formals

import '../l10n/lang.dart';
import '../game/formulas.dart';

/// 通算のマイルストーンと受賞。
///
/// キャリアの節目を記録に残す。引退画面で並ぶのがご褒美になる。
enum Award {
  debut(Say('プロデビュー', 'Professional debut')),
  firstGoal(Say('初ゴール', 'First goal')),
  hundredMatches(Say('通算100試合', '100 appearances')),
  twoHundredMatches(Say('通算200試合', '200 appearances')),
  fiftyGoals(Say('通算50ゴール', '50 goals')),
  hundredGoals(Say('通算100ゴール', '100 goals')),
  firstCap(Say('代表デビュー', 'International debut')),
  fiftyCaps(Say('代表50キャップ', '50 caps')),
  youngPlayer(Say('新人王', 'Young player of the year')),
  topScorer(Say('得点王', 'Top scorer')),
  seasonBest(Say('年間ベストイレブン', 'Team of the year')),
  leagueTitle(Say('リーグ優勝', 'League champion')),
  promotion(Say('昇格', 'Promotion')),
  continentalTitle(Say('大陸カップ優勝', 'Continental cup winner')),
  domesticCup(Say('国内カップ優勝', 'Domestic cup winner')),
  worldCup(Say('世界大会出場', 'At the world tournament')),
  worldCupTitle(Say('世界大会優勝', 'World champion'));

  const Award(Say label) : _label = label;

  final Say _label;

  String get label => _label.t;
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
      ? tr('${(marketValue / 10000).toStringAsFixed(1)}億円',
            'JPY ${(marketValue / 100).toStringAsFixed(1)}M')
      : tr('$marketValue万円', 'JPY ${(marketValue / 100).toStringAsFixed(1)}M');

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
      ? tr('厚い信頼', 'Full trust')
      : manager >= 50
      ? tr('普通', 'Normal')
      : manager >= 25
      ? tr('疑われている', 'Doubted')
      : tr('構想外', 'Frozen out');

  String get teammatesLabel => teammates >= 75
      ? tr('中心人物', 'At the heart of it')
      : teammates >= 50
      ? tr('馴染んでいる', 'One of the group')
      : teammates >= 25
      ? tr('距離がある', 'Kept at a distance')
      : tr('浮いている', 'On the outside');

  /// **次の段までの距離。** 言葉だけだと、近いのか遠いのかが分からない。
  ///
  /// 一番上の段に居るなら null。
  static (String, int)? nextStepFor(int value, List<(int, String)> steps) {
    for (final step in steps) {
      if (value < step.$1) return (step.$2, step.$1 - value);
    }
    return null;
  }

  /// 監督の信頼の、次の段と残り。
  (String, int)? get managerNext =>
      nextStepFor(manager, [
        (25, tr('疑われている', 'Doubted')),
        (50, tr('普通', 'Normal')),
        (75, tr('厚い信頼', 'Full trust')),
      ]);

  /// ロッカールームの、次の段と残り。
  (String, int)? get teammatesNext => nextStepFor(teammates, [
    (25, tr('距離がある', 'Kept at a distance')),
    (50, tr('馴染んでいる', 'One of the group')),
    (75, tr('中心人物', 'At the heart of it')),
  ]);

  Map<String, dynamic> toJson() => {'manager': manager, 'teammates': teammates};

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
    this.appearanceBonus = 0,
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

  /// 出場給。基準の試合数で 0、出るほど増え、欠けるほど減る。
  final int appearanceBonus;

  /// 手取り。マイナスなら貯蓄を削る。
  int get net =>
      salary + sponsor + appearanceBonus - agentFee - tax - living - staff;

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
  int livingCostFor(int salary) => (salary * (0.08 + lifestyle * 0.07)).round();

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
    int appearances = Formulas.appearanceBaseline,
  }) => SeasonBudget(
    salary: salary,
    agentFee: (salary * agentFeePercent / 100).round(),
    tax: (salary * taxRateFor(salary)).round(),
    living: livingCostFor(salary) + (salary * extraLivingRate).round(),
    staff: staffCost,
    sponsor: sponsor,
    appearanceBonus: Formulas.appearanceBonus(
      salary: salary,
      appearances: appearances,
    ),
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
    int appearances = Formulas.appearanceBaseline,
  }) {
    final budget = budgetFor(
      salary: salary,
      agentFeePercent: agentFeePercent,
      staffCost: staffCost,
      extraLivingRate: extraLivingRate,
      appearances: appearances,
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
      ? tr('${(savings / 10000).toStringAsFixed(1)}億円',
            'JPY ${(savings / 100).toStringAsFixed(1)}M')
      : tr('$savings万円', 'JPY ${(savings / 100).toStringAsFixed(1)}M');

  /// 読むたびに言語を選ぶ。
  static List<String> get lifestyleLabels =>
      [for (final l in _lifestyleLabels) l.t];

  static const List<Say> _lifestyleLabels = [
    Say('質素', 'Frugal'),
    Say('普通', 'Normal'),
    Say('派手', 'Flashy'),
    Say('豪奢', 'Lavish'),
  ];

  String get lifestyleLabel => lifestyleLabels[lifestyle.clamp(0, 3)];

  Map<String, dynamic> toJson() => {'savings': savings, 'lifestyle': lifestyle};

  factory Finances.fromJson(Map<String, dynamic>? json) => json == null
      ? const Finances()
      : Finances(
          savings: json['savings'] as int? ?? 0,
          lifestyle: json['lifestyle'] as int? ?? 1,
        );
}
