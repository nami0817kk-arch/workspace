import 'dart:math';

import 'life.dart';
import 'player.dart';
import 'traits.dart';

/// 選択の結果。変わるものだけ指定する。
class Effect {
  const Effect({
    this.abilities = const {},
    this.focusBonus = 0,
    this.morale = 0,
    this.fatigue = 0,
    this.injuryChance = 0,
    this.trait,
    this.heightCm = 0,
    this.achievement = 0,
  });

  /// 能力の増減(決まった能力)。
  final Map<Ability, int> abilities;

  /// 今いちばん重点にしている能力への加算。
  final int focusBonus;
  final int morale;
  final int fatigue;

  /// 怪我をする確率(0〜1)。特性の効き方もかかる。
  final double injuryChance;

  /// 習得できるなら得る特性。
  final Trait? trait;
  final double heightCm;

  /// 直近の実績に足す点(スカウトの目に留まる等)。
  final double achievement;
}

class EventOption {
  const EventOption(this.label, this.effect);
  final String label;
  final Effect effect;
}

class EventDef {
  const EventDef({
    required this.id,
    required this.title,
    required this.body,
    required this.options,
    this.minAge = 6,
    this.maxAge = 40,
    this.proOnly = false,
  });

  final String id;
  final String title;
  final String body;
  final List<EventOption> options;
  final int minAge;
  final int maxAge;
  final bool proOnly;
}

const events = <EventDef>[
  EventDef(
    id: 'coach_menu',
    title: 'コーチの特別メニュー',
    body: 'コーチが「お前だけ特別メニューをやってみるか」と声をかけてきた。',
    options: [
      EventOption('受ける', Effect(focusBonus: 3, fatigue: 15, trait: Trait.hardWorker)),
      EventOption('今日は遠慮する', Effect(morale: -3)),
    ],
  ),
  EventDef(
    id: 'rival',
    title: 'ライバルの出現',
    body: '同い年の選手が練習試合で圧倒してきた。悔しいが、胸が熱くなる。',
    minAge: 9,
    options: [
      EventOption('勝負を挑み続ける', Effect(abilities: {Ability.defense: 2, Ability.speed: 2}, morale: 8, fatigue: 10)),
      EventOption('距離を置く', Effect(morale: -5)),
    ],
  ),
  EventDef(
    id: 'slump',
    title: 'スランプ',
    body: 'シュートが入らない。何をやっても噛み合わない日が続く。',
    minAge: 10,
    options: [
      EventOption('しっかり休む', Effect(fatigue: -20, morale: 3)),
      EventOption('気合いで練習する', Effect(focusBonus: 2, fatigue: 20, morale: -5, injuryChance: 0.15)),
    ],
  ),
  EventDef(
    id: 'senior_advice',
    title: '先輩のアドバイス',
    body: '先輩がシュートフォームを見てくれた。「肘の向きを直すといい」',
    options: [
      EventOption('素直に聞く', Effect(abilities: {Ability.threePoint: 2, Ability.midRange: 2})),
      EventOption('自分流を貫く', Effect(morale: 6)),
    ],
  ),
  EventDef(
    id: 'night_practice',
    title: '夜の自主練',
    body: '体育館の灯りがまだついている。ボールの音が聞こえる。',
    options: [
      EventOption('自分もやる', Effect(abilities: {Ability.stamina: 3}, fatigue: 15, injuryChance: 0.10)),
      EventOption('今日は帰る', Effect(fatigue: -5)),
    ],
  ),
  EventDef(
    id: 'friends',
    title: '友だちの誘い',
    body: '友だちが「たまには遊びに行こうぜ」と誘ってきた。',
    options: [
      EventOption('遊びに行く', Effect(morale: 15, fatigue: -10)),
      EventOption('断って練習する', Effect(focusBonus: 1, morale: -3)),
    ],
  ),
  EventDef(
    id: 'video',
    title: '試合の映像',
    body: '憧れの選手の試合映像を、夜中までかけて何度も見返した。',
    options: [
      EventOption('パスの動きを真似る', Effect(abilities: {Ability.pass: 3})),
      EventOption('守備の動きを真似る', Effect(abilities: {Ability.defense: 3})),
    ],
  ),
  EventDef(
    id: 'growing_pains',
    title: '成長痛',
    body: '膝が痛い。身長が伸びている証拠だと言われた。',
    minAge: 10,
    maxAge: 17,
    options: [
      EventOption('休んで体を守る', Effect(fatigue: -15, heightCm: 1.5)),
      EventOption('我慢して練習する', Effect(focusBonus: 2, fatigue: 10, injuryChance: 0.35)),
    ],
  ),
  EventDef(
    id: 'joint_practice',
    title: '他校との合同練習',
    body: '強豪校との合同練習に呼ばれた。レベルの差を肌で感じる。',
    minAge: 13,
    options: [
      EventOption('全力でぶつかる', Effect(abilities: {Ability.physical: 2, Ability.rebound: 2}, fatigue: 15, achievement: 5)),
      EventOption('見学に徹する', Effect(abilities: {Ability.pass: 1, Ability.defense: 1}, morale: 2)),
    ],
  ),
  EventDef(
    id: 'scout',
    title: 'スカウトの視線',
    body: '客席に、それらしい人が座っている。試合のあと、名刺を渡された。',
    minAge: 17,
    options: [
      EventOption('積極的にアピールする', Effect(achievement: 10, morale: 5, trait: Trait.starPower, fatigue: 5)),
      EventOption('目の前のプレーに集中する', Effect(trait: Trait.clutch, morale: 3)),
    ],
  ),
  EventDef(
    id: 'idol_game',
    title: '憧れの選手の試合',
    body: '憧れの選手の試合を、会場で観られることになった。',
    options: [
      EventOption('最前列で観る', Effect(morale: 20, trait: Trait.sunny)),
      EventOption('分析しながら観る', Effect(abilities: {Ability.dribble: 2, Ability.pass: 2})),
    ],
  ),
  EventDef(
    id: 'teammate_trouble',
    title: 'チームの不協和音',
    body: 'チームメイトと意見がぶつかった。ベンチの空気が重い。',
    minAge: 12,
    options: [
      EventOption('話し合う', Effect(abilities: {Ability.pass: 2}, morale: 5, fatigue: 5)),
      EventOption('黙って練習する', Effect(focusBonus: 1, morale: -6)),
    ],
  ),
  EventDef(
    id: 'pro_media',
    title: '取材の依頼',
    body: '地元メディアから取材の依頼が来た。',
    minAge: 19,
    proOnly: true,
    options: [
      EventOption('受ける', Effect(morale: 10, fatigue: 8, trait: Trait.starPower)),
      EventOption('断って調整する', Effect(fatigue: -10)),
    ],
  ),
];

EventDef? eventById(String id) {
  for (final e in events) {
    if (e.id == id) return e;
  }
  return null;
}

/// 1ターンに出来事が起きる確率。
const eventChance = 0.35;

/// 出来事を引く(起きなければ null)。年齢・段階に合うものから選ぶ。
EventDef? rollEvent(Player p, {required bool pro, required Random rng}) {
  if (rng.nextDouble() >= eventChance) return null;
  final pool = [
    for (final e in events)
      if (p.age >= e.minAge && p.age <= e.maxAge && (!e.proOnly || pro)) e,
  ];
  if (pool.isEmpty) return null;
  return pool[rng.nextInt(pool.length)];
}

/// 選んだ結果を選手・体調に当てる。achievement は呼び出し側が扱う。
({Player player, Condition condition, bool gotInjured}) applyEffect(
  Player p,
  Condition c,
  Effect e,
  Ability focus,
  Random rng,
) {
  final ab = Map<Ability, int>.of(p.abilities);
  void add(Ability a, int d) => ab[a] = (ab[a]! + d).clamp(0, abilityCap);
  for (final x in e.abilities.entries) {
    add(x.key, x.value);
  }
  if (e.focusBonus != 0) add(focus, e.focusBonus);

  var fatigue = c.fatigue;
  fatigue += e.fatigue > 0
      ? (e.fatigue * fatigueMultiplier(p.traits)).round()
      : e.fatigue;
  var morale = c.morale;
  morale += e.morale > 0
      ? (e.morale * moraleGainMultiplier(p.traits)).round()
      : (e.morale * moraleLossMultiplier(p.traits)).round();

  var injured = c.injuredTerms;
  var gotInjured = false;
  if (!c.injured && e.injuryChance > 0) {
    if (rng.nextDouble() < e.injuryChance * injuryMultiplier(p.traits)) {
      injured = 1 + rng.nextInt(3);
      gotInjured = true;
      morale -= 10;
    }
  }

  final traits = e.trait == null ? p.traits : gain(p.traits, e.trait!);
  return (
    player: p.copyWith(
      abilities: ab,
      traits: traits,
      heightCm: p.heightCm + e.heightCm,
    ),
    condition: c.copyWith(
      fatigue: fatigue,
      morale: morale,
      injuredTerms: injured,
    ),
    gotInjured: gotInjured,
  );
}
