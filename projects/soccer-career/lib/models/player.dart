import '../game/formulas.dart';
import 'attributes.dart';
import 'traits.dart';

/// プレイヤーが操作する選手。
class Player {
  const Player({
    required this.name,
    required this.age,
    required this.position,
    required this.attributes,
    required this.potential,
    this.traits = const [],
    this.condition = Formulas.conditionMax,
  });

  final String name;
  final int age;
  final Position position;
  final Attributes attributes;

  /// 総合力の上限。ここまでしか伸びない。画面には帯でしか見せない。
  final int potential;

  final List<Trait> traits;

  /// 0〜100。試合と練習で減り、休養で戻る。低いと試合の成功率が落ちる。
  final int condition;

  int get overall => attributes.overallFor(position);

  bool get atPotential => overall >= potential;

  /// ポテンシャルの見せ方。数値そのものは隠す。
  String get potentialBand {
    final headroom = potential - overall;
    if (potential >= 88) return '別格';
    if (potential >= 80) return '高い';
    if (headroom >= 15) return '伸びしろ大';
    if (headroom >= 6) return '普通';
    return '頭打ち';
  }

  Player copyWith({
    int? age,
    Attributes? attributes,
    Position? position,
    int? condition,
  }) =>
      Player(
        name: name,
        age: age ?? this.age,
        position: position ?? this.position,
        attributes: attributes ?? this.attributes,
        potential: potential,
        traits: traits,
        condition: (condition ?? this.condition)
            .clamp(0, Formulas.conditionMax)
            .toInt(),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'age': age,
        'position': position.name,
        'attributes': attributes.toJson(),
        'potential': potential,
        'traits': traits.map((t) => t.name).toList(),
        'condition': condition,
      };

  factory Player.fromJson(Map<String, dynamic> json) {
    final attributes =
        Attributes.fromJson(json['attributes'] as Map<String, dynamic>);
    final position = Position.parse(json['position'] as String);
    return Player(
      name: json['name'] as String,
      age: json['age'] as int,
      position: position,
      attributes: attributes,
      // ポテンシャルを足す前の保存データには無い。今の総合力に少し上乗せする。
      potential: json['potential'] as int? ??
          (attributes.overallFor(position) + 8),
      traits: [
        for (final n in (json['traits'] as List? ?? const []))
          if (Trait.values.any((t) => t.name == n))
            Trait.values.byName(n as String),
      ],
      condition: json['condition'] as int? ?? Formulas.conditionMax,
    );
  }
}
