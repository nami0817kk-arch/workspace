import 'career.dart';
import 'skills.dart';
import 'traits.dart';

/// 能力。0〜99。
enum Ability {
  threePoint('3Pシュート'),
  midRange('ミドル'),
  inside('ゴール下'),
  dribble('ドリブル'),
  pass('パス'),
  defense('ディフェンス'),
  rebound('リバウンド'),
  speed('スピード'),
  physical('フィジカル'),
  stamina('スタミナ'),
  freeThrow('フリースロー');

  const Ability(this.label);
  final String label;

  static Ability? parse(String s) {
    for (final a in Ability.values) {
      if (a.name == s) return a;
    }
    return null;
  }
}

/// ポジション。身長と能力から決まる(選べない)。
enum Position {
  pointGuard('PG'),
  shootingGuard('SG'),
  smallForward('SF'),
  powerForward('PF'),
  center('C');

  const Position(this.label);
  final String label;

  /// ポジションの持ち味(試合での効き方)。
  String get perk => switch (this) {
        Position.pointGuard => 'チームワークの効きが1.4倍',
        Position.shootingGuard => '勝負どころの3Pが決まりやすい(+8%)',
        Position.smallForward => '体調が崩れにくい(動きの良さ+0.03)',
        Position.powerForward => '勝負どころのドライブが決まりやすい(+7%)',
        Position.center => '勝負どころのディフェンスが決まりやすい(+8%)・リバウンド1.2倍',
      };
}

const abilityCap = 99;
const startLevel = 20;

class Player {
  Player({
    required this.name,
    required this.age,
    required this.potential,
    required this.heightCm,
    required this.heightGenes,
    Map<Ability, int>? abilities,
    this.traits = const {},
    this.skills = const {},
  }) : abilities = abilities ?? {for (final a in Ability.values) a: startLevel};

  final String name;
  final int age;

  /// 素質 0〜100。伸びの上限と速さに効く。生まれつきで変わらない。
  final int potential;

  /// 今の身長(cm)。
  final double heightCm;

  /// 最終身長の素質 0〜1。生まれつきで変わらない。
  final double heightGenes;
  final Map<Ability, int> abilities;
  final Set<Trait> traits;

  /// 得意技(条件を満たすと身につく)。
  final Set<Skill> skills;

  int of(Ability a) => abilities[a] ?? 0;

  Player copyWith({
    int? age,
    double? heightCm,
    Map<Ability, int>? abilities,
    Set<Trait>? traits,
    Set<Skill>? skills,
  }) =>
      Player(
        name: name,
        age: age ?? this.age,
        potential: potential,
        heightCm: heightCm ?? this.heightCm,
        heightGenes: heightGenes,
        abilities: abilities ?? this.abilities,
        traits: traits ?? this.traits,
        skills: skills ?? this.skills,
      );

  /// 身長が効く補正つきの能力(リバウンド・ゴール下は高いほど、ドリブル・スピードは低いほど有利)。
  /// 基準は 185cm。1cm あたり 0.4。
  double effective(Ability a) {
    final tall = (heightCm - 185) * 0.4;
    final v = of(a) +
        switch (a) {
          Ability.rebound || Ability.inside => tall,
          Ability.dribble || Ability.speed => -tall * 0.5,
          _ => 0,
        } +
        effectiveBonus(traits, a);
    return v.clamp(0, 120).toDouble();
  }

  Position get position {
    if (heightCm >= 203) return Position.center;
    if (heightCm >= 195) {
      // 内側が得意なら 199cm からセンター、それ未満はパワーフォワード。
      // 外が得意な大型は、199cm 以上ならパワーフォワード(ストレッチ)、未満はスモールフォワード。
      final inside = of(Ability.inside) >= of(Ability.threePoint);
      if (inside) return heightCm >= 199 ? Position.center : Position.powerForward;
      return heightCm >= 199 ? Position.powerForward : Position.smallForward;
    }
    if (heightCm >= 188) return Position.smallForward;
    if (of(Ability.pass) >= of(Ability.threePoint) &&
        of(Ability.dribble) >= of(Ability.midRange)) {
      return Position.pointGuard;
    }
    return heightCm >= 182 ? Position.shootingGuard : Position.pointGuard;
  }

  /// 身長の評価(0〜100)。155cm で 0、186cm で約48、210cm で約85、220cm 以上で100。
  /// 身長は能力の1つとして総合評価に入る(素質=ポテンシャルとは別。伸びは `heightGenes` と幼少期の生活習慣で決まる)。
  double get heightRating => heightRatingOf(heightCm);

  /// 総合評価(0〜99 付近)。ポジションごとに重みが違い、身長も能力として入る。
  double get overall {
    final w = _weights[position]!;
    var sum = 0.0, total = 0.0;
    for (final e in w.entries) {
      sum += effective(e.key) * e.value;
      total += e.value;
    }
    final hw = heightWeightOf(position);
    sum += heightRating * hw;
    total += hw;
    return (sum / total).clamp(0, 99).toDouble();
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'age': age,
        'potential': potential,
        'heightCm': heightCm,
        'heightGenes': heightGenes,
        'abilities': {for (final e in abilities.entries) e.key.name: e.value},
        'traits': [for (final t in traits) t.name],
        'skills': [for (final k in skills) k.name],
      };

  /// 項目を足すときは既定値を置く(既存セーブを壊さない)。
  factory Player.fromJson(Map<String, dynamic> j) {
    final raw = (j['abilities'] as Map?) ?? const {};
    final ab = <Ability, int>{for (final a in Ability.values) a: startLevel};
    for (final e in raw.entries) {
      final a = Ability.parse(e.key as String);
      if (a != null) ab[a] = (e.value as num).toInt();
    }
    return Player(
      name: (j['name'] as String?) ?? '名無し',
      age: (j['age'] as num?)?.toInt() ?? startAge,
      potential: (j['potential'] as num?)?.toInt() ?? 50,
      heightCm: (j['heightCm'] as num?)?.toDouble() ?? 118,
      heightGenes: (j['heightGenes'] as num?)?.toDouble() ?? 0.5,
      abilities: ab,
      traits: {
        for (final s in (j['traits'] as List?) ?? const [])
          if (Trait.parse(s as String) != null) Trait.parse(s)!,
      },
      skills: {
        for (final s in (j['skills'] as List?) ?? const [])
          if (Skill.parse(s as String) != null) Skill.parse(s)!,
      },
    );
  }
}

/// 身長の評価(0〜100)。
double heightRatingOf(double cm) => ((cm - 155) / 65 * 100).clamp(0, 100).toDouble();

/// 身長が総合評価に効く度合い(ポジションの重みと同じ尺度)。大きい選手ほど身長が効く。
int heightWeightOf(Position p) => switch (p) {
      Position.pointGuard => 1,
      Position.shootingGuard => 1,
      Position.smallForward => 2,
      Position.powerForward => 3,
      Position.center => 4,
    };

/// ポジションごとの能力の重み(総合評価に効く度合い)。
Map<Ability, int> weightsOf(Position p) => _weights[p]!;

const _weights = <Position, Map<Ability, int>>{
  Position.pointGuard: {
    Ability.dribble: 3,
    Ability.pass: 3,
    Ability.threePoint: 2,
    Ability.speed: 2,
    Ability.defense: 1,
    Ability.stamina: 1,
    Ability.freeThrow: 1,
  },
  Position.shootingGuard: {
    Ability.threePoint: 3,
    Ability.midRange: 3,
    Ability.dribble: 2,
    Ability.speed: 2,
    Ability.defense: 1,
    Ability.stamina: 1,
    Ability.freeThrow: 2,
  },
  Position.smallForward: {
    Ability.midRange: 2,
    Ability.threePoint: 2,
    Ability.defense: 2,
    Ability.inside: 1,
    Ability.rebound: 1,
    Ability.speed: 1,
    Ability.physical: 1,
    Ability.stamina: 1,
    Ability.freeThrow: 1,
  },
  Position.powerForward: {
    Ability.inside: 3,
    Ability.rebound: 3,
    Ability.physical: 2,
    Ability.defense: 2,
    Ability.midRange: 1,
    Ability.freeThrow: 1,
  },
  Position.center: {
    Ability.inside: 3,
    Ability.rebound: 3,
    Ability.defense: 3,
    Ability.physical: 3,
    Ability.stamina: 1,
    Ability.freeThrow: 1,
  },
};

/// 生まれの選手を作る。身長は 6歳で 112〜124cm。
Player newPlayer(
        String name, int potential, double heightGenes, Set<Trait> traits,
        {int bonus = 0}) =>
    Player(
      name: name,
      age: startAge,
      potential: potential.clamp(0, 100),
      heightCm: 112 + heightGenes.clamp(0, 1) * 12,
      heightGenes: heightGenes.clamp(0, 1).toDouble(),
      traits: traits,
      // 殿堂の実績から引き継ぐ初期能力。
      abilities: {for (final a in Ability.values) a: startLevel + bonus},
    );
