import '../game/formulas.dart';

/// 選手のポジション。GK は局面の性質が他と全く違うため、今は対象外。
enum Position {
  fw('FW', 'フォワード'),
  mf('MF', 'ミッドフィールダー'),
  df('DF', 'ディフェンダー');

  const Position(this.label, this.fullName);

  final String label;
  final String fullName;
}

/// 能力値。0〜99 の6項目で、FC 系のゲームに合わせてある。
class Attributes {
  const Attributes({
    required this.pace,
    required this.shooting,
    required this.passing,
    required this.dribbling,
    required this.defending,
    required this.physical,
  });

  final int pace;
  final int shooting;
  final int passing;
  final int dribbling;
  final int defending;
  final int physical;

  /// ポジションごとの重み付き総合力。同じ能力でも FW と DF で評価が変わる。
  int overallFor(Position position) {
    final weights = _weights[position]!;
    final sum = pace * weights[0] +
        shooting * weights[1] +
        passing * weights[2] +
        dribbling * weights[3] +
        defending * weights[4] +
        physical * weights[5];
    return (sum / weights.reduce((a, b) => a + b)).round();
  }

  static const Map<Position, List<int>> _weights = {
    //                   pace sho pas dri def phy
    Position.fw: [3, 5, 2, 4, 1, 3],
    Position.mf: [2, 3, 5, 4, 3, 3],
    Position.df: [3, 1, 2, 2, 6, 4],
  };

  int operator [](AttributeKey key) => switch (key) {
        AttributeKey.pace => pace,
        AttributeKey.shooting => shooting,
        AttributeKey.passing => passing,
        AttributeKey.dribbling => dribbling,
        AttributeKey.defending => defending,
        AttributeKey.physical => physical,
      };

  /// 1項目だけ増減させた新しい能力値を返す。上下限で丸める。
  Attributes bump(AttributeKey key, int delta) {
    int clamp(int v) =>
        v.clamp(Formulas.minAttribute, Formulas.maxAttribute).toInt();
    return Attributes(
      pace: clamp(pace + (key == AttributeKey.pace ? delta : 0)),
      shooting: clamp(shooting + (key == AttributeKey.shooting ? delta : 0)),
      passing: clamp(passing + (key == AttributeKey.passing ? delta : 0)),
      dribbling: clamp(dribbling + (key == AttributeKey.dribbling ? delta : 0)),
      defending: clamp(defending + (key == AttributeKey.defending ? delta : 0)),
      physical: clamp(physical + (key == AttributeKey.physical ? delta : 0)),
    );
  }

  Map<String, dynamic> toJson() => {
        'pace': pace,
        'shooting': shooting,
        'passing': passing,
        'dribbling': dribbling,
        'defending': defending,
        'physical': physical,
      };

  factory Attributes.fromJson(Map<String, dynamic> json) => Attributes(
        pace: json['pace'] as int,
        shooting: json['shooting'] as int,
        passing: json['passing'] as int,
        dribbling: json['dribbling'] as int,
        defending: json['defending'] as int,
        physical: json['physical'] as int,
      );
}

/// 能力値の項目。局面がどの能力で判定されるかを指すのに使う。
enum AttributeKey {
  pace('スピード'),
  shooting('シュート'),
  passing('パス'),
  dribbling('ドリブル'),
  defending('守備'),
  physical('フィジカル');

  const AttributeKey(this.label);

  final String label;
}
