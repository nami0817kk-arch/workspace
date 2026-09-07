import 'attributes.dart';

/// プレイヤーが操作する選手。
class Player {
  const Player({
    required this.name,
    required this.age,
    required this.position,
    required this.attributes,
  });

  final String name;
  final int age;
  final Position position;
  final Attributes attributes;

  int get overall => attributes.overallFor(position);

  Player copyWith({int? age, Attributes? attributes, Position? position}) =>
      Player(
        name: name,
        age: age ?? this.age,
        position: position ?? this.position,
        attributes: attributes ?? this.attributes,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'age': age,
        'position': position.name,
        'attributes': attributes.toJson(),
      };

  factory Player.fromJson(Map<String, dynamic> json) => Player(
        name: json['name'] as String,
        age: json['age'] as int,
        position: Position.values.byName(json['position'] as String),
        attributes:
            Attributes.fromJson(json['attributes'] as Map<String, dynamic>),
      );
}
