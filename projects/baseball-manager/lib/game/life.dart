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

/// 練習の出来。同じ練習でも、うまくいく日と失敗する日がある。
enum Outcome {
  bad('失敗', 0.4),
  normal('', 1.0),
  good('好調', 1.25),
  great('大成功', 1.8);

  const Outcome(this.label, this.multiplier);
  final String label;

  /// 貯まる経験点にかかる倍率。
  final double multiplier;
}

/// 出来が決まる過ごし方(練習・特訓・練習試合・コーチ)。休養・交流・研究は毎回ふつう。
bool hasOutcome(Plan a) =>
    a == Plan.train || a == Plan.special || a == Plan.match || a == Plan.lesson;

/// 出来を決める。特訓は振れ幅が大きい(失敗も大成功も多い)。
/// 平均の倍率は1.0前後になるようにしてある(全体のバランスは変えない)。
Outcome rollOutcome(Plan a, Random rng) {
  if (!hasOutcome(a)) return Outcome.normal;
  final r = rng.nextDouble();
  final bad = a == Plan.special ? 0.20 : 0.12;
  final great = a == Plan.special ? 0.10 : 0.08;
  final good = 0.20;
  if (r < bad) return Outcome.bad;
  if (r < bad + great) return Outcome.great;
  if (r < bad + great + good) return Outcome.good;
  return Outcome.normal;
}

/// 1ターンの結果。能力は直接は上がらず、経験点が貯まる(衰える年だけ能力が直接下がる)。
class TermResult {
  const TermResult(this.player, this.condition,
      {this.gotInjured = false,
      this.exp = const {},
      this.outcome = Outcome.normal});
  final Player player;
  final Condition condition;
  final bool gotInjured;

  /// 今回貯まった経験点(種類ごと)。やる気と出来の倍率はかけてある。
  final Map<Category, int> exp;

  /// 今回の出来(失敗・好調・大成功など)。
  final Outcome outcome;
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
  final outcome = rollOutcome(action, rng);
  final motiv = motivationOf(c.morale).expMultiplier * outcome.multiplier;
  final next = Map<Ability, int>.of(p.abilities);
  final gained = <Category, int>{};
  for (final a in abilitiesOf(p.role)) {
    // 練習試合は特定の能力に偏らない。
    final f = action == Plan.match ? a : focus;
    final x = yearlyDelta(p, a, f) *
        e.scale *
        share *
        (action == Plan.study ? studyMultiplier(p.traits) : 1.0);
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
  // 失敗した日は怪我もしやすい。
  final hurt = rng.nextDouble() <
      injuryChance(c, action, p.traits) *
          share *
          (outcome == Outcome.bad ? 1.5 : 1.0);
  final dFatigue = e.fatigue > 0
      ? (e.fatigue * fatigueMultiplier(p.traits) * share).round()
      : (e.fatigue * recoveryMultiplier(p.traits) * share).round();
  var dMorale = e.morale > 0
      ? (e.morale * moraleGainMultiplier(p.traits) * share).round()
      : (e.morale * moraleLossMultiplier(p.traits) * share).round();
  // 大成功は気持ちが上がり、失敗は疲れが増える。
  if (outcome == Outcome.great) dMorale += (6 * share).round();
  final extraFatigue = outcome == Outcome.bad ? (6 * share).round() : 0;
  return TermResult(
    p.copyWith(abilities: next),
    c.copyWith(
      fatigue: c.fatigue + dFatigue + extraFatigue,
      morale: c.morale + dMorale,
      injuredTerms: hurt ? 1 + rng.nextInt(2) : 0,
    ),
    gotInjured: hurt,
    exp: gained,
    outcome: outcome,
  );
}

/// 年の終わり: 年齢が1つ進み、疲れが少し抜ける。
Player endOfYear(Player p) => p.copyWith(age: p.age + 1);
Condition endOfYearCondition(Condition c) =>
    c.copyWith(fatigue: c.fatigue - 20);

// ── 季節の途中で起きる出来事(選択つき) ──

/// 出来事の結果(選手と体調)。
typedef EventResult = ({Player player, Condition condition});

/// 運が絡む出来事の結果。`rng` で成功か失敗かが決まる。
typedef RiskyApply = EventResult Function(
    Player p, Condition c, Ability focus, Random rng);

class EventChoice {
  const EventChoice(this.label, this.apply, [this.onCast]) : risky = null;

  /// 運しだいの選択肢。結果は `risky` が乱数で決める(`apply` は乱数を固定した見本)。
  EventChoice.risky(this.label, RiskyApply fn, [this.onCast])
      : risky = fn,
        apply = ((p, c, f) => fn(p, c, f, Random(0)));

  final String label;

  /// 運しだいなら、その結果を決める関数。普通の選択肢は null。
  final RiskyApply? risky;

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

Player _gain(Player p, Ability a, int n) {
  // 役割に無い能力(打者の球威など)は増やさない。
  if (!abilitiesOf(p.role).contains(a)) return p;
  return p.copyWith(
    abilities: {...p.abilities, a: (p.of(a) + n).clamp(0, abilityCap)},
  );
}

/// 体が大きくなったときの伸び。役割に合う能力が育つ。
Player _growthSpurt(Player p) => switch (p.role) {
      Role.batter => _gain(_gain(p, Ability.power, 2), Ability.speed, 1),
      Role.pitcher => _gain(_gain(p, Ability.stamina, 2), Ability.stuff, 1),
      Role.twoWay => _gain(_gain(p, Ability.power, 2), Ability.stamina, 1),
    };

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
  // ── 追加の出来事 ──
  GameEvent(
      'dad-catch',
      '父がキャッチボールに誘ってきた。',
      [
        EventChoice(
          '付き合う',
          (p, c, f) => (
            player: _gain(p, f, 1),
            condition: c.copyWith(morale: c.morale + 8)
          ),
          (cast, rng) => cast.family?.addBond(10),
        ),
        EventChoice(
          '友達と遊ぶ',
          (p, c, f) => (
            player: p,
            condition: c.copyWith(morale: c.morale + 6, fatigue: c.fatigue - 5)
          ),
        ),
      ],
      when: (stage, cast) =>
          (stage == Stage.youth || stage == Stage.juniorHigh) &&
          cast.family != null),
  GameEvent(
      'growth-spurt',
      '急に背が伸びてきた。',
      [
        EventChoice(
          '体をたくさん動かす',
          (p, c, f) => (
            player: _growthSpurt(p),
            condition: c.copyWith(fatigue: c.fatigue + 10)
          ),
        ),
        EventChoice(
          '休んで体を作る',
          (p, c, f) => (
            player: p,
            condition: c.copyWith(fatigue: c.fatigue - 15, morale: c.morale + 3)
          ),
        ),
      ],
      when: (stage, cast) => stage == Stage.youth || stage == Stage.juniorHigh),
  GameEvent(
      'scout-visit',
      'プロのスカウトが練習を見に来た。',
      [
        EventChoice.risky('全力でアピールする', (p, c, f, rng) {
          if (rng.nextDouble() < 0.6) {
            return (
              player: _gain(p, f, 2),
              condition:
                  c.copyWith(morale: c.morale + 15, fatigue: c.fatigue + 10)
            );
          }
          return (
            player: p,
            condition: c.copyWith(morale: c.morale - 8, fatigue: c.fatigue + 10)
          );
        }),
        EventChoice(
          'いつも通りにやる',
          (p, c, f) => (player: p, condition: c.copyWith(morale: c.morale + 3)),
        ),
      ],
      when: (stage, cast) =>
          stage == Stage.highSchool || stage == Stage.pathChoice),
  GameEvent('injury-scare', '体に違和感がある。', [
    EventChoice(
      'すぐ休んで様子を見る',
      (p, c, f) => (
        player: p,
        condition: c.copyWith(fatigue: c.fatigue - 10, morale: c.morale - 3)
      ),
    ),
    EventChoice.risky('我慢して続ける', (p, c, f, rng) {
      if (rng.nextDouble() < 0.7) {
        return (
          player: _gain(p, f, 1),
          condition: c.copyWith(fatigue: c.fatigue + 10)
        );
      }
      return (
        player: p,
        condition: c.copyWith(morale: c.morale - 5, injuredTerms: 1)
      );
    }),
  ]),
  GameEvent('big-chance', '練習試合で先発のチャンスが回ってきた。', [
    EventChoice.risky('挑む', (p, c, f, rng) {
      if (rng.nextDouble() < 0.5) {
        return (
          player: _gain(p, f, 2),
          condition: c.copyWith(morale: c.morale + 15)
        );
      }
      return (
        player: p,
        condition: c.copyWith(morale: c.morale - 10, fatigue: c.fatigue + 10)
      );
    }),
    EventChoice(
      '今回は見送る',
      (p, c, f) => (player: p, condition: c.copyWith(morale: c.morale - 2)),
    ),
  ]),
  GameEvent('rain-day', '雨で外の練習が中止になった。', [
    EventChoice(
      'ゆっくり休む',
      (p, c, f) => (player: p, condition: c.copyWith(fatigue: c.fatigue - 15)),
    ),
    EventChoice(
      '室内で自主練する',
      (p, c, f) => (
        player: _gain(p, f, 1),
        condition: c.copyWith(fatigue: c.fatigue + 5)
      ),
    ),
  ]),
  GameEvent(
      'veteran-advice',
      'ベテランが、体の使い方を教えてくれると言う。',
      [
        EventChoice(
          '教えを聞く',
          (p, c, f) => (
            player: _gain(p, f, 2),
            condition: c.copyWith(morale: c.morale + 5)
          ),
        ),
        EventChoice(
          '自分のやり方を貫く',
          (p, c, f) => (player: p, condition: c.copyWith(morale: c.morale + 8)),
        ),
      ],
      when: (stage, cast) => stage == Stage.pro),
  GameEvent(
      'fan-letter',
      'ファンから手紙が届いた。',
      [
        EventChoice(
          '返事を書く',
          (p, c, f) => (
            player: p,
            condition: c.copyWith(morale: c.morale + 12, fatigue: c.fatigue + 3)
          ),
        ),
        EventChoice(
          '励みにして練習する',
          (p, c, f) => (
            player: _gain(p, f, 1),
            condition: c.copyWith(morale: c.morale + 8)
          ),
        ),
      ],
      when: (stage, cast) => stage == Stage.pro),
  GameEvent(
      'media',
      '雑誌の取材を受けることになった。',
      [
        EventChoice(
          '堂々と答える',
          (p, c, f) =>
              (player: p, condition: c.copyWith(morale: c.morale + 12)),
        ),
        EventChoice(
          '断って練習に集中する',
          (p, c, f) => (
            player: _gain(p, f, 1),
            condition: c.copyWith(morale: c.morale + 2, fatigue: c.fatigue + 4)
          ),
        ),
      ],
      when: (stage, cast) => stage == Stage.pro),
  GameEvent(
      'trade-rumor',
      'トレードの噂が耳に入ってきた。',
      [
        EventChoice(
          '気にせず目の前に集中する',
          (p, c, f) => (
            player: _gain(p, f, 1),
            condition: c.copyWith(morale: c.morale - 2)
          ),
        ),
        EventChoice(
          '球団に直接たずねる',
          (p, c, f) => (player: p, condition: c.copyWith(morale: c.morale + 6)),
        ),
      ],
      when: (stage, cast) => stage == Stage.pro),
  GameEvent(
      'rookie',
      '期待の新人が入団してきた。',
      [
        EventChoice(
          '負けじと練習量を増やす',
          (p, c, f) => (
            player: _gain(p, f, 2),
            condition: c.copyWith(morale: c.morale + 4, fatigue: c.fatigue + 12)
          ),
        ),
        EventChoice(
          '面倒を見てやる',
          (p, c, f) => (
            player: p,
            condition: c.copyWith(morale: c.morale + 10, fatigue: c.fatigue - 4)
          ),
        ),
      ],
      when: (stage, cast) => stage == Stage.pro),
  GameEvent(
      'sponsor',
      '企業から広告のオファーが来た。',
      [
        EventChoice(
          '受ける',
          (p, c, f) => (
            player: p,
            condition: c.copyWith(morale: c.morale + 14, fatigue: c.fatigue + 8)
          ),
        ),
        EventChoice(
          '野球に専念したいと断る',
          (p, c, f) => (
            player: _gain(p, f, 1),
            condition: c.copyWith(morale: c.morale + 4)
          ),
        ),
      ],
      when: (stage, cast) => stage == Stage.pro),
  GameEvent(
      'camp',
      'オフに海外でのトレーニングに誘われた。',
      [
        EventChoice.risky('参加する', (p, c, f, rng) {
          if (rng.nextDouble() < 0.7) {
            return (
              player: _gain(p, f, 3),
              condition:
                  c.copyWith(morale: c.morale + 8, fatigue: c.fatigue + 15)
            );
          }
          return (
            player: p,
            condition: c.copyWith(morale: c.morale - 6, fatigue: c.fatigue + 18)
          );
        }),
        EventChoice(
          '体を休める',
          (p, c, f) => (
            player: p,
            condition: c.copyWith(fatigue: c.fatigue - 15, morale: c.morale + 3)
          ),
        ),
      ],
      when: (stage, cast) => stage == Stage.pro),
  GameEvent(
      'hot-streak',
      '調子がいい。バットも球も思い通りだ。',
      [
        EventChoice(
          '勢いのまま攻める',
          (p, c, f) => (
            player: _gain(p, f, 2),
            condition: c.copyWith(morale: c.morale + 8, fatigue: c.fatigue + 8)
          ),
        ),
        EventChoice(
          '落ち着いて基本に立ち返る',
          (p, c, f) => (
            player: _gain(p, f, 1),
            condition: c.copyWith(morale: c.morale + 4)
          ),
        ),
      ],
      when: (stage, cast) => stage == Stage.pro || stage == Stage.highSchool),
  GameEvent(
      'school-trip',
      '学校行事で、練習を休む日ができた。',
      [
        EventChoice(
          '思いきり楽しむ',
          (p, c, f) => (
            player: p,
            condition: c.copyWith(morale: c.morale + 14, fatigue: c.fatigue - 8)
          ),
        ),
        EventChoice(
          '朝だけ自主練をしておく',
          (p, c, f) => (
            player: _gain(p, f, 1),
            condition: c.copyWith(morale: c.morale + 5)
          ),
        ),
      ],
      when: (stage, cast) =>
          stage == Stage.juniorHigh || stage == Stage.highSchool),
  GameEvent(
      'new-glove',
      '誕生日に、新しいグローブを買ってもらった。',
      [
        EventChoice(
          '毎日手入れして使い込む',
          (p, c, f) => (
            player: _gain(p, Ability.fielding, 2),
            condition: c.copyWith(morale: c.morale + 10)
          ),
        ),
        EventChoice(
          '友だちに自慢しにいく',
          (p, c, f) =>
              (player: p, condition: c.copyWith(morale: c.morale + 14)),
        ),
      ],
      when: (stage, cast) => stage == Stage.youth),
  GameEvent('diet', '食事や睡眠を見直すことにした。', [
    EventChoice(
      '食事を変えて体を大きくする',
      (p, c, f) => (
        player: _gain(p, f, 1),
        condition: c.copyWith(fatigue: c.fatigue + 5)
      ),
    ),
    EventChoice(
      '睡眠をしっかりとる',
      (p, c, f) => (
        player: p,
        condition: c.copyWith(fatigue: c.fatigue - 15, morale: c.morale + 3)
      ),
    ),
  ]),
  GameEvent(
      'exam',
      '学校のテストが近い。',
      [
        EventChoice(
          'ちゃんと勉強する',
          (p, c, f) => (
            player: p,
            condition: c.copyWith(morale: c.morale + 5, fatigue: c.fatigue - 5)
          ),
        ),
        EventChoice.risky('練習を優先する', (p, c, f, rng) {
          if (rng.nextDouble() < 0.5) {
            return (player: _gain(p, f, 1), condition: c);
          }
          return (
            player: p,
            condition: c.copyWith(morale: c.morale - 10)
          ); // 先生に叱られた
        }),
      ],
      when: (stage, cast) =>
          stage == Stage.juniorHigh ||
          stage == Stage.highSchool ||
          stage == Stage.youth),
  GameEvent(
      'rival-slump',
      'ライバルが不調に苦しんでいる。',
      [
        EventChoice(
          '声をかけて励ます',
          (p, c, f) => (player: p, condition: c.copyWith(morale: c.morale + 3)),
          (cast, rng) => cast.rival?.addBond(10),
        ),
        EventChoice(
          '気にせず自分の練習をする',
          (p, c, f) => (
            player: _gain(p, f, 1),
            condition: c.copyWith(fatigue: c.fatigue + 5)
          ),
        ),
      ],
      when: (stage, cast) => cast.rival != null),
  GameEvent(
      'mate-quarrel',
      'チームメイトが言い争いを始めた。',
      [
        EventChoice(
          '間に入って仲直りさせる',
          (p, c, f) => (
            player: p,
            condition: c.copyWith(fatigue: c.fatigue + 5, morale: c.morale + 4)
          ),
          (cast, rng) {
            for (final m in cast.teammates) {
              m.addBond(6);
            }
          },
        ),
        EventChoice(
          '放っておく',
          (p, c, f) => (player: p, condition: c),
          (cast, rng) {
            for (final m in cast.teammates) {
              m.addBond(-4);
            }
          },
        ),
      ],
      when: (stage, cast) => cast.teammates.length >= 2),
  GameEvent('old-bat', '古い道具を見つけた。', [
    EventChoice(
      '使ってみる',
      (p, c, f) =>
          (player: _gain(p, f, 1), condition: c.copyWith(morale: c.morale + 5)),
    ),
    EventChoice(
      '大事にしまっておく',
      (p, c, f) => (player: p, condition: c.copyWith(morale: c.morale + 3)),
    ),
  ]),
  GameEvent(
      'lover-lunch',
      '恋人が手作りのお弁当を持ってきてくれた。',
      [
        EventChoice(
          'ありがたくいただく',
          (p, c, f) => (
            player: p,
            condition: c.copyWith(morale: c.morale + 12, fatigue: c.fatigue - 5)
          ),
          (cast, rng) => cast.lover?.addBond(8),
        ),
        EventChoice(
          '気持ちだけ受け取る',
          (p, c, f) => (player: p, condition: c.copyWith(morale: c.morale + 2)),
          (cast, rng) => cast.lover?.addBond(-2),
        ),
      ],
      when: (stage, cast) => cast.lover != null),
];

/// 出来事の起きる確率(1季節あたり)。
const eventChance = 0.4;

/// 今季の出来事。起きなければ null。
/// `stage` と `cast` を渡すと、条件のある出来事(恋人・ライバルなど)も候補に入る。
GameEvent? drawEvent(Random rng,
    {double share = 1.0,
    Stage? stage,
    Cast? cast,
    String? exclude,
    Set<String> recent = const {}}) {
  if (rng.nextDouble() >= eventChance * share) return null;
  final pool = [
    for (final e in events)
      if (e.when == null ||
          (stage != null && cast != null && e.when!(stage, cast)))
        e,
  ];
  // 直前と同じ出来事、最近起きた出来事は避ける(候補が無くなるなら、避けるのをやめる)。
  var fresh = [
    for (final e in pool)
      if (e.id != exclude && !recent.contains(e.id)) e
  ];
  if (fresh.length < 3) {
    fresh = [
      for (final e in pool)
        if (e.id != exclude) e
    ];
  }
  final from = fresh.isEmpty ? pool : fresh;
  return from[rng.nextInt(from.length)];
}
