import 'dart:math';

import 'career.dart';
import 'player.dart';
import 'traits.dart';

/// 季節ごとの過ごし方。
enum Action {
  practice('練習', '重点の能力をじっくり伸ばす。'),
  intense('特訓', '大きく伸びるが疲れて怪我もしやすい。'),
  rest('休養', '疲れを取り、気持ちを戻す。伸びない。'),
  study('研究', '映像を見て全体を少しずつ伸ばす。'),
  social('交流', '仲間と過ごして気持ちを上げる。'),
  scrimmage('練習試合', '全体が少し伸びる。疲れる。');

  const Action(this.label, this.description);
  final String label;
  final String description;

  /// 重点の能力を選ぶ過ごし方か。
  bool get usesFocus =>
      this == Action.practice || this == Action.intense || this == Action.study;
}

/// 体調。年をまたいで持ち、大会の動きに効く。
class Condition {
  const Condition({this.fatigue = 0, this.morale = 50, this.injuredTerms = 0});

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

  Condition copyWith({int? fatigue, int? morale, int? injuredTerms}) =>
      Condition(
        fatigue: (fatigue ?? this.fatigue).clamp(0, 100),
        morale: (morale ?? this.morale).clamp(0, 100),
        injuredTerms: max(0, injuredTerms ?? this.injuredTerms),
      );

  Map<String, dynamic> toJson() =>
      {'fatigue': fatigue, 'morale': morale, 'injuredTerms': injuredTerms};

  factory Condition.fromJson(Map<String, dynamic>? j) => Condition(
        fatigue: (j?['fatigue'] as num?)?.toInt() ?? 0,
        morale: (j?['morale'] as num?)?.toInt() ?? 50,
        injuredTerms: (j?['injuredTerms'] as num?)?.toInt() ?? 0,
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
    return 3.9 * g * talent * share * growthMultiplier(p.traits, p.age);
  }
  final aging = switch (a) {
    Ability.speed || Ability.stamina || Ability.physical => 1.5,
    _ => 1.0,
  };
  return 3.0 * g * (a == focus ? 0.5 : 1.0) * aging * declineMultiplier(p.traits);
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
        (focus: 1.0, other: 1.0, fatigue: 10, morale: -2, injury: 0.03),
      Action.intense =>
        (focus: 1.8, other: 1.0, fatigue: 25, morale: -5, injury: 0.12),
      Action.rest => (focus: 0.0, other: 0.0, fatigue: -35, morale: 5, injury: 0),
      Action.study =>
        (focus: 0.8, other: 1.6, fatigue: 5, morale: 2, injury: 0.01),
      Action.social =>
        (focus: 0.3, other: 1.2, fatigue: -10, morale: 15, injury: 0),
      Action.scrimmage =>
        (focus: 0.6, other: 2.4, fatigue: 15, morale: 3, injury: 0.05),
    };

/// 1ターン進める。年齢と身長はここでは動かさない(年末に `ageUp`)。
({Player player, Condition condition, bool gotInjured}) playTerm(
  Player p,
  Condition c,
  Action action,
  Ability focus,
  Random rng,
) {
  if (!canChoose(action, c)) {
    throw StateError('怪我中に選べない過ごし方: $action');
  }
  final e = _effect(action);
  final tired = c.fatigue >= 70 ? 0.7 : 1.0;
  final mood = 0.85 + c.morale / 333; // 0.85〜1.15
  final next = Map<Ability, int>.of(p.abilities);
  if (!c.injured) {
    for (final a in Ability.values) {
      final mult = a == focus ? e.focus : e.other;
      final yearly = yearlyDelta(p, a, focus);
      // 伸びない過ごし方(休養)は、伸びる年には何も動かさない。衰えは止まらない。
      if (mult == 0 && yearly >= 0) continue;
      final base = yearly / 4 * (yearly < 0 ? 1.0 : mult);
      final scaled = base >= 0 ? base * tired * mood : base;
      final noise = (rng.nextDouble() - 0.5) * 0.6;
      next[a] = (p.of(a) + _stochasticRound(scaled + noise, rng))
          .clamp(0, abilityCap);
    }
  }

  var fatigue = c.fatigue;
  final df = e.fatigue;
  fatigue += df > 0 ? (df * fatigueMultiplier(p.traits)).round() : df;
  var morale = c.morale;
  final dm = e.morale;
  morale += dm > 0
      ? (dm * moraleGainMultiplier(p.traits)).round()
      : (dm * moraleLossMultiplier(p.traits)).round();

  var injured = max(0, c.injuredTerms - 1);
  var gotInjured = false;
  if (!c.injured) {
    final risk = e.injury *
        injuryMultiplier(p.traits) *
        (c.fatigue >= 70 ? 2.0 : 1.0);
    if (rng.nextDouble() < risk) {
      injured = 1 + rng.nextInt(3);
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
    ),
    gotInjured: gotInjured,
  );
}

/// 年末: 年齢を1つ上げ、身長を伸ばす。
Player ageUp(Player p, Random rng) {
  final growth = heightGrowthPerYear(p.age, p.heightGenes);
  final noise = growth > 0 ? (rng.nextDouble() - 0.5) * 1.2 : 0.0;
  return p.copyWith(
    age: p.age + 1,
    heightCm: p.heightCm + max(0.0, growth + noise),
  );
}
