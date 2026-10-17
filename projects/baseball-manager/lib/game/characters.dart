import 'dart:math';

import 'career.dart';
import 'exp.dart';
import 'player.dart';
import 'traits.dart';

/// 登場人物の種類。名前はすべて架空(実在の人物と無関係)。
enum Kind {
  teammate('チームメイト'),
  rival('ライバル'),
  family('家族'),
  lover('恋人'),
  coach('コーチ');

  const Kind(this.label);
  final String label;
}

/// コーチから「コツ」を何回教わると特性を習得できるか。
const tipsNeeded = 4;

class Character {
  Character({
    required this.id,
    required this.name,
    required this.kind,
    this.bond = 0,
    this.specialty,
    this.teaches,
    this.tips = 0,
    this.talent = 0,
  });

  final String id;
  final String name;
  final Kind kind;

  /// 絆 0〜100。ライバルでは「切磋琢磨の度合い」。
  int bond;

  /// チームメイトの得意分野。同じ種類の練習で友情タッグが起きる。
  final Ability? specialty;

  /// コーチが教えてくれる特性。
  final Trait? teaches;
  int tips;

  /// ライバルの素質 40〜90。強さの頭打ちを決める。
  final int talent;

  void addBond(int n) => bond = (bond + n).clamp(0, 100);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        'bond': bond,
        'specialty': specialty?.name,
        'teaches': teaches?.name,
        'tips': tips,
        'talent': talent,
      };

  /// 項目を足すときは既定値を置く。
  factory Character.fromJson(Map<String, dynamic> j) => Character(
        id: (j['id'] as String?) ?? 'x',
        name: (j['name'] as String?) ?? '名無し',
        kind: Kind.values.firstWhere((k) => k.name == j['kind'],
            orElse: () => Kind.teammate),
        bond: (j['bond'] as num?)?.toInt() ?? 0,
        specialty: Ability.parse((j['specialty'] as String?) ?? ''),
        teaches: Trait.parse((j['teaches'] as String?) ?? ''),
        tips: (j['tips'] as num?)?.toInt() ?? 0,
        talent: (j['talent'] as num?)?.toInt() ?? 0,
      );
}

/// ライバルの、その年齢での強さ(能力の総合評価と同じ尺度)。
/// 13歳から伸びて22歳ごろ頭打ち、34歳から落ちる。
double rivalLevel(Character r, int age) {
  final peak = 35 + r.talent * 0.5; // 40→55、90→80
  final grow = ((age - 6) / 16).clamp(0.2, 1.0);
  final decline = age > 33 ? max(0.5, 1 - (age - 33) * 0.05) : 1.0;
  return peak * grow * decline;
}

const _surnames = [
  '朝倉',
  '五十嵐',
  '岩井',
  '内藤',
  '大槻',
  '加賀',
  '桐生',
  '久保田',
  '小宮',
  '榊原',
  '白石',
  '須藤',
  '高梨',
  '辻',
  '長谷',
  '日向',
  '藤堂',
  '真壁',
  '宮坂',
  '八木'
];
const _given = [
  '蓮',
  '大地',
  '颯',
  '陽斗',
  '悠真',
  '樹',
  '航',
  '拓海',
  '隼',
  '凛',
  '奏',
  '湊',
  '璃央',
  '翼',
  '亮',
  '悠',
  '駿',
  '怜',
  '朔',
  '晴'
];
const _loverGiven = ['美咲', '葵', '陽菜', '凛', '紬', '詩織', '澪', '千夏', '彩', '楓'];

String _name(Random rng, Set<String> used, {bool lover = false}) {
  for (var i = 0; i < 50; i++) {
    final n = lover
        ? '${_surnames[rng.nextInt(_surnames.length)]} ${_loverGiven[rng.nextInt(_loverGiven.length)]}'
        : '${_surnames[rng.nextInt(_surnames.length)]} ${_given[rng.nextInt(_given.length)]}';
    if (used.add(n)) return n;
  }
  return '名無し';
}

/// 段階ごとにコーチが教えうる特性。
const _taught = <Stage, List<Trait>>{
  Stage.youth: [Trait.hardWorker, Trait.sunny, Trait.ironMan],
  Stage.juniorHigh: [Trait.sturdy, Trait.ironMan, Trait.hardWorker],
  Stage.highSchool: [Trait.clutch, Trait.genius, Trait.starPower],
  Stage.pathChoice: [Trait.longevity, Trait.clutch, Trait.starPower],
  Stage.pro: [Trait.longevity, Trait.genius, Trait.clutch, Trait.starPower],
};

/// いま習得できるものから1つ。なければ null。
Trait? teachableTrait(Stage s, Set<Trait> have, Random rng) {
  final pool = [
    for (final t in _taught[s] ?? const <Trait>[])
      if (canGain(have, t)) t
  ];
  return pool.isEmpty ? null : pool[rng.nextInt(pool.length)];
}

/// 友情タッグ練習で経験点が増える倍率。
const tagMultiplier = 1.3;

/// 登場人物たち。
class Cast {
  Cast(this.members, {this.rivalWins = 0, this.rivalLosses = 0});

  final List<Character> members;
  int rivalWins;
  int rivalLosses;

  Character? _first(Kind k) {
    for (final m in members) {
      if (m.kind == k) return m;
    }
    return null;
  }

  Character? get rival => _first(Kind.rival);
  Character? get lover => _first(Kind.lover);
  Character? get family => _first(Kind.family);
  Character? get coach => _first(Kind.coach);
  List<Character> get teammates => [
        for (final m in members)
          if (m.kind == Kind.teammate) m
      ];

  /// 6歳の始まり: 家族・ライバル(同い年)・チームメイト・コーチ。
  factory Cast.initial(Random rng, Role role, Set<Trait> have) {
    final used = <String>{};
    final c = Cast([
      Character(id: 'family', name: '母', kind: Kind.family, bond: 30),
      Character(
        id: 'rival',
        name: _name(rng, used),
        kind: Kind.rival,
        talent: 40 + rng.nextInt(51),
      ),
    ]);
    c._cast(Stage.youth, rng, role, have, used);
    return c;
  }

  /// チームメイトとコーチを入れ替える。
  void _cast(
      Stage s, Random rng, Role role, Set<Trait> have, Set<String> used) {
    members.removeWhere((m) => m.kind == Kind.teammate || m.kind == Kind.coach);
    final abilities = abilitiesOf(role == Role.twoWay ? Role.batter : role);
    for (var i = 0; i < 3; i++) {
      members.add(Character(
        id: 'mate$i',
        name: _name(rng, used),
        kind: Kind.teammate,
        bond: 10 + rng.nextInt(15),
        specialty: abilities[rng.nextInt(abilities.length)],
      ));
    }
    members.add(Character(
      id: 'coach',
      name: _name(rng, used),
      kind: Kind.coach,
      teaches: teachableTrait(s, have, rng),
    ));
  }

  /// 段階が変わったとき。仲間とコーチが替わり、高校で恋人が現れる。
  void rotate(Stage s, Random rng, Role role, Set<Trait> have) {
    final used = {for (final m in members) m.name};
    _cast(s, rng, role, have, used);
    if (s == Stage.highSchool && lover == null) {
      members.add(Character(
        id: 'lover',
        name: _name(rng, used, lover: true),
        kind: Kind.lover,
        bond: 10,
      ));
    }
  }

  /// 友情タッグ練習の相手。重点と同じ種類が得意な仲間のうち絆の高い順に、
  /// 絆に応じた確率で。起きなければ null。
  Character? pickTagMate(Ability focus, Random rng) {
    final key = categoryOf(focus);
    final mates = teammates
        .where((m) => m.specialty != null && categoryOf(m.specialty!) == key)
        .toList()
      ..sort((a, b) => b.bond.compareTo(a.bond));
    for (final m in mates) {
      if (rng.nextDouble() < 0.2 + m.bond / 250) return m;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'members': [for (final m in members) m.toJson()],
        'rivalWins': rivalWins,
        'rivalLosses': rivalLosses,
      };

  factory Cast.fromJson(Map<String, dynamic> j) => Cast(
        [
          for (final m in (j['members'] as List?) ?? const [])
            Character.fromJson((m as Map).cast<String, dynamic>()),
        ],
        rivalWins: (j['rivalWins'] as num?)?.toInt() ?? 0,
        rivalLosses: (j['rivalLosses'] as num?)?.toInt() ?? 0,
      );
}
