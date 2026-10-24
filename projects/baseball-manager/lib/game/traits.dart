import 'dart:math';

import 'player.dart';
import 'skills.dart';

/// 特性。能力とは別に、選手の個性として効き方を変える。
/// 良いものだけでなく、代償のあるもの・悪いものもある。
enum Trait {
  lateBloomer('大器晩成', '少年期は伸びが鈍いが、19歳以降に大きく伸びる。', true),
  earlyBloomer('早熟', '若いうちは伸びが大きいが、衰えも早い。', false),
  hardWorker('努力家', '練習の伸びが1割増える。', true),
  genius('天才肌', '伸びが2割増える。', true),
  sturdy('頑丈', '怪我をしにくい。', true),
  glassBody('ガラスの肉体', '怪我をしやすいが、伸びは1.15倍。', false),
  ironMan('鉄人', '疲れが溜まりにくい。', true),
  sunny('前向き', '気持ちが上がりやすく、下がりにくい。', true),
  clutch('勝負強い', '大会での体調が+10相当になる。', true),
  nervy('ノミの心臓', '大会での体調が-10相当になる。', false),
  starPower('華がある', 'ドラフトの評価に+5。', true),
  longevity('長持ち', '衰えがゆるやか。', true),

  // 試合の能力を足すもの(長距離砲・剛腕など)は、2026-10-24 に特殊能力(`skills.dart`)へ移した。
  // 特性は、生まれつきの体質と性格だけ。

  // ── 誰でも ──
  leader('キャプテンシー', 'チームをまとめ、大会・シーズンのチーム力が+3。', true),
  moodMaker('ムードメーカー', '友情タッグの経験点が増える(1.5倍)。', true),
  quickRecovery('回復力', '休養で疲れがよく抜ける(1.5倍)。', true),
  worldStage('国際舞台に強い', '世界大会での体調が+10相当になる。', true),
  studious('研究熱心', '「研究」で貯まる特殊能力のコツが1つ多い。', true),
  moody('ムラっ気', '気持ちの上下が激しい(上がるのも下がるのも1.3倍)。', false),
  slowRecovery('疲れが抜けにくい', '休養で疲れが抜けにくい(0.6倍)。', false),
  lonely('一匹狼', '友情タッグの経験点が減る(0.6倍)が、練習の伸びは1割増える。', false),

  // ── レア特性(生まれつき4%、または節目の「覚醒」でしか手に入らない) ──
  monster('怪物', '規格外。伸びが1割ほど増え、衰えも1割ゆるやか。', true),
  steelBody('鋼の肉体', '衰えがゆるやか(0.6倍)。疲れも溜まりにくい(0.8倍)。', true),
  ironWill('不屈', '怪我の影響が半分以下(0.4倍)。大会での体調が+5相当になる。', true),
  stagePresence('千両役者', '大会(世界大会も)での体調が+8相当になる。', true),
  fortune('強運', '練習の「失敗」が半分に、「大成功」が1.6倍出る。', true);

  const Trait(this.label, this.description, this.positive);
  final String label;
  final String description;

  /// 良い特性か(画面の色分けや、抽選の重みに使う)。
  final bool positive;

  /// 打者・投手のどちらに効く特性か。役割に縛られる特性は特殊能力へ移したので、いまは全部 `any`。
  TraitFor get forRole => TraitFor.any;

  /// レア特性か(通常の抽選には出ない。画面では金色で見せる)。
  bool get rare => rareTraits.contains(this);

  /// この役割の選手に意味がある特性か。二刀流は両方。
  bool appliesTo(Role r) => switch (forRole) {
        TraitFor.any => true,
        TraitFor.batter => r != Role.pitcher,
        TraitFor.pitcher => r != Role.batter,
      };

  static Trait? parse(String s) {
    for (final t in Trait.values) {
      if (t.name == s) return t;
    }
    return null;
  }
}

/// 特性が効く役割。
enum TraitFor { any, batter, pitcher }

/// レア特性。生まれつき(`rareBirthChance`)か、節目の覚醒(`Game` の `_tryAwaken`)でだけ手に入る。
const rareTraits = <Trait>{
  Trait.monster,
  Trait.steelBody,
  Trait.ironWill,
  Trait.stagePresence,
  Trait.fortune,
};

/// 生まれつきレア特性を1つ持つ確率。
const rareBirthChance = 0.04;

/// 通常の特性の上限。レア特性は別枠で、最大 `maxRareTraits` 個まで(通常が埋まっていても覚醒できる)。
const maxTraits = 4;
const maxRareTraits = 2;

/// 同時に持てない組み合わせ。
const _conflicts = <Trait, Trait>{
  Trait.lateBloomer: Trait.earlyBloomer,
  Trait.sturdy: Trait.glassBody,
  Trait.clutch: Trait.nervy,
  Trait.quickRecovery: Trait.slowRecovery,
  Trait.moodMaker: Trait.lonely,
  Trait.sunny: Trait.moody,
};

/// 3つ以上の組み合わせではなく2つずつの矛盾のため、上の表だけでは足りないもの。
const _extraConflicts = <(Trait, Trait)>[
  (Trait.leader, Trait.lonely),
  (Trait.ironWill, Trait.glassBody),
  (Trait.ironWill, Trait.nervy),
  (Trait.stagePresence, Trait.nervy),
  (Trait.steelBody, Trait.earlyBloomer),
  (Trait.steelBody, Trait.glassBody),
  (Trait.monster, Trait.earlyBloomer),
];

bool _conflict(Trait a, Trait b) =>
    _conflicts[a] == b ||
    _conflicts[b] == a ||
    _extraConflicts
        .any((c) => (c.$1 == a && c.$2 == b) || (c.$1 == b && c.$2 == a));

/// `t` を新しく持てるか(重複・矛盾・上限)。
bool canGain(Set<Trait> have, Trait t) =>
    !have.contains(t) &&
    (t.rare
        ? have.where((h) => h.rare).length < maxRareTraits
        : have.where((h) => !h.rare).length < maxTraits) &&
    !have.any((h) => _conflict(h, t));

/// 持てるなら足した集合を、持てなければそのままを返す。
Set<Trait> gain(Set<Trait> have, Trait t) =>
    canGain(have, t) ? {...have, t} : have;

/// 生まれつきの出やすさ。最初の12個(成長・怪我・体調の基本の特性)は出やすく、
/// あとから増えた個性派は出にくい。良い特性は悪い特性の倍出る。
/// レア特性は通常の抽選に出さない(0)。
int _weight(Trait t) =>
    t.rare ? 0 : (t.positive ? 2 : 1) * (t.index < 12 ? 6 : 1);

/// 生まれつきの特性。0〜2個。良い特性が出やすい(悪いものは半分)。
Set<Trait> rollInnateTraits(Random rng, [Role? role]) {
  final r = rng.nextDouble();
  final n = r < 0.35 ? 0 : (r < 0.80 ? 1 : 2);
  var have = <Trait>{};
  for (var i = 0; i < n; i++) {
    final pool = [
      for (final t in Trait.values)
        if (canGain(have, t) && (role == null || t.appliesTo(role)))
          ...List.filled(_weight(t), t),
    ];
    if (pool.isEmpty) break;
    have = gain(have, pool[rng.nextInt(pool.length)]);
  }
  return have;
}

/// 持てるレア特性から1つ選ぶ。無ければ null。
Trait? pickRare(Random rng, Set<Trait> have, Role role) {
  final pool = [
    for (final t in rareTraits)
      if (t.appliesTo(role) && canGain(have, t)) t,
  ];
  return pool.isEmpty ? null : pool[rng.nextInt(pool.length)];
}

/// 生まれつきのレア特性(4%)。持てなければそのまま。
Set<Trait> rollBirthRare(Random rng, Set<Trait> have, Role role) {
  if (rng.nextDouble() >= rareBirthChance) return have;
  final t = pickRare(rng, have, role);
  return t == null ? have : gain(have, t);
}

// ── 効き方。各システムはここだけを見る ──

/// 伸びる年(成長率 >= 0)の倍率。`age` は今の年齢。
double growthMultiplier(Set<Trait> t, int age) {
  var m = 1.0;
  if (t.contains(Trait.lateBloomer)) m *= age < 19 ? 0.7 : 1.4;
  if (t.contains(Trait.earlyBloomer)) m *= age < 16 ? 1.3 : 1.0;
  if (t.contains(Trait.hardWorker)) m *= 1.1;
  if (t.contains(Trait.genius)) m *= 1.2;
  if (t.contains(Trait.monster)) m *= 1.12;
  if (t.contains(Trait.glassBody)) m *= 1.15;
  if (t.contains(Trait.lonely)) m *= 1.1;
  return m;
}

/// 衰える年(成長率 < 0)の倍率。大きいほど落ちる。
double declineMultiplier(Set<Trait> t) {
  var m = 1.0;
  if (t.contains(Trait.earlyBloomer)) m *= 1.3;
  if (t.contains(Trait.longevity)) m *= 0.6;
  if (t.contains(Trait.monster)) m *= 0.9;
  if (t.contains(Trait.steelBody)) m *= 0.6;
  return m;
}

double injuryMultiplier(Set<Trait> t) {
  var m = 1.0;
  if (t.contains(Trait.sturdy)) m *= 0.5;
  if (t.contains(Trait.glassBody)) m *= 1.8;
  if (t.contains(Trait.ironWill)) m *= 0.4;
  return m;
}

/// 疲労の増え方(増えるときだけ。減るときは変えない)。
double fatigueMultiplier(Set<Trait> t) =>
    (t.contains(Trait.ironMan) ? 0.7 : 1.0) *
    (t.contains(Trait.steelBody) ? 0.8 : 1.0);

/// 気持ちの上がり方 / 下がり方。
double moraleGainMultiplier(Set<Trait> t) =>
    (t.contains(Trait.sunny) ? 1.5 : 1.0) *
    (t.contains(Trait.moody) ? 1.3 : 1.0);
double moraleLossMultiplier(Set<Trait> t) =>
    (t.contains(Trait.sunny) ? 0.5 : 1.0) *
    (t.contains(Trait.moody) ? 1.3 : 1.0);

/// 大会の体調に足す値。
int tournamentBonus(Set<Trait> t) =>
    (t.contains(Trait.clutch) ? 10 : 0) -
    (t.contains(Trait.nervy) ? 10 : 0) +
    (t.contains(Trait.ironWill) ? 5 : 0) +
    (t.contains(Trait.stagePresence) ? 8 : 0);

/// ドラフトの点数に足す値。
double draftBonus(Set<Trait> t) => t.contains(Trait.starPower) ? 5 : 0;

// ── 新しい特性の効き方 ──

/// 試合の間だけ、特殊能力で能力が上限(99)を超えられる。能力が99でも、上乗せが消えないように。
const gameAbilityCap = 120;

/// 特殊能力(と特性)を反映した、試合用の選手。元の選手は変えない。
/// 試合の能力を足すのは特殊能力だけ(特性は体質と性格。2026-10-24 に分けた)。
Player traitAdjusted(Player p) {
  final d = skillAbilityDelta(p.skills);
  if (d.isEmpty) return p;
  return p.copyWith(abilities: {
    for (final e in p.abilities.entries)
      e.key: (e.value + (d[e.key] ?? 0)).clamp(0, gameAbilityCap),
  });
}

/// 大会・シーズンのチーム力に足す値。
int traitTeamBonus(Set<Trait> t) => t.contains(Trait.leader) ? 3 : 0;

/// 休養などで疲れが「抜ける」ときの倍率(疲れが増えるときは変えない)。
double recoveryMultiplier(Set<Trait> t) =>
    (t.contains(Trait.quickRecovery) ? 1.5 : 1.0) *
    (t.contains(Trait.slowRecovery) ? 0.6 : 1.0);

/// 友情タッグの経験点の倍率(基本の倍率に掛ける)。
double tagTraitMultiplier(Set<Trait> t) =>
    (t.contains(Trait.moodMaker) ? 1.5 : 1.0) *
    (t.contains(Trait.lonely) ? 0.6 : 1.0);

/// 世界大会の体調に足す値。
int worldBonus(Set<Trait> t) => t.contains(Trait.worldStage) ? 10 : 0;

/// 練習の出来の振れ方。強運は失敗が半分・大成功が1.6倍(平均は少し上がる)。
({double bad, double great}) outcomeLuck(Set<Trait> t) =>
    t.contains(Trait.fortune) ? (bad: 0.5, great: 1.6) : (bad: 1.0, great: 1.0);
