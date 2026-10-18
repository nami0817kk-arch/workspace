import 'dart:math';

import 'player.dart';

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

  // ── 打者の特性 ──
  slugger('長距離砲', '試合でパワー+9、ミート-2。一発がある。', true, TraitFor.batter),
  contactHitter('アベレージヒッター', '試合でミート+9、パワー-2。当てるのがうまい。', true, TraitFor.batter),
  patient('選球眼の鬼', '試合で選球眼+10、ミート+2。四球を選べる。', true, TraitFor.batter),
  speedster('俊足', '試合で走力+8。二塁打・三塁打と盗塁が増える。', true, TraitFor.batter),

  // ── 投手の特性 ──
  fireballer('剛腕', '試合で球威+6、制球-4。三振を奪う。', true, TraitFor.pitcher),
  finesse('精密機械', '試合で制球+8。四球を出さない。', true, TraitFor.pitcher),
  workhorse('スタミナお化け', '試合でスタミナ+8。長いイニングを投げ抜く。', true, TraitFor.pitcher),

  // ── 誰でも ──
  leader('キャプテンシー', 'チームをまとめ、大会・シーズンのチーム力が+3。', true),
  moodMaker('ムードメーカー', '友情タッグの経験点が増える(1.5倍)。', true),
  quickRecovery('回復力', '休養で疲れがよく抜ける(1.5倍)。', true),
  worldStage('国際舞台に強い', '世界大会での体調が+10相当になる。', true),
  studious('研究熱心', '「研究」で貯まる経験点が1.4倍。', true),
  moody('ムラっ気', '気持ちの上下が激しい(上がるのも下がるのも1.3倍)。', false),
  slowRecovery('疲れが抜けにくい', '休養で疲れが抜けにくい(0.6倍)。', false),
  lonely('一匹狼', '友情タッグの経験点が減る(0.6倍)が、練習の伸びは1割増える。', false);

  const Trait(this.label, this.description, this.positive,
      [this.forRole = TraitFor.any]);
  final String label;
  final String description;

  /// 良い特性か(画面の色分けや、抽選の重みに使う)。
  final bool positive;

  /// 打者・投手のどちらに効く特性か(打者の特性は投手に意味が無いので、与えない)。
  final TraitFor forRole;

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

const maxTraits = 4;

/// 同時に持てない組み合わせ。
const _conflicts = <Trait, Trait>{
  Trait.lateBloomer: Trait.earlyBloomer,
  Trait.sturdy: Trait.glassBody,
  Trait.clutch: Trait.nervy,
  Trait.slugger: Trait.contactHitter,
  Trait.fireballer: Trait.finesse,
  Trait.quickRecovery: Trait.slowRecovery,
  Trait.moodMaker: Trait.lonely,
  Trait.sunny: Trait.moody,
};

/// 3つ以上の組み合わせではなく2つずつの矛盾のため、上の表だけでは足りないもの。
const _extraConflicts = <(Trait, Trait)>[
  (Trait.leader, Trait.lonely),
];

bool _conflict(Trait a, Trait b) =>
    _conflicts[a] == b ||
    _conflicts[b] == a ||
    _extraConflicts
        .any((c) => (c.$1 == a && c.$2 == b) || (c.$1 == b && c.$2 == a));

/// `t` を新しく持てるか(重複・矛盾・上限)。
bool canGain(Set<Trait> have, Trait t) =>
    !have.contains(t) &&
    have.length < maxTraits &&
    !have.any((h) => _conflict(h, t));

/// 持てるなら足した集合を、持てなければそのままを返す。
Set<Trait> gain(Set<Trait> have, Trait t) =>
    canGain(have, t) ? {...have, t} : have;

/// 生まれつきの出やすさ。最初の12個(成長・怪我・体調の基本の特性)は出やすく、
/// あとから増えた個性派は出にくい。良い特性は悪い特性の倍出る。
int _weight(Trait t) => (t.positive ? 2 : 1) * (t.index < 12 ? 6 : 1);

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

// ── 効き方。各システムはここだけを見る ──

/// 伸びる年(成長率 >= 0)の倍率。`age` は今の年齢。
double growthMultiplier(Set<Trait> t, int age) {
  var m = 1.0;
  if (t.contains(Trait.lateBloomer)) m *= age < 19 ? 0.7 : 1.4;
  if (t.contains(Trait.earlyBloomer)) m *= age < 16 ? 1.3 : 1.0;
  if (t.contains(Trait.hardWorker)) m *= 1.1;
  if (t.contains(Trait.genius)) m *= 1.2;
  if (t.contains(Trait.glassBody)) m *= 1.15;
  if (t.contains(Trait.lonely)) m *= 1.1;
  return m;
}

/// 衰える年(成長率 < 0)の倍率。大きいほど落ちる。
double declineMultiplier(Set<Trait> t) {
  var m = 1.0;
  if (t.contains(Trait.earlyBloomer)) m *= 1.3;
  if (t.contains(Trait.longevity)) m *= 0.6;
  return m;
}

double injuryMultiplier(Set<Trait> t) {
  var m = 1.0;
  if (t.contains(Trait.sturdy)) m *= 0.5;
  if (t.contains(Trait.glassBody)) m *= 1.8;
  return m;
}

/// 疲労の増え方(増えるときだけ。減るときは変えない)。
double fatigueMultiplier(Set<Trait> t) => t.contains(Trait.ironMan) ? 0.7 : 1.0;

/// 気持ちの上がり方 / 下がり方。
double moraleGainMultiplier(Set<Trait> t) =>
    (t.contains(Trait.sunny) ? 1.5 : 1.0) *
    (t.contains(Trait.moody) ? 1.3 : 1.0);
double moraleLossMultiplier(Set<Trait> t) =>
    (t.contains(Trait.sunny) ? 0.5 : 1.0) *
    (t.contains(Trait.moody) ? 1.3 : 1.0);

/// 大会の体調に足す値。
int tournamentBonus(Set<Trait> t) =>
    (t.contains(Trait.clutch) ? 10 : 0) - (t.contains(Trait.nervy) ? 10 : 0);

/// ドラフトの点数に足す値。
double draftBonus(Set<Trait> t) => t.contains(Trait.starPower) ? 5 : 0;

// ── 新しい特性の効き方 ──

/// 試合の間だけ効く能力の上乗せ(元の選手は変えない)。打者・投手の特性。
Map<Ability, int> traitAbilityDelta(Set<Trait> t) {
  final d = <Ability, int>{};
  void add(Ability a, int n) => d[a] = (d[a] ?? 0) + n;
  if (t.contains(Trait.slugger)) {
    add(Ability.power, 9);
    add(Ability.contact, -2);
  }
  if (t.contains(Trait.contactHitter)) {
    add(Ability.contact, 9);
    add(Ability.power, -2);
  }
  if (t.contains(Trait.patient)) {
    add(Ability.eye, 10);
    add(Ability.contact, 2);
  }
  if (t.contains(Trait.speedster)) add(Ability.speed, 8);
  if (t.contains(Trait.fireballer)) {
    add(Ability.stuff, 6);
    add(Ability.control, -4);
  }
  if (t.contains(Trait.finesse)) add(Ability.control, 8);
  if (t.contains(Trait.workhorse)) add(Ability.stamina, 8);
  return d;
}

/// 特性を反映した、試合用の選手。元の選手は変えない。
Player traitAdjusted(Player p) {
  final d = traitAbilityDelta(p.traits);
  if (d.isEmpty) return p;
  return p.copyWith(abilities: {
    for (final e in p.abilities.entries)
      e.key: (e.value + (d[e.key] ?? 0)).clamp(0, 99),
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

/// 「研究」で貯まる量の倍率。
double studyMultiplier(Set<Trait> t) => t.contains(Trait.studious) ? 1.4 : 1.0;

/// 世界大会の体調に足す値。
int worldBonus(Set<Trait> t) => t.contains(Trait.worldStage) ? 10 : 0;
