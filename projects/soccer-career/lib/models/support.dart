/// 自腹で雇うスタッフの種類。
///
/// クラブが付けてくれるものとは別に、選手が自分の金で抱える専属。
/// 稼いだ金の使い道を「豪遊するか、身体に投資するか」にするための仕組み。
enum StaffKind {
  coach('専属コーチ', '練習の質が上がる'),
  trainer('専属トレーナー', '怪我をしにくく、戻りが早い'),
  nutritionist('専属栄養士', '身体が整い、衰えが遅くなる');

  const StaffKind(this.label, this.description);

  final String label;
  final String description;
}

/// 抱えているスタッフ。level 0 は雇っていない状態。
class StaffTeam {
  const StaffTeam({this.coach = 0, this.trainer = 0, this.nutritionist = 0});

  final int coach;
  final int trainer;
  final int nutritionist;

  static const int maxLevel = 3;

  /// 段位ごとの年間の報酬（万円）。
  static const List<int> costPerLevel = [0, 200, 600, 1500];

  static const List<String> levelLabels = ['無し', '駆け出し', '一流', '世界的'];

  int operator [](StaffKind kind) => switch (kind) {
        StaffKind.coach => coach,
        StaffKind.trainer => trainer,
        StaffKind.nutritionist => nutritionist,
      };

  StaffTeam withLevel(StaffKind kind, int level) {
    final v = level.clamp(0, maxLevel);
    return StaffTeam(
      coach: kind == StaffKind.coach ? v : coach,
      trainer: kind == StaffKind.trainer ? v : trainer,
      nutritionist: kind == StaffKind.nutritionist ? v : nutritionist,
    );
  }

  /// 1シーズンの人件費（万円）。
  int get costPerSeason =>
      costPerLevel[coach] + costPerLevel[trainer] + costPerLevel[nutritionist];

  /// 練習の効きやすさ。
  double get growthFactor => 1 + coach * 0.12 + nutritionist * 0.03;

  /// 怪我のしやすさ。
  double get injuryFactor =>
      (1 - trainer * 0.12 - nutritionist * 0.04).clamp(0.5, 1.0);

  /// 休養で戻る量への上乗せ。
  int get recoveryBonus => trainer * 3 + nutritionist * 2;

  /// 衰えが始まる年齢を後ろにずらす。
  int get declineAgeOffset => nutritionist >= 3 ? 2 : (nutritionist >= 2 ? 1 : 0);

  bool get isEmpty => coach == 0 && trainer == 0 && nutritionist == 0;

  Map<String, dynamic> toJson() =>
      {'coach': coach, 'trainer': trainer, 'nutritionist': nutritionist};

  factory StaffTeam.fromJson(Map<String, dynamic>? json) => json == null
      ? const StaffTeam()
      : StaffTeam(
          coach: json['coach'] as int? ?? 0,
          trainer: json['trainer'] as int? ?? 0,
          nutritionist: json['nutritionist'] as int? ?? 0,
        );
}

/// 生活習慣。睡眠と食事。
///
/// 練習と違って毎週選ぶものではなく、一度決めたら続くもの。
/// 効き方は小さいが、10年積むと別の選手になる。
class Habits {
  const Habits({this.sleep = 1, this.diet = 1});

  /// 0=夜更かし 1=普通 2=徹底した睡眠
  final int sleep;

  /// 0=好きに食べる 1=普通 2=管理された食事
  final int diet;

  static const List<String> sleepLabels = ['夜更かし', '普通', '徹底した睡眠'];
  static const List<String> dietLabels = ['好きに食べる', '普通', '管理された食事'];

  String get sleepLabel => sleepLabels[sleep.clamp(0, 2)];
  String get dietLabel => dietLabels[diet.clamp(0, 2)];

  /// 休養で戻る量への上乗せ。
  int get recoveryBonus => (sleep - 1) * 5 + (diet - 1) * 2;

  /// 怪我のしやすさ。
  double get injuryFactor =>
      (1 - (sleep - 1) * 0.08 - (diet - 1) * 0.05).clamp(0.7, 1.3);

  /// 練習の効きやすさ。
  double get growthFactor => 1 + (sleep - 1) * 0.05 + (diet - 1) * 0.05;

  /// 生活費への上乗せ（年俸に対する割合）。良い食事は金がかかる。
  double get livingCostExtra => diet == 2 ? 0.03 : 0;

  /// プロ意識が上がりやすいか。両方を整えている選手だけ。
  bool get disciplined => sleep >= 2 && diet >= 2;

  /// どちらも捨てている生活。若いうちは平気でも、後で払う。
  bool get reckless => sleep == 0 && diet == 0;

  Habits copyWith({int? sleep, int? diet}) => Habits(
        sleep: (sleep ?? this.sleep).clamp(0, 2),
        diet: (diet ?? this.diet).clamp(0, 2),
      );

  Map<String, dynamic> toJson() => {'sleep': sleep, 'diet': diet};

  factory Habits.fromJson(Map<String, dynamic>? json) => json == null
      ? const Habits()
      : Habits(
          sleep: json['sleep'] as int? ?? 1,
          diet: json['diet'] as int? ?? 1,
        );
}
