import 'dart:math';

import 'exp.dart';
import 'player.dart';
import 'traits.dart';

/// 特殊能力(パワプロの特殊能力のように、経験点で取る)。特性(生まれつきの体質・性格)とは別の枠。
///
/// - 取るには、その種類(打撃・守備走塁・投球)の経験点を払う(`skillCost`)。
/// - **コツ**(0〜`maxSkillTips`)が貯まるほど安くなる。コツは研究・特訓・練習試合・交流・コーチで貯まる。
/// - 金の特殊能力(`gold`)は、もとになる特殊能力(`requires`)を持っていないと取れない。
/// - 効き方は試合の間だけ(`skillAbilityDelta` / `skillMatchBonus`)。総合評価やドラフトの点には入らない。
enum Skill {
  // ── 打者(打撃) ──
  chance('チャンス◯', '大会・世界大会の勝負どころに強い(体調+6相当)。', Category.batting, 30),
  powerHitter('パワーヒッター', '試合でパワー+6。', Category.batting, 40),
  averageHitter('アベレージヒッター', '試合でミート+6。', Category.batting, 40),
  eyePlus('選球眼◯', '試合で選球眼+6・ミート+1。', Category.batting, 35),
  wideAngle('広角打法', '試合でミート+3・パワー+3。', Category.batting, 45),
  // ── 打者(守備走塁) ──
  stealer('盗塁◯', '試合で走力+6。', Category.running, 30),
  fieldMaster('守備職人', '試合で守備+6。', Category.running, 30),
  strongArm('強肩', '試合で守備+3・走力+3。', Category.running, 35),
  // ── 打者の金特 ──
  geniusBat('天才打者', '金の特殊能力。試合でミート+8・パワー+4・選球眼+4。', Category.batting, 120,
      gold: true, requiresName: 'averageHitter'),
  artist('アーチスト', '金の特殊能力。試合でパワー+12。', Category.batting, 120,
      gold: true, requiresName: 'powerHitter'),
  // ── 投手(投球) ──
  strikeout('奪三振', '試合で球威+5。', Category.pitching, 40),
  controlPlus('コントロール◯', '試合で制球+6。', Category.pitching, 40),
  staminaPlus('スタミナ◯', '試合でスタミナ+6。', Category.pitching, 35),
  pinch('対ピンチ◯', '大会・世界大会の勝負どころに強い(体調+6相当)。', Category.pitching, 30),
  nobi('ノビ◯', '試合で球威+3・制球+2。', Category.pitching, 40),
  heavyBall('重い球', '試合で球威+3・スタミナ+2。', Category.pitching, 35),
  // ── 投手の金特 ──
  geniusArm('天才投手', '金の特殊能力。試合で球威+8・制球+6。', Category.pitching, 130,
      gold: true, requiresName: 'strikeout'),
  precision('精密機械', '金の特殊能力。試合で制球+12。', Category.pitching, 120,
      gold: true, requiresName: 'controlPlus');

  const Skill(this.label, this.description, this.category, this.baseCost,
      {this.gold = false, this.requiresName});

  final String label;
  final String description;

  /// 払う経験点の種類。
  final Category category;

  /// コツ0のときの値段(経験点)。
  final int baseCost;

  /// 金の特殊能力(もとの特殊能力が要る・高い)。
  final bool gold;
  final String? requiresName;

  /// 金特のもとになる特殊能力。
  Skill? get requires => requiresName == null ? null : Skill.parse(requiresName!);

  /// この役割の選手が取れるか(打者の特殊能力は投手には取れない。二刀流は両方)。
  bool appliesTo(Role r) => usableCategories(r).contains(category);

  /// 大会の勝負どころに効く(練習試合でコツが貯まりやすい)特殊能力か。
  bool get forMatches =>
      this == Skill.chance ||
      this == Skill.pinch ||
      this == Skill.stealer ||
      this == Skill.staminaPlus;

  static Skill? parse(String s) {
    for (final k in Skill.values) {
      if (k.name == s) return k;
    }
    return null;
  }
}

/// コツの上限。1つで値段が10%下がり、上限で半額。
const maxSkillTips = 5;
const skillTipDiscount = 0.10;

/// コツ `tips` のときの値段。
int skillCost(Skill s, int tips) =>
    max(1, (s.baseCost * (1 - skillTipDiscount * tips.clamp(0, maxSkillTips))).round());

/// 役割で取れる特殊能力の一覧(画面の並び順)。
List<Skill> skillsFor(Role r) => [
      for (final s in Skill.values)
        if (s.appliesTo(r)) s
    ];

/// 取れない理由(取れるなら null)。
String? skillBlock(Player p, Skill s, ExpPool pool, int tips) {
  if (!s.appliesTo(p.role)) return 'この役割では取れない';
  if (p.skills.contains(s)) return '取得済み';
  final req = s.requires;
  if (req != null && !p.skills.contains(req)) return '「${req.label}」が先に要る';
  if (pool.of(s.category) < skillCost(s, tips)) return '経験点が足りない';
  return null;
}

/// 試合の間だけ効く能力の上乗せ(特殊能力のぶん)。
Map<Ability, int> skillAbilityDelta(Set<Skill> s) {
  final d = <Ability, int>{};
  void add(Ability a, int n) => d[a] = (d[a] ?? 0) + n;
  for (final k in s) {
    switch (k) {
      case Skill.powerHitter:
        add(Ability.power, 6);
      case Skill.averageHitter:
        add(Ability.contact, 6);
      case Skill.eyePlus:
        add(Ability.eye, 6);
        add(Ability.contact, 1);
      case Skill.wideAngle:
        add(Ability.contact, 3);
        add(Ability.power, 3);
      case Skill.stealer:
        add(Ability.speed, 6);
      case Skill.fieldMaster:
        add(Ability.fielding, 6);
      case Skill.strongArm:
        add(Ability.fielding, 3);
        add(Ability.speed, 3);
      case Skill.geniusBat:
        add(Ability.contact, 8);
        add(Ability.power, 4);
        add(Ability.eye, 4);
      case Skill.artist:
        add(Ability.power, 12);
      case Skill.strikeout:
        add(Ability.stuff, 5);
      case Skill.controlPlus:
        add(Ability.control, 6);
      case Skill.staminaPlus:
        add(Ability.stamina, 6);
      case Skill.nobi:
        add(Ability.stuff, 3);
        add(Ability.control, 2);
      case Skill.heavyBall:
        add(Ability.stuff, 3);
        add(Ability.stamina, 2);
      case Skill.geniusArm:
        add(Ability.stuff, 8);
        add(Ability.control, 6);
      case Skill.precision:
        add(Ability.control, 12);
      case Skill.chance:
      case Skill.pinch:
        break;
    }
  }
  return d;
}

/// 特殊能力が総合評価に足す値。上乗せの合計(大会に効くものは6相当)を5で割り、半分にする。
/// 定価で取ると、同じ経験点で能力を上げるのとほぼ同じ。コツが貯まるほど得になる(コツ5で倍)。
double skillRating(Player p) {
  if (p.skills.isEmpty) return 0;
  final pts = skillAbilityDelta(p.skills).values.fold<int>(0, (a, b) => a + b) +
      skillMatchBonus(p.skills);
  // 投手は能力が3つで1点の重みが大きいので、打者と同じ5で割る(役割で得にならないように)。
  return pts / batterAbilities.length * 0.5;
}

/// 大会(世界大会も)の体調に足す値(特殊能力のぶん)。
int skillMatchBonus(Set<Skill> s) =>
    (s.contains(Skill.chance) ? 6 : 0) + (s.contains(Skill.pinch) ? 6 : 0);

/// 大会の体調に足す値(特性＋特殊能力)。
int matchBonus(Player p) => tournamentBonus(p.traits) + skillMatchBonus(p.skills);

/// 古いセーブの特性の名前(特殊能力に移したもの)を、特殊能力に読み替える。
const legacyTraitSkills = <String, Skill>{
  'slugger': Skill.powerHitter,
  'contactHitter': Skill.averageHitter,
  'patient': Skill.eyePlus,
  'speedster': Skill.stealer,
  'fireballer': Skill.strikeout,
  'finesse': Skill.controlPlus,
  'workhorse': Skill.staminaPlus,
  'prodigyBat': Skill.geniusBat,
  'prodigyArm': Skill.geniusArm,
};

/// コツを貯める先を選ぶ。`category` が与えられればその種類から。取れるもの(未取得・役割に合う)のうち、
/// コツがいちばん多いもの(同じならくじ)。金特は、もとを持っているときだけ候補にする。
Skill? pickTipTarget(Player p, Map<Skill, int> tips, Random rng,
    {Category? category, bool matchesOnly = false}) {
  final cands = [
    for (final s in skillsFor(p.role))
      if (!p.skills.contains(s) &&
          (tips[s] ?? 0) < maxSkillTips &&
          (category == null || s.category == category) &&
          (!matchesOnly || s.forMatches) &&
          (s.requires == null || p.skills.contains(s.requires)))
        s
  ];
  if (cands.isEmpty) return null;
  final best = cands.map((s) => tips[s] ?? 0).reduce(max);
  final top = [
    for (final s in cands)
      if ((tips[s] ?? 0) == best) s
  ];
  return top[rng.nextInt(top.length)];
}

Map<String, int> skillTipsToJson(Map<Skill, int> m) =>
    {for (final e in m.entries) if (e.value > 0) e.key.name: e.value};

Map<Skill, int> skillTipsFromJson(Object? j) {
  final out = <Skill, int>{};
  if (j is Map) {
    for (final e in j.entries) {
      final s = Skill.parse('${e.key}');
      if (s != null) out[s] = ((e.value as num?)?.toInt() ?? 0).clamp(0, maxSkillTips);
    }
  }
  return out;
}
