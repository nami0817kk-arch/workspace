import 'dart:math';

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
  longevity('長持ち', '衰えがゆるやか。', true);

  const Trait(this.label, this.description, this.positive);
  final String label;
  final String description;

  /// 良い特性か(画面の色分けや、抽選の重みに使う)。
  final bool positive;

  static Trait? parse(String s) {
    for (final t in Trait.values) {
      if (t.name == s) return t;
    }
    return null;
  }
}

const maxTraits = 4;

/// 同時に持てない組み合わせ。
const _conflicts = <Trait, Trait>{
  Trait.lateBloomer: Trait.earlyBloomer,
  Trait.sturdy: Trait.glassBody,
  Trait.clutch: Trait.nervy,
};

bool _conflict(Trait a, Trait b) =>
    _conflicts[a] == b || _conflicts[b] == a;

/// `t` を新しく持てるか(重複・矛盾・上限)。
bool canGain(Set<Trait> have, Trait t) =>
    !have.contains(t) &&
    have.length < maxTraits &&
    !have.any((h) => _conflict(h, t));

/// 持てるなら足した集合を、持てなければそのままを返す。
Set<Trait> gain(Set<Trait> have, Trait t) =>
    canGain(have, t) ? {...have, t} : have;

/// 生まれつきの特性。0〜2個。良い特性が出やすい(悪いものは半分)。
Set<Trait> rollInnateTraits(Random rng) {
  final r = rng.nextDouble();
  final n = r < 0.35 ? 0 : (r < 0.80 ? 1 : 2);
  var have = <Trait>{};
  for (var i = 0; i < n; i++) {
    final pool = [
      for (final t in Trait.values)
        if (canGain(have, t)) ...List.filled(t.positive ? 2 : 1, t),
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
double moraleGainMultiplier(Set<Trait> t) => t.contains(Trait.sunny) ? 1.5 : 1.0;
double moraleLossMultiplier(Set<Trait> t) => t.contains(Trait.sunny) ? 0.5 : 1.0;

/// 大会の体調に足す値。
int tournamentBonus(Set<Trait> t) =>
    (t.contains(Trait.clutch) ? 10 : 0) - (t.contains(Trait.nervy) ? 10 : 0);

/// ドラフトの点数に足す値。
double draftBonus(Set<Trait> t) => t.contains(Trait.starPower) ? 5 : 0;
