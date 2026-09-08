import 'dart:math';

/// 心の状態。
///
/// コンディションが身体なら、こちらは頭のほう。出番、怪我、私生活で動く。
/// 低いと何をしても噛み合わず、高いと同じ能力でも上振れる。
/// サッカー選手の1年は長く、身体だけを管理していれば済むものではない。
class Morale {
  const Morale({this.value = 60});

  final int value;

  static const int max = 100;

  Morale bump(int delta) => Morale(value: (value + delta).clamp(0, max));

  /// 成功率への増減。±3% まで。
  double get chanceModifier => (value - 60) * 0.0008;

  /// 練習の効きへの倍率。
  double get growthFactor => 0.85 + value * 0.0025;

  String get label => value >= 80
      ? '充実している'
      : value >= 55
          ? '悪くない'
          : value >= 30
              ? '沈んでいる'
              : '限界が近い';

  /// 助けが要る水準か。ここに落ちたら休ませる判断が要る。
  bool get needsCare => value < 30;

  Map<String, dynamic> toJson() => {'value': value};

  factory Morale.fromJson(Map<String, dynamic>? json) =>
      json == null ? const Morale() : Morale(value: json['value'] as int? ?? 60);
}

/// 累積疲労。
///
/// コンディションは1週間で戻るが、こちらは戻らない。連戦を重ねるほど
/// 溜まり、怪我のしやすさに効く。オフでだいたい抜ける。
class Fatigue {
  const Fatigue({this.value = 0});

  final int value;

  static const int max = 100;

  Fatigue add(int amount) => Fatigue(value: (value + amount).clamp(0, max));

  /// オフで抜ける分。歳を取るほど抜けにくい。
  Fatigue afterOffseason(int age) =>
      Fatigue(value: max0(value - (age >= 30 ? 45 : 70)));

  static int max0(int v) => v < 0 ? 0 : v;

  /// 怪我のしやすさへの倍率。
  double get injuryFactor => 1 + value * 0.006;

  /// 回復量への倍率。溜まっているほど戻りが悪い。
  double get recoveryFactor => 1 - value * 0.003;

  String get label => value >= 70
      ? '限界まで来ている'
      : value >= 40
          ? '疲れが抜けない'
          : '問題ない';

  Map<String, dynamic> toJson() => {'value': value};

  factory Fatigue.fromJson(Map<String, dynamic>? json) =>
      json == null ? const Fatigue() : Fatigue(value: json['value'] as int? ?? 0);
}

/// 一時的な絶好調と不調。
///
/// 実力とは別に、数試合だけ続く波。良いときは何をやっても入り、
/// 悪いときは何をやっても外れる。シーズンに起伏を作るための仕組み。
enum MomentumState {
  zone('ゾーン', 0.07),
  normal('平常', 0),
  slump('スランプ', -0.06);

  const MomentumState(this.label, this.chanceModifier);

  final String label;
  final double chanceModifier;
}

/// 波の状態と残り試合数。
class Momentum {
  const Momentum({this.state = MomentumState.normal, this.matches = 0});

  final MomentumState state;
  final int matches;

  bool get isActive => state != MomentumState.normal && matches > 0;

  double get chanceModifier => isActive ? state.chanceModifier : 0;

  /// 1試合ぶん進める。
  Momentum tick() => matches <= 1
      ? const Momentum()
      : Momentum(state: state, matches: matches - 1);

  /// 直近の出来から、波に入るかを決める。
  ///
  /// 良い試合が続いた後に入り、悪い試合が続いた後に落ちる。実力どおりの
  /// 成績が延々と続くより、波があるほうが1シーズンを追う気になる。
  static Momentum roll(Random random, {required List<double> recent}) {
    if (recent.length < 3) return const Momentum();
    final window = recent.sublist(max(0, recent.length - 3));
    final average = window.reduce((a, b) => a + b) / window.length;
    if (average >= 7.3 && random.nextDouble() < 0.25) {
      return Momentum(state: MomentumState.zone, matches: 3 + random.nextInt(3));
    }
    if (average <= 5.8 && random.nextDouble() < 0.25) {
      return Momentum(state: MomentumState.slump, matches: 3 + random.nextInt(4));
    }
    return const Momentum();
  }

  Map<String, dynamic> toJson() => {'state': state.name, 'matches': matches};

  factory Momentum.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const Momentum();
    return Momentum(
      state: MomentumState.values.any((s) => s.name == json['state'])
          ? MomentumState.values.byName(json['state'] as String)
          : MomentumState.normal,
      matches: json['matches'] as int? ?? 0,
    );
  }
}

/// スパイクのスポンサー。
///
/// 知名度が上がると付く。年俸とは別の収入で、断ることもできる
/// （その代わり、条件が悪い相手に縛られない）。
class Sponsor {
  const Sponsor({required this.name, required this.annual, this.years = 3});

  final String name;

  /// 年あたりの契約金（万円）。
  final int annual;

  /// 残り年数。
  final int years;

  static const List<String> brands = [
    'アストレア', 'ノルディカ', 'ヴェント', 'クロノス', 'ミラージュ',
  ];

  /// 知名度に見合うスポンサーを引く。付かないこともある。
  static Sponsor? offerFor({
    required int fame,
    required Random random,
    int marketValue = 0,
  }) {
    if (fame < 35) return null;
    final annual = ((fame - 30) * 40 + marketValue * 0.05).round();
    return Sponsor(
      name: brands[random.nextInt(brands.length)],
      annual: (annual / 10).round() * 10,
      years: 2 + random.nextInt(3),
    );
  }

  Sponsor aged() =>
      Sponsor(name: name, annual: annual, years: years - 1);

  bool get expired => years <= 0;

  Map<String, dynamic> toJson() =>
      {'name': name, 'annual': annual, 'years': years};

  static Sponsor? fromJson(Map<String, dynamic>? json) => json == null
      ? null
      : Sponsor(
          name: json['name'] as String? ?? 'スポンサー',
          annual: json['annual'] as int? ?? 0,
          years: json['years'] as int? ?? 1,
        );
}

/// 年齢で変わるキャリアの段階。
///
/// 同じ数字を見ていても、19歳の70と33歳の70では意味が違う。
/// 画面の言葉をここで変える。
enum CareerStage {
  youth('育成年代', 'まだ何者でもない'),
  prospect('若手', '伸びしろで見られている'),
  established('中堅', '計算される立場になった'),
  peak('全盛期', '数字がそのまま評価になる'),
  veteran('ベテラン', '経験で埋める時期'),
  twilight('晩年', '一試合ごとが最後になりうる');

  const CareerStage(this.label, this.description);

  final String label;
  final String description;

  static CareerStage of(int age) {
    if (age <= 18) return CareerStage.youth;
    if (age <= 22) return CareerStage.prospect;
    if (age <= 26) return CareerStage.established;
    if (age <= 30) return CareerStage.peak;
    if (age <= 34) return CareerStage.veteran;
    return CareerStage.twilight;
  }
}

/// 引退後の道。
///
/// 現役でやってきたことが、そのまま次の職業の適性になる。
/// 数字だけ残して終わりにしないための締め。
enum SecondCareer {
  manager('監督', '戦術を語り、人を動かす'),
  coach('育成コーチ', '次の世代を伸ばす'),
  pundit('解説者', '見てきたものを言葉にする'),
  director('スポーツディレクター', 'クラブを組み立てる'),
  entrepreneur('実業家', '稼いだものを次に回す'),
  quiet('静かな暮らし', 'footballから離れる');

  const SecondCareer(this.label, this.description);

  final String label;
  final String description;
}

/// プレシーズンの過ごし方。
///
/// シーズンが始まる前の1か月をどう使うか。ここで積んだものは
/// 開幕からの数試合に効き、手を抜けば秋に響く。
enum PreseasonPlan {
  tour('海外ツアー', '興行に付き合う。名前は売れるが、疲れを残して開幕する'),
  camp('強化合宿', '走り込む。開幕は重いが、身体は出来上がる'),
  rest('完全休養', '何もしない。疲れは抜けるが、出遅れる');

  const PreseasonPlan(this.label, this.description);

  final String label;
  final String description;

  /// 開幕時のコンディション。
  int get condition => switch (this) {
        PreseasonPlan.tour => 80,
        PreseasonPlan.camp => 70,
        PreseasonPlan.rest => 100,
      };

  /// 溜まっている疲労に足す量。
  int get fatigue => switch (this) {
        PreseasonPlan.tour => 12,
        PreseasonPlan.camp => 6,
        PreseasonPlan.rest => 0,
      };

  /// 知名度への上乗せ。
  int get fame => this == PreseasonPlan.tour ? 3 : 0;

  /// そのシーズンの練習の効きへの倍率。
  double get growthFactor => switch (this) {
        PreseasonPlan.camp => 1.1,
        PreseasonPlan.rest => 0.95,
        PreseasonPlan.tour => 1.0,
      };
}
