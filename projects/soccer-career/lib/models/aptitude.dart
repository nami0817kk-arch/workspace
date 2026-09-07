import 'attributes.dart';

/// ポジション適性。
///
/// 能力値が同じでも、やったことのないポジションでは同じようには動けない。
/// 本職は100で、そこから近いポジションほど高い。試合に出ると上がる。
/// これがあると「コンバートで生き延びる」というキャリアが成立する。
class Aptitude {
  const Aptitude(this.values);

  final Map<Position, int> values;

  static const int max = 100;

  /// コンバートを試せる下限。ここに届かないと話にならない。
  static const int convertible = 55;

  /// 適性が1下がるごとに総合力から引かれる量の係数。
  static const double penaltyPerPoint = 0.2;

  /// ポジションの近さ。数字はそのまま初期適性になる。
  ///
  /// 縦の関係（CB→DM）より横の関係（CB→SB）のほうが近い、といった
  /// 現実の転向のしやすさをそのまま置いてある。
  static const Map<Position, Map<Position, int>> _related = {
    Position.gk: {},
    Position.cb: {Position.sb: 60, Position.dm: 55},
    Position.sb: {Position.cb: 58, Position.wg: 55, Position.dm: 50},
    Position.dm: {Position.cm: 70, Position.cb: 55},
    Position.cm: {Position.dm: 70, Position.am: 68},
    Position.am: {Position.cm: 68, Position.wg: 62, Position.st: 55},
    Position.wg: {Position.am: 62, Position.st: 58, Position.sb: 50},
    Position.st: {Position.am: 55, Position.wg: 58},
  };

  factory Aptitude.initial(Position primary) => Aptitude({
        primary: max,
        ...?_related[primary],
      });

  /// 適性を何も持っていない状態。
  ///
  /// 適性を導入する前の保存データや、テストで能力値だけを組んだ選手が
  /// ここに入る。何も分からないときに減点すると、過去のキャリアの
  /// 総合力が突然落ちるので、その場合は減点しない。
  bool get isUnknown => values.isEmpty;

  int operator [](Position position) =>
      values[position] ?? (isUnknown ? max : 25);

  /// そのポジションで出たときに総合力から引かれる量。
  int penaltyFor(Position position) =>
      ((max - this[position]) * penaltyPerPoint).round();

  bool canConvert(Position position) =>
      !isUnknown && this[position] >= convertible;

  /// そのポジションで出た経験を足す。上に行くほど上がりにくい。
  Aptitude playedAt(Position position) {
    final current = this[position];
    if (current >= max) return this;
    final gain = current >= 90 ? 1 : (current >= 70 ? 2 : 3);
    return Aptitude({...values, position: (current + gain).clamp(0, max)});
  }

  /// 見せる用。本職と、実戦で使える水準にあるポジション。
  List<Position> get usable => [
        for (final p in Position.values)
          if (canConvert(p)) p,
      ];

  Map<String, dynamic> toJson() =>
      {for (final e in values.entries) e.key.name: e.value};

  /// 適性を持たせる前の保存データは、今のポジションを本職として読む。
  factory Aptitude.fromJson(Map<String, dynamic>? json, Position primary) {
    if (json == null) return Aptitude.initial(primary);
    final values = <Position, int>{};
    for (final e in json.entries) {
      if (Position.values.any((p) => p.name == e.key)) {
        values[Position.values.byName(e.key)] = e.value as int;
      }
    }
    if (values.isEmpty) return Aptitude.initial(primary);
    return Aptitude(values);
  }
}
