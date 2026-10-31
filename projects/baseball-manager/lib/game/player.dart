import 'at_bat.dart';
import 'career.dart';
import 'skills.dart';
import 'traits.dart';

/// `twoWay`(二刀流)は打者と投手の両方の能力を持つ。選べるのはプロの段階だけ(`switchRole`)。
enum Role { batter, pitcher, twoWay }

/// 能力。0〜99。野手と投手で使うものが違う。
enum Ability {
  contact,
  power,
  trajectory,
  speed,
  arm,
  fielding,
  catching,
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

/// 打者の能力(パワプロと同じ7つ)。弾道・肩力・捕球が、守備と長打の中身を分ける。
const batterAbilities = [
  Ability.trajectory,
  Ability.contact,
  Ability.power,
  Ability.speed,
  Ability.arm,
  Ability.fielding,
  Ability.catching,
];
const pitcherAbilities = [Ability.stuff, Ability.control, Ability.stamina];

List<Ability> abilitiesOf(Role r) => switch (r) {
      Role.batter => batterAbilities,
      Role.pitcher => pitcherAbilities,
      Role.twoWay => [...batterAbilities, ...pitcherAbilities],
    };

class Player {
  Player({
    required this.name,
    required this.role,
    required this.age,
    required this.potential,
    Map<Ability, int>? abilities,
    this.traits = const {},
    this.gifts = const {},
    this.skills = const {},
  }) : abilities = abilities ?? {for (final a in abilitiesOf(role)) a: 20};

  final String name;
  final Role role; // 役割は `switchRole` 以外では変わらない
  final int age;

  /// 素質 0〜100。伸びの上限と速さに効く。生まれつきで変わらない。
  final int potential;
  final Map<Ability, int> abilities;

  /// 特性(個性)。能力とは別に効き方を変える。`traits.dart`。
  final Set<Trait> traits;

  /// 天賦(能力ごとの才能の偏り -2〜+2)。生まれつきで変わらない。`talent.dart`。
  final Map<Ability, int> gifts;

  /// 特殊能力(経験点で取る。特性とは別の枠)。`skills.dart`。
  final Set<Skill> skills;

  int gift(Ability a) => gifts[a] ?? 0;

  int of(Ability a) => abilities[a] ?? 0;

  Player copyWith({
    int? age,
    Role? role,
    int? potential,
    Map<Ability, int>? abilities,
    Set<Trait>? traits,
    Map<Ability, int>? gifts,
    Set<Skill>? skills,
  }) =>
      Player(
        name: name,
        role: role ?? this.role,
        age: age ?? this.age,
        potential: potential ?? this.potential,
        abilities: abilities ?? this.abilities,
        traits: traits ?? this.traits,
        gifts: gifts ?? this.gifts,
        skills: skills ?? this.skills,
      );

  /// 守備力(守備と捕球から)。失策や守備の表彰に使う。
  int get defense =>
      ((of(Ability.fielding) * 6 + of(Ability.catching) * 4) / 10).round();

  /// 打席の計算に使う形。長打は弾道が3割、四球の選びやすさはミートに連動する。
  Batter toBatter() => Batter(
      contact: of(Ability.contact),
      power: ((of(Ability.power) * 7 + of(Ability.trajectory) * 3) / 10).round(),
      eye: of(Ability.contact));
  Pitcher toPitcher() =>
      Pitcher(control: of(Ability.control), stuff: of(Ability.stuff));

  Map<String, dynamic> toJson() => {
        'name': name,
        'role': role.name,
        'age': age,
        'potential': potential,
        'abilities': {for (final e in abilities.entries) e.key.name: e.value},
        'traits': [for (final t in traits) t.name],
        'gifts': {for (final e in gifts.entries) e.key.name: e.value},
        'skills': [for (final s in skills) s.name],
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
    // 古いセーブ(能力が5つだった頃)は、足りない打者の能力を今ある能力から補う。選球眼は無くなった。
    if (ab.isNotEmpty && role != Role.pitcher) {
      final c = ab[Ability.contact] ?? 20, pw = ab[Ability.power] ?? 20;
      final f = ab[Ability.fielding] ?? 20;
      ab.putIfAbsent(Ability.trajectory, () => ((c + pw) / 2).round());
      ab.putIfAbsent(Ability.arm, () => f);
      ab.putIfAbsent(Ability.catching, () => f);
    }
    return Player(
      name: (j['name'] as String?) ?? '名無し',
      role: role,
      age: (j['age'] as num?)?.toInt() ?? 6,
      potential: (j['potential'] as num?)?.toInt() ?? 50,
      abilities: ab.isEmpty ? null : ab,
      traits: {
        for (final s in (j['traits'] as List?) ?? const [])
          if (Trait.parse(s as String) != null) Trait.parse(s)!,
      },
      gifts: giftsFromJson(j['gifts']),
      skills: {
        for (final s in (j['skills'] as List?) ?? const [])
          if (Skill.parse(s as String) != null) Skill.parse(s)!,
        // 特殊能力に移した昔の特性(長距離砲など)は、特殊能力として読み替える
        for (final s in (j['traits'] as List?) ?? const [])
          if (legacyTraitSkills[s] != null) legacyTraitSkills[s]!,
      },
    );
  }
}

/// 転向で新しく持つ能力の初期値。ゼロからではないが、本職よりは低い。
const switchStartLevel = 25;

/// プロの段階でだけ役割を変えられる(二刀流にする/本職に戻す)。
/// 新しく持つ能力は `switchStartLevel`、持たなくなる能力は消える。
Player switchRole(Player p, Role to, Stage stage) {
  if (stage != Stage.pro) {
    throw StateError('役割を変えられるのはプロの段階だけ: $stage');
  }
  final ab = <Ability, int>{
    for (final a in abilitiesOf(to)) a: p.abilities[a] ?? switchStartLevel,
  };
  return p.copyWith(role: to, abilities: ab);
}

/// 天賦の読み込み。無い・壊れている項目は0(古いセーブは天賦なし)。
Map<Ability, int> giftsFromJson(Object? raw) {
  final d = <Ability, int>{};
  if (raw is Map) {
    for (final e in raw.entries) {
      final a = Ability.parse('${e.key}');
      final v = e.value;
      if (a != null && v is num) d[a] = v.toInt().clamp(-2, 2);
    }
  }
  return d;
}
