// 名前（`_label` ほか）は private だが、**`this._label` には書けない**
// ——Dart は名前付き引数を `_` で始められない。外に見せるのは `String` の
// getter なので、持ち物は private のまま置く。
// ignore_for_file: prefer_initializing_formals

import '../l10n/lang.dart';

/// 自腹で雇うスタッフの種類。
///
/// クラブが付けてくれるものとは別に、選手が自分の金で抱える専属。
/// 稼いだ金の使い道を「豪遊するか、身体に投資するか」にするための仕組み。
enum StaffKind {
  coach(Say('専属コーチ', 'Personal coach'), Say('練習の質が上がる', 'Better quality of training')),
  trainer(Say('専属トレーナー', 'Personal trainer'), Say('怪我をしにくく、戻りが早い', 'Fewer injuries and a quicker return')),
  nutritionist(Say('専属栄養士', 'Personal nutritionist'), Say('身体が整い、衰えが遅くなる', 'The body holds together and declines later'));

  const StaffKind(Say label, Say description)
    : _label = label,
      _description = description;

  final Say _label;
  final Say _description;

  String get label => _label.t;
  String get description => _description.t;
}

/// 抱えているスタッフ。level 0 は雇っていない状態。
class StaffTeam {
  const StaffTeam({this.coach = 0, this.trainer = 0, this.nutritionist = 0});

  final int coach;
  final int trainer;
  final int nutritionist;

  static const int maxLevel = 3;

  /// 段位ごとの年間の報酬（万円）。
  /// 1シーズンの人件費（万円）。段ごとに跳ね上がる。
  ///
  /// **安すぎると「全員を最高で雇う」が常に正解になる。** 実測（16キャリアずつ）で、
  /// 雇わない選手は引退時に中央 6.7億円・**最小でも3.5億円**を余らせていた——
  /// 金は使い道の無い点数で、雇う側はピーク +0.9・出場 +13・年俸 +877 を
  /// ただで手にしていた。3人を最高で揃えても払い切れる値段だったため、
  /// 「誰を雇うか」という選択が存在しなかった。
  ///
  /// 3人を最高で揃えると1シーズン9,600万円。**稼ぎの余りを超える**ので、
  /// 伸び（コーチ）・怪我（トレーナー）・衰え（栄養士）のどれを取るかになる。
  static const List<int> costPerLevel = [0, 400, 1200, 3200];

  /// 読むたびに言語を選ぶ。
  static List<String> get levelLabels =>
      [for (final l in _levelLabels) l.t];

  static const List<Say> _levelLabels = [Say('無し', 'None'), Say('駆け出し', 'Just starting out'), Say('一流', 'Top class'), Say('世界的', 'World class')];

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

  /// 読むたびに言語を選ぶ。
  static List<String> get sleepLabels =>
      [for (final l in _sleepLabels) l.t];

  static List<String> get dietLabels => [for (final l in _dietLabels) l.t];

  static const List<Say> _sleepLabels = [Say('夜更かし', 'Late nights'), Say('普通', 'Normal'), Say('徹底した睡眠', 'Strict sleep')];
  static const List<Say> _dietLabels = [Say('好きに食べる', 'Eat what you like'), Say('普通', 'Normal'), Say('管理された食事', 'A managed diet')];

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
