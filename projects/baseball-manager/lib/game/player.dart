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
  stamina,
  breaking;

  static Ability? parse(String s) {
    for (final a in Ability.values) {
      if (a.name == s) return a;
    }
    return null;
  }
}

/// 打者の能力(パワプロと同じ7つ)。弾道・肩力・捕球が、守備と長打の中身を分ける。
const batterAbilities = [
  Ability.contact,
  Ability.power,
  Ability.trajectory,
  Ability.speed,
  Ability.arm,
  Ability.fielding,
  Ability.catching,
];
/// 投手の能力(パワプロと同じ。球速・コントロール・スタミナ・変化球)。
const pitcherAbilities = [
  Ability.stuff,
  Ability.control,
  Ability.stamina,
  Ability.breaking,
];

List<Ability> abilitiesOf(Role r) => switch (r) {
      Role.batter => batterAbilities,
      // 投手も打撃・守備の能力を持つ(パワプロと同じ)。先に投球、あとに打撃・守備。
      Role.pitcher => [...pitcherAbilities, ...batterAbilities],
      Role.twoWay => [...batterAbilities, ...pitcherAbilities],
    };

/// 役割の本業の能力(総合評価・才能の平均・弱点の判定に使う)。投手の打撃・守備は含めない。
List<Ability> mainAbilitiesOf(Role r) => switch (r) {
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
      eye: _eyeOf(of(Ability.contact)));
  /// 打席の計算に使う形。変化球は球威に3割まぜる(球速だけでも、変化球だけでも抑えきれない)。
  Pitcher toPitcher() => Pitcher(
      control: of(Ability.control),
      stuff: ((of(Ability.stuff) * 7 + of(Ability.breaking) * 3) / 10).round());

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
    fillMissingAbilities(role, ab);
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

/// 四球の選びやすさ(`Batter.eye`)をミートから決める割合(%)。100でミートそのまま、0で一定(50)。
/// 選球眼をなくしたので、ミートが高いほど四球が増えすぎないよう弱めてある。`tool/balance.dart` で決めた。
const eyeFromContact = int.fromEnvironment('BAL_EYE', defaultValue: 50);

int _eyeOf(int contact) =>
    (50 + (contact - 50) * eyeFromContact / 100).round().clamp(0, 99);

/// 古いセーブ・殿堂の記録で足りない能力を補う(能力が5つだった頃・投手が投球だけだった頃)。
/// 選球眼は無くなったので捨てる。空なら何もしない(既定の値を使う)。
void fillMissingAbilities(Role role, Map<Ability, int> ab) {
  // 古いセーブ(能力が5つだった頃)は、足りない打者の能力を今ある能力から補う。選球眼は無くなった。
  if (ab.isNotEmpty) {
    final c = ab[Ability.contact] ?? 20, pw = ab[Ability.power] ?? 20;
    final f = ab[Ability.fielding] ?? 20;
    // 投手(能力が投球だけだった頃)は、打撃・守備を低い値で足す
    for (final a in batterAbilities) {
      if (role == Role.pitcher) ab.putIfAbsent(a, () => 20);
    }
    if (role != Role.pitcher) {
      ab.putIfAbsent(Ability.trajectory, () => ((c + pw) / 2).round());
      ab.putIfAbsent(Ability.arm, () => f);
      ab.putIfAbsent(Ability.catching, () => f);
    }
    // 変化球は、球威と制球の平均から
    if (role != Role.batter) {
      ab.putIfAbsent(Ability.breaking,
          () => (((ab[Ability.stuff] ?? 20) + (ab[Ability.control] ?? 20)) / 2).round());
    }
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
