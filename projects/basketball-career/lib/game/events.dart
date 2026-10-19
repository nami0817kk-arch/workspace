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
    this.teamwork = 0,
    this.coach = 0,
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

  /// チームワーク(0〜100)への加算。
  final int teamwork;

  /// コーチとの信頼(0〜100)への加算。
  final int coach;
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
      EventOption('受ける', Effect(focusBonus: 3, fatigue: 15, trait: Trait.hardWorker, coach: 6)),
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
      EventOption('遊びに行く', Effect(morale: 15, fatigue: -10, teamwork: 6)),
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
      EventOption('話し合う', Effect(abilities: {Ability.pass: 2}, morale: 5, fatigue: 5, teamwork: 12)),
      EventOption('黙って練習する', Effect(focusBonus: 1, morale: -6, teamwork: -10)),
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
  EventDef(
    id: 'rival_talk',
    title: 'ライバルとの会話',
    body: '試合のあと、{rival}が声をかけてきた。「次は負けない」',
    minAge: 12,
    options: [
      EventOption('握手して健闘をたたえる', Effect(morale: 8, abilities: {Ability.pass: 1})),
      EventOption('「こっちこそ」と言い返す', Effect(focusBonus: 2, morale: 4, fatigue: 5)),
    ],
  ),
  EventDef(
    id: 'coach_talk',
    title: 'コーチとの面談',
    body: 'コーチが「最近どうだ」と声をかけてくれた。',
    options: [
      EventOption('悩みを正直に話す', Effect(morale: 6, coach: 12)),
      EventOption('「大丈夫です」と答える', Effect(morale: 2, coach: -3)),
    ],
  ),
  EventDef(
    id: 'family',
    title: '家族の応援',
    body: '家族が毎週、遠くから応援に来てくれている。',
    options: [
      EventOption('期待に応えたいと奮起する', Effect(focusBonus: 1, morale: 10)),
      EventOption('感謝を伝えて、ゆっくり休む', Effect(fatigue: -12, morale: 8)),
    ],
  ),
  EventDef(
    id: 'captain',
    title: 'キャプテンに指名',
    body: 'チームのキャプテンを任されることになった。',
    minAge: 12,
    options: [
      EventOption('引き受ける', Effect(teamwork: 15, abilities: {Ability.pass: 1}, fatigue: 8, coach: 5)),
      EventOption('プレーに集中したいと断る', Effect(focusBonus: 2, teamwork: -4)),
    ],
  ),
  EventDef(
    id: 'kouhai',
    title: '後輩の指導',
    body: '入ってきたばかりの後輩が、基本を教えてほしいと頼んできた。',
    minAge: 13,
    options: [
      EventOption('丁寧に教える', Effect(abilities: {Ability.defense: 1, Ability.pass: 1}, teamwork: 8, fatigue: 5)),
      EventOption('自分の練習を優先する', Effect(focusBonus: 2, teamwork: -3)),
    ],
  ),
  EventDef(
    id: 'body_making',
    title: '体づくり',
    body: 'トレーナーから、体づくりのメニューを勧められた。',
    minAge: 12,
    options: [
      EventOption('食事と筋トレを徹底する', Effect(abilities: {Ability.physical: 3}, fatigue: 8, morale: -2)),
      EventOption('今のペースを守る', Effect(fatigue: -4)),
    ],
  ),
  EventDef(
    id: 'overseas_camp',
    title: '海外キャンプへの招待',
    body: '海外の強豪が開くキャンプに招待された。世界の速さと高さを知る機会だ。',
    minAge: 17,
    options: [
      EventOption('参加する', Effect(abilities: {Ability.speed: 2, Ability.physical: 2, Ability.defense: 1}, fatigue: 20, morale: 6, achievement: 4)),
      EventOption('見送る', Effect(fatigue: -6)),
    ],
  ),
  EventDef(
    id: 'injury_comeback',
    title: '復帰を支えた人',
    body: '辛いリハビリの間、ずっと支えてくれた人がいる。',
    minAge: 12,
    options: [
      EventOption('その人のためにも頑張ると誓う', Effect(morale: 12, trait: Trait.sunny)),
      EventOption('自分の力だけで乗り越えたと考える', Effect(abilities: {Ability.stamina: 2}, morale: 3)),
    ],
  ),
  EventDef(
    id: 'sponsor',
    title: 'スポンサーの打診',
    body: '地元の企業が、応援したいと申し出てきた。',
    minAge: 19,
    proOnly: true,
    options: [
      EventOption('受ける', Effect(morale: 10, achievement: 3, fatigue: 5)),
      EventOption('練習に集中するため断る', Effect(focusBonus: 2)),
    ],
  ),
  EventDef(
    id: 'veteran_advice',
    title: 'ベテランの教え',
    body: '長く第一線で戦うベテランが、コツを教えてくれた。',
    minAge: 19,
    proOnly: true,
    options: [
      EventOption('学ぶ姿勢で聞く', Effect(abilities: {Ability.midRange: 2, Ability.defense: 2}, coach: 4)),
      EventOption('自分のやり方を貫く', Effect(morale: 5)),
    ],
  ),
  EventDef(
    id: 'study_balance',
    title: '勉強との両立',
    body: '部活と勉強の両立に悩んでいる。',
    minAge: 12,
    maxAge: 18,
    options: [
      EventOption('勉強の時間を確保する', Effect(morale: 4, fatigue: -5)),
      EventOption('バスケを優先する', Effect(focusBonus: 2, morale: -3, fatigue: 5)),
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
EventDef? rollEvent(Player p,
    {required bool pro,
    required Random rng,
    List<String> recent = const []}) {
  if (rng.nextDouble() >= eventChance) return null;
  final all = [
    for (final e in events)
      if (p.age >= e.minAge && p.age <= e.maxAge && (!e.proOnly || pro)) e,
  ];
  // 最近起きたものは避ける(同じ出来事ばかりにならないように)。
  final fresh = [for (final e in all) if (!recent.contains(e.id)) e];
  final pool = fresh.isEmpty ? all : fresh;
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
