import '../game/formulas.dart';

/// 局面プールの種類。細かいポジションはこのどれかに属する。
///
/// ポジションごとに局面を全部書き分けると量が爆発するので、
/// 「どんな場面に立ち会うか」の単位でまとめてある。
enum ScenarioFamily { goalkeeper, defence, midfield, forward }

/// 選手のポジション。
enum Position {
  gk('GK', 'ゴールキーパー', ScenarioFamily.goalkeeper),
  cb('CB', 'センターバック', ScenarioFamily.defence),
  sb('SB', 'サイドバック', ScenarioFamily.defence),
  dm('DM', '守備的MF', ScenarioFamily.midfield),
  cm('CM', 'セントラルMF', ScenarioFamily.midfield),
  am('OMF', '攻撃的MF', ScenarioFamily.midfield),
  wg('WG', 'ウイング', ScenarioFamily.forward),
  st('ST', 'ストライカー', ScenarioFamily.forward);

  const Position(this.label, this.fullName, this.family);

  final String label;
  final String fullName;
  final ScenarioFamily family;

  /// 保存データから復元する。
  ///
  /// 3ポジションだった頃の保存データ（fw / mf / df）も読めるようにしてある。
  /// 読めないと、更新した途端にキャリアが消える。
  static Position parse(String name) => switch (name) {
        'fw' => Position.st,
        'mf' => Position.cm,
        'df' => Position.cb,
        _ => Position.values.byName(name),
      };
}

/// 能力値の項目。局面がどの能力で判定されるかを指すのに使う。
enum AttributeKey {
  pace('スピード'),
  shooting('シュート'),
  passing('パス'),
  dribbling('ドリブル'),
  defending('守備'),
  physical('フィジカル'),
  goalkeeping('GK');

  const AttributeKey(this.label);

  final String label;
}

/// 能力値。0〜99 の7項目。
class Attributes {
  const Attributes({
    required this.pace,
    required this.shooting,
    required this.passing,
    required this.dribbling,
    required this.defending,
    required this.physical,
    this.goalkeeping = Formulas.defaultGoalkeeping,
  });

  final int pace;
  final int shooting;
  final int passing;
  final int dribbling;
  final int defending;
  final int physical;
  final int goalkeeping;

  /// ポジションごとの重み付き総合力。同じ能力でも ST と CB で評価が変わる。
  int overallFor(Position position) {
    final w = _weights[position]!;
    final sum = pace * w[0] +
        shooting * w[1] +
        passing * w[2] +
        dribbling * w[3] +
        defending * w[4] +
        physical * w[5] +
        goalkeeping * w[6];
    return (sum / w.reduce((a, b) => a + b)).round();
  }

  static const Map<Position, List<int>> _weights = {
    //                pace sho pas dri def phy gk
    Position.gk: [1, 0, 1, 0, 2, 3, 10],
    Position.cb: [2, 0, 2, 1, 6, 5, 0],
    Position.sb: [4, 1, 3, 3, 4, 3, 0],
    Position.dm: [2, 1, 4, 2, 5, 4, 0],
    Position.cm: [2, 2, 5, 4, 3, 3, 0],
    Position.am: [3, 4, 5, 5, 1, 2, 0],
    Position.wg: [5, 3, 3, 5, 1, 2, 0],
    Position.st: [3, 6, 2, 3, 0, 4, 0],
  };

  int operator [](AttributeKey key) => switch (key) {
        AttributeKey.pace => pace,
        AttributeKey.shooting => shooting,
        AttributeKey.passing => passing,
        AttributeKey.dribbling => dribbling,
        AttributeKey.defending => defending,
        AttributeKey.physical => physical,
        AttributeKey.goalkeeping => goalkeeping,
      };

  /// 1項目だけ増減させた新しい能力値を返す。上下限で丸める。
  Attributes bump(AttributeKey key, int delta) {
    int c(int v) => v.clamp(Formulas.minAttribute, Formulas.maxAttribute).toInt();
    int at(AttributeKey k, int v) => c(v + (key == k ? delta : 0));
    return Attributes(
      pace: at(AttributeKey.pace, pace),
      shooting: at(AttributeKey.shooting, shooting),
      passing: at(AttributeKey.passing, passing),
      dribbling: at(AttributeKey.dribbling, dribbling),
      defending: at(AttributeKey.defending, defending),
      physical: at(AttributeKey.physical, physical),
      goalkeeping: at(AttributeKey.goalkeeping, goalkeeping),
    );
  }

  Map<String, dynamic> toJson() => {
        'pace': pace,
        'shooting': shooting,
        'passing': passing,
        'dribbling': dribbling,
        'defending': defending,
        'physical': physical,
        'goalkeeping': goalkeeping,
      };

  factory Attributes.fromJson(Map<String, dynamic> json) => Attributes(
        pace: json['pace'] as int,
        shooting: json['shooting'] as int,
        passing: json['passing'] as int,
        dribbling: json['dribbling'] as int,
        defending: json['defending'] as int,
        physical: json['physical'] as int,
        // GK 能力を足す前の保存データには無い。
        goalkeeping:
            json['goalkeeping'] as int? ?? Formulas.defaultGoalkeeping,
      );
}
