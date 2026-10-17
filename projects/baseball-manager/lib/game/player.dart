import 'at_bat.dart';

enum Role { batter, pitcher }

/// 能力。0〜99。野手と投手で使うものが違う。
enum Ability {
  contact,
  power,
  speed,
  fielding,
  eye,
  stuff,
  control,
  stamina;

  static Ability? parse(String s) {
    for (final a in Ability.values) {
      if (a.name == s) return a;
    }
    return null;
  }
}

const batterAbilities = [
  Ability.contact,
  Ability.power,
  Ability.speed,
  Ability.fielding,
  Ability.eye,
];
const pitcherAbilities = [Ability.stuff, Ability.control, Ability.stamina];

List<Ability> abilitiesOf(Role r) =>
    r == Role.batter ? batterAbilities : pitcherAbilities;

class Player {
  Player({
    required this.name,
    required this.role,
    required this.age,
    required this.potential,
    Map<Ability, int>? abilities,
  }) : abilities = abilities ?? {for (final a in abilitiesOf(role)) a: 20};

  final String name;
  final Role role;
  final int age;

  /// 素質 0〜100。伸びの上限と速さに効く。生まれつきで変わらない。
  final int potential;
  final Map<Ability, int> abilities;

  int of(Ability a) => abilities[a] ?? 0;

  Player copyWith({int? age, Map<Ability, int>? abilities}) => Player(
        name: name,
        role: role,
        age: age ?? this.age,
        potential: potential,
        abilities: abilities ?? this.abilities,
      );

  Batter toBatter() =>
      Batter(contact: of(Ability.contact), power: of(Ability.power), eye: of(Ability.eye));
  Pitcher toPitcher() =>
      Pitcher(control: of(Ability.control), stuff: of(Ability.stuff));

  Map<String, dynamic> toJson() => {
        'name': name,
        'role': role.name,
        'age': age,
        'potential': potential,
        'abilities': {for (final e in abilities.entries) e.key.name: e.value},
      };

  /// 項目を足すときは既定値を置く(既存セーブを壊さない)。
  factory Player.fromJson(Map<String, dynamic> j) {
    final role = Role.values.firstWhere(
      (r) => r.name == j['role'],
      orElse: () => Role.batter,
    );
    final raw = (j['abilities'] as Map?) ?? const {};
    final ab = <Ability, int>{};
    for (final e in raw.entries) {
      final a = Ability.parse(e.key as String);
      if (a != null) ab[a] = (e.value as num).toInt();
    }
    return Player(
      name: (j['name'] as String?) ?? '名無し',
      role: role,
      age: (j['age'] as num?)?.toInt() ?? 6,
      potential: (j['potential'] as num?)?.toInt() ?? 50,
      abilities: ab.isEmpty ? null : ab,
    );
  }
}
