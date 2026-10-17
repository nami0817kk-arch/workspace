import 'dart:math';

import 'player.dart';
import 'characters.dart';
import 'career.dart';
import 'exp.dart';
import 'training.dart';
import 'traits.dart';

/// 1年は4つの季節。選択は季節ごとに行う。夏は大会の季節。
enum Term { spring, summer, autumn, winter }

/// 季節の過ごし方。
enum Plan {
  train, // 練習: 重点を伸ばす
  special, // 特訓: 大きく伸びるが疲れて怪我しやすい
  rest, // 休養: 疲れを取る
  study, // 研究: 気持ちが乗り、重点が少し伸びる
  social, // 交流: 友人・家族と過ごして気持ちを上げる
  match, // 練習試合・遠征: 全体が少し伸びる
  lesson; // コーチに教わる: 少し伸び、コツが貯まる(貯まると特性を習得)

  /// 重点の能力が要るか。
  bool get needsFocus =>
      this == Plan.train ||
      this == Plan.special ||
      this == Plan.study ||
      this == Plan.lesson;
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

  Condition copyWith({int? fatigue, int? morale, int? injuredTerms}) =>
      Condition(
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
({double scale, int fatigue, int morale}) effectOf(Plan a) => switch (a) {
      Plan.train => (scale: 0.25, fatigue: 15, morale: 0),
      Plan.special => (scale: 0.45, fatigue: 35, morale: -5),
      Plan.rest => (scale: 0.05, fatigue: -40, morale: 5),
      Plan.study => (scale: 0.12, fatigue: 5, morale: 10),
      Plan.social => (scale: 0.03, fatigue: -10, morale: 20),
      Plan.match => (scale: 0.17, fatigue: 20, morale: 0),
      Plan.lesson => (scale: 0.15, fatigue: 12, morale: 0),
    };

/// 怪我の確率。疲れているほど、特訓ほど高い。
double injuryChance(Condition c, Plan a, [Set<Trait> traits = const {}]) =>
    (0.02 + c.fatigue / 100 * 0.15 + (a == Plan.special ? 0.10 : 0.0)) *
    injuryMultiplier(traits);

/// 1ターンの結果。能力は直接は上がらず、経験点が貯まる(衰える年だけ能力が直接下がる)。
class TermResult {
  const TermResult(this.player, this.condition,
      {this.gotInjured = false, this.exp = const {}});
  final Player player;
  final Condition condition;
  final bool gotInjured;

  /// 今回貯まった経験点(種類ごと)。やる気の倍率はかけてある。
  final Map<Category, int> exp;
}

/// 1ターンを過ごす。年齢は進めない(年の終わりに `endOfYear`)。
/// `share` は季節に対する割合(月単位なら 1/3)。効果・疲労・怪我がその分小さくなる。
/// 怪我中は選択に関わらず安静になり、経験点は貯まらない。
TermResult playTerm(
  Player p,
  Condition c,
  Plan action,
  Ability focus,
  Random rng, {
  double share = 1.0,
}) {
  if (c.injured) {
    return TermResult(
      p,
      c.copyWith(
          fatigue: c.fatigue - (20 * share).round(),
          injuredTerms: c.injuredTerms - 1),
    );
  }
  final e = effectOf(action);
  final motiv = motivationOf(c.morale).expMultiplier;
  final next = Map<Ability, int>.of(p.abilities);
  final gained = <Category, int>{};
  for (final a in abilitiesOf(p.role)) {
    // 練習試合は特定の能力に偏らない。
    final f = action == Plan.match ? a : focus;
    final x = yearlyDelta(p, a, f) * e.scale * share;
    if (x >= 0) {
      final cat = categoryOf(a);
      gained[cat] = (gained[cat] ?? 0) +
          (x * expPerPoint * motiv * roleExpFactor(p.role)).round();
    } else {
      // 衰えは経験点を通さず直接下がる。端数は確率で切り上げる。
      final whole = x.truncate();
      final delta = whole + (rng.nextDouble() < (whole - x) ? -1 : 0);
      next[a] = (p.of(a) + delta).clamp(0, abilityCap);
    }
  }
  final hurt = rng.nextDouble() < injuryChance(c, action, p.traits) * share;
  final dFatigue = e.fatigue > 0
      ? (e.fatigue * fatigueMultiplier(p.traits) * share).round()
      : (e.fatigue * share).round();
  final dMorale = e.morale > 0
      ? (e.morale * moraleGainMultiplier(p.traits) * share).round()
      : (e.morale * moraleLossMultiplier(p.traits) * share).round();
  return TermResult(
    p.copyWith(abilities: next),
    c.copyWith(
      fatigue: c.fatigue + dFatigue,
      morale: c.morale + dMorale,
      injuredTerms: hurt ? 1 + rng.nextInt(2) : 0,
    ),
    gotInjured: hurt,
    exp: gained,
  );
}

/// 年の終わり: 年齢が1つ進み、疲れが少し抜ける。
Player endOfYear(Player p) => p.copyWith(age: p.age + 1);
Condition endOfYearCondition(Condition c) =>
    c.copyWith(fatigue: c.fatigue - 20);

// ── 季節の途中で起きる出来事(選択つき) ──

class EventChoice {
  const EventChoice(this.label, this.apply, [this.onCast]);
  final String label;

  /// 登場人物への影響(絆・コツなど)。選んだ後に呼ばれる。
  final void Function(Cast cast, Random rng)? onCast;

  /// 結果。能力・体調を返す。重点の能力 `focus` を使えるようにしてある。
  final ({Player player, Condition condition}) Function(
      Player p, Condition c, Ability focus) apply;
}

class GameEvent {
  const GameEvent(this.id, this.text, this.choices, {this.when});
  final String id;
  final String text;
  final List<EventChoice> choices;

  /// 起きる条件。省略なら誰にでも起きうる。
  final bool Function(Stage stage, Cast cast)? when;
}

Player _gain(Player p, Ability a, int n) => p.copyWith(
      abilities: {...p.abilities, a: (p.of(a) + n).clamp(0, abilityCap)},
    );

final List<GameEvent> events = [
  GameEvent('coach', '名のあるコーチが声をかけてきた。', [
    EventChoice(
        '弟子入りする',
        (p, c, f) => (
              player: _gain(p, f, 3),
              condition: c.copyWith(fatigue: c.fatigue + 10)
            )),
    EventChoice('今は断る',
        (p, c, f) => (player: p, condition: c.copyWith(morale: c.morale + 5))),
  ]),
  GameEvent('rival', '同い年のライバルが現れた。', [
    EventChoice(
        '意識して追いかける',
        (p, c, f) => (
              player: _gain(p, f, 2),
              condition: c.copyWith(morale: c.morale - 5)
            )),
    EventChoice('気にしない',
        (p, c, f) => (player: p, condition: c.copyWith(morale: c.morale + 5))),
  ]),
  GameEvent('slump', 'スランプに入ってしまった。', [
    EventChoice(
        '休んで立て直す',
        (p, c, f) => (
              player: p,
              condition:
                  c.copyWith(fatigue: c.fatigue - 30, morale: c.morale + 5)
            )),
    EventChoice(
        '練習で打開する',
        (p, c, f) => (
              player: _gain(p, f, 1),
              condition:
                  c.copyWith(fatigue: c.fatigue + 15, morale: c.morale - 10)
            )),
  ]),
  GameEvent('winter-menu', '厳しい特別メニューを任された。', [
    EventChoice(
        'やり抜く',
        (p, c, f) => (
              player: p.copyWith(traits: gain(p.traits, Trait.hardWorker)),
              condition: c.copyWith(fatigue: c.fatigue + 20)
            )),
    EventChoice('無理はしない',
        (p, c, f) => (player: p, condition: c.copyWith(morale: c.morale + 5))),
  ]),
  GameEvent(
      'date',
      '恋人からデートに誘われた。',
      [
        EventChoice(
          '行く',
          (p, c, f) => (
            player: p,
            condition:
                c.copyWith(fatigue: c.fatigue - 10, morale: c.morale + 15)
          ),
          (cast, rng) => cast.lover?.addBond(12),
        ),
        EventChoice(
          '練習があるから断る',
          (p, c, f) => (player: p, condition: c.copyWith(morale: c.morale - 3)),
          (cast, rng) => cast.lover?.addBond(-6),
        ),
      ],
      when: (stage, cast) => cast.lover != null),
  GameEvent(
      'family',
      '母がお弁当を作って待っていた。',
      [
        EventChoice(
          '感謝して食べる',
          (p, c, f) =>
              (player: p, condition: c.copyWith(morale: c.morale + 10)),
          (cast, rng) => cast.family?.addBond(10),
        ),
        EventChoice(
          '急いで練習へ向かう',
          (p, c, f) =>
              (player: p, condition: c.copyWith(fatigue: c.fatigue + 5)),
          (cast, rng) => cast.family?.addBond(-3),
        ),
      ],
      when: (stage, cast) => cast.family != null),
  GameEvent(
      'rival-talk',
      'ライバルが勝負を挑んできた。',
      [
        EventChoice(
          '受けて立つ',
          (p, c, f) => (
            player: _gain(p, f, 1),
            condition: c.copyWith(fatigue: c.fatigue + 10)
          ),
          (cast, rng) => cast.rival?.addBond(8),
        ),
        EventChoice(
          '今は断る',
          (p, c, f) => (player: p, condition: c.copyWith(morale: c.morale - 3)),
        ),
      ],
      when: (stage, cast) => cast.rival != null),
  GameEvent(
      'coach-extra',
      'コーチが居残り練習に付き合ってくれると言う。',
      [
        EventChoice(
          '居残りする',
          (p, c, f) =>
              (player: p, condition: c.copyWith(fatigue: c.fatigue + 15)),
          (cast, rng) => cast.coach?.tips += 1,
        ),
        EventChoice(
          '今日は帰る',
          (p, c, f) => (player: p, condition: c.copyWith(morale: c.morale + 3)),
        ),
      ],
      when: (stage, cast) => cast.coach != null),
  GameEvent(
      'mate-invite',
      '仲間が一緒に練習しようと誘ってきた。',
      [
        EventChoice(
          '一緒にやる',
          (p, c, f) => (
            player: p,
            condition: c.copyWith(fatigue: c.fatigue + 8, morale: c.morale + 5)
          ),
          (cast, rng) {
            for (final m in cast.teammates) {
              m.addBond(4);
            }
          },
        ),
        EventChoice(
          'ひとりで集中する',
          (p, c, f) => (player: _gain(p, f, 1), condition: c),
          (cast, rng) {
            for (final m in cast.teammates) {
              m.addBond(-2);
            }
          },
        ),
      ],
      when: (stage, cast) => cast.teammates.isNotEmpty),
  GameEvent('friend', '友人が遊びに誘ってくれた。', [
    EventChoice(
        '遊びに行く',
        (p, c, f) => (
              player: p,
              condition:
                  c.copyWith(fatigue: c.fatigue - 10, morale: c.morale + 15)
            )),
    EventChoice(
        '練習を優先する',
        (p, c, f) => (
              player: _gain(p, f, 1),
              condition: c.copyWith(fatigue: c.fatigue + 10)
            )),
  ]),
];

/// 出来事の起きる確率(1季節あたり)。
const eventChance = 0.4;

/// 今季の出来事。起きなければ null。
/// `stage` と `cast` を渡すと、条件のある出来事(恋人・ライバルなど)も候補に入る。
GameEvent? drawEvent(Random rng,
    {double share = 1.0, Stage? stage, Cast? cast}) {
  if (rng.nextDouble() >= eventChance * share) return null;
  final pool = [
    for (final e in events)
      if (e.when == null ||
          (stage != null && cast != null && e.when!(stage, cast)))
        e,
  ];
  return pool[rng.nextInt(pool.length)];
}
