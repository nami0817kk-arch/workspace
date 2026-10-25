import 'dart:math';

import 'career.dart';
import 'build.dart';
import 'player.dart';
import 'special.dart';
import 'traits.dart';

/// 季節ごとの過ごし方。
enum Action {
  practice('練習', '重点の能力をじっくり伸ばす。'),
  intense('特訓', '大きく伸びるが疲れて怪我もしやすい。'),
  rest('休養', '疲れを取り、気持ちを戻す。伸びない。'),
  study('研究', '映像を見て全体を少しずつ伸ばす。大会の前なら相手の分析にもなる。'),
  social('交流', '仲間と過ごして気持ちを上げる。チームワークが大きく上がる。'),
  scrimmage('練習試合', '全体が少し伸びる。疲れる。チームワークが少し上がる。');

  const Action(this.label, this.description);
  final String label;
  final String description;

  /// 重点の能力を選ぶ過ごし方か。
  bool get usesFocus =>
      this == Action.practice || this == Action.intense || this == Action.study;
}

/// 体調。年をまたいで持ち、大会の動きに効く。
/// 怪我の種類。重いほど長く休み、大怪我は後に響く(スピードとフィジカルが落ちる)。
enum Injury {
  sprain('捻挫', 1, 2, 60),
  strain('肉離れ', 2, 3, 32),
  fracture('骨折', 4, 6, 8);

  const Injury(this.label, this.minTerms, this.maxTerms, this.weight);
  final String label;
  final int minTerms;
  final int maxTerms;
  final int weight;

  /// 後遺症があるか(大怪我だけ)。
  bool get lasting => this == Injury.fracture;

  int terms(Random rng) => minTerms + rng.nextInt(maxTerms - minTerms + 1);
}

/// 怪我の種類を引く(軽い怪我ほど起きやすい)。
Injury rollInjury(Random rng) {
  var x = rng.nextInt(Injury.values.fold(0, (s, i) => s + i.weight));
  for (final i in Injury.values) {
    x -= i.weight;
    if (x < 0) return i;
  }
  return Injury.sprain;
}

/// 大怪我の後遺症: スピードとフィジカルが少し落ちる。
Map<Ability, int> applyLastingInjury(Map<Ability, int> abilities) {
  final next = Map<Ability, int>.of(abilities);
  for (final a in [Ability.speed, Ability.physical]) {
    next[a] = ((next[a] ?? 0) - 3).clamp(0, abilityCap);
  }
  return next;
}

class Condition {
  const Condition(
      {this.fatigue = 0,
      this.morale = 50,
      this.injuredTerms = 0,
      this.injuryName = ''});

  /// いまの怪我の名前(健康なら空)。
  final String injuryName;

  /// 疲労 0〜100(高いほど悪い)。
  final int fatigue;

  /// 気持ち 0〜100。
  final int morale;

  /// 怪我が治るまでの残りターン。0 なら健康。
  final int injuredTerms;

  bool get injured => injuredTerms > 0;

  /// 試合での動きの良さ(0.6〜1.2)。疲労が高いと落ち、気持ちが高いと上がる。
  double get form {
    final f = 1.0 - fatigue / 250 + (morale - 50) / 400;
    return (injured ? f * 0.6 : f).clamp(0.5, 1.2);
  }

  Condition copyWith(
      {int? fatigue, int? morale, int? injuredTerms, String? injuryName}) {
    final terms = max(0, injuredTerms ?? this.injuredTerms);
    return Condition(
      fatigue: (fatigue ?? this.fatigue).clamp(0, 100),
      morale: (morale ?? this.morale).clamp(0, 100),
      injuredTerms: terms,
      injuryName: terms == 0 ? '' : (injuryName ?? this.injuryName),
    );
  }

  Map<String, dynamic> toJson() => {
        'fatigue': fatigue,
        'morale': morale,
        'injuredTerms': injuredTerms,
        'injuryName': injuryName,
      };

  factory Condition.fromJson(Map<String, dynamic>? j) => Condition(
        fatigue: (j?['fatigue'] as num?)?.toInt() ?? 0,
        morale: (j?['morale'] as num?)?.toInt() ?? 50,
        injuredTerms: (j?['injuredTerms'] as num?)?.toInt() ?? 0,
        injuryName: (j?['injuryName'] as String?) ?? '',
      );
}

/// 1ターン(季節)で選べる過ごし方か。怪我中は特訓と練習試合ができない。
bool canChoose(Action a, Condition c) =>
    !(c.injured && (a == Action.intense || a == Action.scrimmage));

/// 能力 `a` が1年で動く量(ノイズ抜き)。1ターンはこれの4分の1を基準に使う。
/// 伸びる年は素質が効き、下る年は重点を置いた能力が落ちにくい。
double yearlyDelta(Player p, Ability a, Ability focus) {
  final g = growthFactor(p.age);
  final talent = 0.5 + p.potential / 100; // 0.5〜1.5
  final share = a == focus ? 1.0 : 0.25;
  if (g >= 0) {
    return 5.2 *
        g *
        talent *
        share *
        growthMultiplier(p.traits, p.age) *
        abilityGrowthMultiplier(p.traits, a) *
        styleGrowthMultiplier(p.style, a) *
        specialGrowthMultiplier(p.specials, a);
  }
  final aging = switch (a) {
    Ability.speed || Ability.stamina || Ability.physical => 1.5,
    _ => 1.0,
  };
  return 3.0 *
      g *
      (a == focus ? 0.5 : 1.0) *
      aging *
      declineMultiplier(p.traits) *
      specialDeclineMultiplier(p.specials);
}

/// 今の重点のおすすめ。ポジションに効く能力のうち、伸びしろ(重み × (100 − 今の値))が最も大きいもの。
Ability recommendedFocus(Player p) {
  final w = weightsOf(p.position);
  return w.keys.reduce((a, b) =>
      w[a]! * (100 - p.of(a)) >= w[b]! * (100 - p.of(b)) ? a : b);
}

/// 小数を確率で丸める(期待値が保たれる)。小さな伸びが消えないようにする。
int _stochasticRound(double v, Random rng) {
  final f = v.floor();
  return f + (rng.nextDouble() < v - f ? 1 : 0);
}

/// 過ごし方ごとの (重点の倍率, 重点以外の倍率, 疲労, 気持ち, 怪我の確率)。
({double focus, double other, int fatigue, int morale, double injury}) _effect(
        Action a) =>
    switch (a) {
      Action.practice =>
        (focus: 1.2, other: 0.6, fatigue: 10, morale: -2, injury: 0.03),
      Action.intense =>
        (focus: 2.2, other: 0.8, fatigue: 25, morale: -5, injury: 0.12),
      Action.rest => (focus: 0.0, other: 0.0, fatigue: -35, morale: 5, injury: 0),
      Action.study =>
        (focus: 0.6, other: 0.9, fatigue: 5, morale: 2, injury: 0.01),
      Action.social =>
        (focus: 0.2, other: 0.4, fatigue: -10, morale: 15, injury: 0),
      Action.scrimmage =>
        (focus: 0.5, other: 1.0, fatigue: 15, morale: 3, injury: 0.05),
    };

/// 1ターン進める。年齢と身長はここでは動かさない(年末に `ageUp`)。
({Player player, Condition condition, bool gotInjured}) playTerm(
  Player p,
  Condition c,
  Action action,
  Ability focus,
  Random rng, {
  double growthScale = 1.0,
}) {
  if (!canChoose(action, c)) {
    throw StateError('怪我中に選べない過ごし方: $action');
  }
  final e = _effect(action);
  final tired = c.fatigue >= 70 ? 0.7 : 1.0;
  final mood = 0.85 + c.morale / 333; // 0.85〜1.15
  var next = Map<Ability, int>.of(p.abilities);
  if (!c.injured) {
    for (final a in Ability.values) {
      final mult = a == focus ? e.focus : e.other;
      final yearly = yearlyDelta(p, a, focus);
      // 伸びない過ごし方(休養)は、伸びる年には何も動かさない。衰えは止まらない。
      if (mult == 0 && yearly >= 0) continue;
      final base = yearly / 4 * (yearly < 0 ? 1.0 : mult);
      final scaled = base >= 0 ? base * tired * mood * growthScale : base;
      final noise = (rng.nextDouble() - 0.5) * 0.6;
      next[a] = (p.of(a) + _stochasticRound(scaled + noise, rng))
          .clamp(0, abilityCap);
    }
  }

  var fatigue = c.fatigue;
  final df = e.fatigue;
  fatigue += df > 0
      ? (df * fatigueMultiplier(p.traits)).round()
      : (df * specialRecoveryMultiplier(p.specials)).round();
  var morale = c.morale;
  final dm = e.morale;
  morale += dm > 0
      ? (dm * moraleGainMultiplier(p.traits) * specialMoraleGainMultiplier(p.specials))
          .round()
      : (dm * moraleLossMultiplier(p.traits) * specialMoraleLossMultiplier(p.specials))
          .round();

  var injured = max(0, c.injuredTerms - 1);
  var injuryName = c.injuryName;
  var gotInjured = false;
  if (!c.injured) {
    final risk = e.injury *
        injuryMultiplier(p.traits) *
        specialInjuryMultiplier(p.specials) *
        (c.fatigue >= 70 ? 2.0 : 1.0);
    if (rng.nextDouble() < risk) {
      final kind = rollInjury(rng);
      injured = kind.terms(rng);
      injuryName = kind.label;
      if (kind.lasting) next = applyLastingInjury(next);
      gotInjured = true;
      morale -= 10;
    }
  }

  return (
    player: p.copyWith(abilities: next),
    condition: Condition(fatigue: 0, morale: 50).copyWith(
      fatigue: fatigue,
      morale: morale,
      injuredTerms: injured,
      injuryName: injuryName,
    ),
    gotInjured: gotInjured,
  );
}

/// 生活習慣の「ふつう」の水準。ふつうに遊んでいるとここに落ち着き、身長の伸びは基準どおり。
const habitBaseline = 4.5;

/// 1ターンの過ごし方が生活習慣(-10〜+10)に与える点。幼少期(17歳まで)だけ。
/// 休養=よく眠る(+0.4)、交流=外で遊ぶ(+0.1)。疲れ切るまでの特訓や、疲れが溜まったまま(70以上)は睡眠不足で乱れる。
double habitDelta(Action a, int fatigue) {
  var d = switch (a) {
    Action.rest => 0.4,
    Action.social => 0.1,
    Action.practice || Action.scrimmage || Action.study => 0.0,
    Action.intense => fatigue >= 60 ? -0.3 : 0.0,
  };
  if (fatigue >= 70) d -= 0.3;
  return d;
}

/// 生活習慣が身長の伸びに与える倍率。「ふつう(+4.5)」で1倍、良い(+10)で約1.05倍、乱れ(-10)で約0.92倍。
/// 最終身長で、良いと+3.5cm・乱れると-5cm くらい(基準から離れるほど効くが、悪い側のほうが緩やか)。
double habitHeightMultiplier(double habit) {
  final d = habit.clamp(-10, 10) - habitBaseline;
  return 1 + d * (d >= 0 ? 0.0095 : 0.0055);
}

/// 年末: 年齢を1つ上げ、身長を伸ばす。`habit` は幼少期の生活習慣(-10〜+10)。
Player ageUp(Player p, Random rng, {double habit = 0}) {
  final growth = heightGrowthPerYear(p.age, p.heightGenes) *
      (p.age <= 17 ? habitHeightMultiplier(habit) : 1.0);
  final noise = growth > 0 ? (rng.nextDouble() - 0.5) * 1.2 : 0.0;
  return p.copyWith(
    age: p.age + 1,
    heightCm: p.heightCm + max(0.0, growth + noise),
  );
}
