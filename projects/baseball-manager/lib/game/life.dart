import 'dart:math';

import 'player.dart';
import 'training.dart';
import 'traits.dart';

/// 1年は4つの季節。選択は季節ごとに行う。夏は大会の季節。
enum Term { spring, summer, autumn, winter }

/// 季節の過ごし方。
enum Action {
  train, // 練習: 重点を伸ばす
  special, // 特訓: 大きく伸びるが疲れて怪我しやすい
  rest, // 休養: 疲れを取る
  study, // 研究: 気持ちが乗り、重点が少し伸びる
  social, // 交流: 友人・家族と過ごして気持ちを上げる
  match; // 練習試合・遠征: 全体が少し伸びる

  /// 重点の能力が要るか。
  bool get needsFocus =>
      this == Action.train || this == Action.special || this == Action.study;
}

/// 年をまたいで持つ状態。能力と別に持つ(体調と気持ち)。
class Condition {
  const Condition({this.fatigue = 0, this.morale = 50, this.injuredTerms = 0});

  final int fatigue; // 疲労 0〜100
  final int morale; // 気持ち 0〜100
  final int injuredTerms; // 残りの怪我の季節数

  bool get injured => injuredTerms > 0;

  /// 体調 0〜100。大会の勝ちやすさに効く。怪我中は半分。
  int get value {
    final v = (morale * 0.5 + (100 - fatigue) * 0.5).round();
    return injured ? v ~/ 2 : v;
  }

  Condition copyWith({int? fatigue, int? morale, int? injuredTerms}) => Condition(
        fatigue: (fatigue ?? this.fatigue).clamp(0, 100),
        morale: (morale ?? this.morale).clamp(0, 100),
        injuredTerms: injuredTerms ?? this.injuredTerms,
      );

  Map<String, dynamic> toJson() =>
      {'fatigue': fatigue, 'morale': morale, 'injuredTerms': injuredTerms};

  /// 項目を足すときは既定値を置く。
  factory Condition.fromJson(Map<String, dynamic> j) => Condition(
        fatigue: (j['fatigue'] as num?)?.toInt() ?? 0,
        morale: (j['morale'] as num?)?.toInt() ?? 50,
        injuredTerms: (j['injuredTerms'] as num?)?.toInt() ?? 0,
      );
}

/// 季節ごとの効果: (伸びの倍率, 疲労の増減, 気持ちの増減)。
/// 倍率は「1年ぶんの伸び」に対する割合で、通常の練習が 0.25(=4季節で1年)。
({double scale, int fatigue, int morale}) effectOf(Action a) => switch (a) {
      Action.train => (scale: 0.25, fatigue: 15, morale: 0),
      Action.special => (scale: 0.45, fatigue: 35, morale: -5),
      Action.rest => (scale: 0.05, fatigue: -40, morale: 5),
      Action.study => (scale: 0.12, fatigue: 5, morale: 10),
      Action.social => (scale: 0.03, fatigue: -10, morale: 20),
      Action.match => (scale: 0.17, fatigue: 20, morale: 0),
    };

/// 怪我の確率。疲れているほど、特訓ほど高い。
double injuryChance(Condition c, Action a, [Set<Trait> traits = const {}]) =>
    (0.02 + c.fatigue / 100 * 0.15 + (a == Action.special ? 0.10 : 0.0)) *
    injuryMultiplier(traits);

/// 1季節の結果。
class TermResult {
  const TermResult(this.player, this.condition, {this.gotInjured = false});
  final Player player;
  final Condition condition;
  final bool gotInjured;
}

/// 1季節を過ごす。年齢は進めない(年の終わりに `endOfYear`)。
/// 怪我中は選択に関わらず安静になり、伸びない。
TermResult playTerm(
  Player p,
  Condition c,
  Action action,
  Ability focus,
  Random rng,
) {
  if (c.injured) {
    return TermResult(
      p,
      c.copyWith(fatigue: c.fatigue - 20, injuredTerms: c.injuredTerms - 1),
    );
  }
  final e = effectOf(action);
  final next = Map<Ability, int>.of(p.abilities);
  for (final a in abilitiesOf(p.role)) {
    // 練習試合は特定の能力に偏らない。
    final f = action == Action.match ? a : focus;
    final x = yearlyDelta(p, a, f) * e.scale;
    // 小さな値が毎回0に丸まらないよう、端数は確率で切り上げる。
    final whole = x.floor();
    final delta = whole + (rng.nextDouble() < x - whole ? 1 : 0);
    next[a] = (p.of(a) + delta).clamp(0, abilityCap);
  }
  final hurt = rng.nextDouble() < injuryChance(c, action, p.traits);
  final dFatigue = e.fatigue > 0
      ? (e.fatigue * fatigueMultiplier(p.traits)).round()
      : e.fatigue;
  final dMorale = e.morale > 0
      ? (e.morale * moraleGainMultiplier(p.traits)).round()
      : (e.morale * moraleLossMultiplier(p.traits)).round();
  return TermResult(
    p.copyWith(abilities: next),
    c.copyWith(
      fatigue: c.fatigue + dFatigue,
      morale: c.morale + dMorale,
      injuredTerms: hurt ? 1 + rng.nextInt(2) : 0,
    ),
    gotInjured: hurt,
  );
}

/// 年の終わり: 年齢が1つ進み、疲れが少し抜ける。
Player endOfYear(Player p) => p.copyWith(age: p.age + 1);
Condition endOfYearCondition(Condition c) => c.copyWith(fatigue: c.fatigue - 20);

// ── 季節の途中で起きる出来事(選択つき) ──

class EventChoice {
  const EventChoice(this.label, this.apply);
  final String label;

  /// 結果。能力・体調を返す。重点の能力 `focus` を使えるようにしてある。
  final ({Player player, Condition condition}) Function(
      Player p, Condition c, Ability focus) apply;
}

class GameEvent {
  const GameEvent(this.id, this.text, this.choices);
  final String id;
  final String text;
  final List<EventChoice> choices;
}

Player _gain(Player p, Ability a, int n) => p.copyWith(
      abilities: {...p.abilities, a: (p.of(a) + n).clamp(0, abilityCap)},
    );

final List<GameEvent> events = [
  GameEvent('coach', '名のあるコーチが声をかけてきた。', [
    EventChoice('弟子入りする', (p, c, f) =>
        (player: _gain(p, f, 3), condition: c.copyWith(fatigue: c.fatigue + 10))),
    EventChoice('今は断る', (p, c, f) =>
        (player: p, condition: c.copyWith(morale: c.morale + 5))),
  ]),
  GameEvent('rival', '同い年のライバルが現れた。', [
    EventChoice('意識して追いかける', (p, c, f) =>
        (player: _gain(p, f, 2), condition: c.copyWith(morale: c.morale - 5))),
    EventChoice('気にしない', (p, c, f) =>
        (player: p, condition: c.copyWith(morale: c.morale + 5))),
  ]),
  GameEvent('slump', 'スランプに入ってしまった。', [
    EventChoice('休んで立て直す', (p, c, f) => (
          player: p,
          condition: c.copyWith(fatigue: c.fatigue - 30, morale: c.morale + 5)
        )),
    EventChoice('練習で打開する', (p, c, f) => (
          player: _gain(p, f, 1),
          condition: c.copyWith(fatigue: c.fatigue + 15, morale: c.morale - 10)
        )),
  ]),
  GameEvent('winter-menu', '厳しい特別メニューを任された。', [
    EventChoice('やり抜く', (p, c, f) => (
          player: p.copyWith(traits: gain(p.traits, Trait.hardWorker)),
          condition: c.copyWith(fatigue: c.fatigue + 20)
        )),
    EventChoice('無理はしない', (p, c, f) =>
        (player: p, condition: c.copyWith(morale: c.morale + 5))),
  ]),
  GameEvent('friend', '友人が遊びに誘ってくれた。', [
    EventChoice('遊びに行く', (p, c, f) => (
          player: p,
          condition: c.copyWith(fatigue: c.fatigue - 10, morale: c.morale + 15)
        )),
    EventChoice('練習を優先する', (p, c, f) => (
          player: _gain(p, f, 1),
          condition: c.copyWith(fatigue: c.fatigue + 10)
        )),
  ]),
];

/// 出来事の起きる確率(1季節あたり)。
const eventChance = 0.4;

/// 今季の出来事。起きなければ null。
GameEvent? drawEvent(Random rng) =>
    rng.nextDouble() < eventChance ? events[rng.nextInt(events.length)] : null;
