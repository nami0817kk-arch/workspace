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
    this.school,
    this.schoolLabel,
    this.national = false,
    this.salaryPct = 0,
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

  /// 進学先の環境(大会の味方の強さへの上乗せ)。null なら変えない。
  final double? school;
  final String? schoolLabel;

  /// 日本代表に参加する(次の冬に世界大会に出る)。
  final bool national;

  /// 年俸の増減(%)。フリーエージェントでの契約交渉など。プロ以外では効かない。
  final int salaryPct;
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
    this.abroadOnly = false,
    this.forced = false,
    this.weight = 1.0,
  });

  final String id;
  final String title;
  final String body;
  final List<EventOption> options;
  final int minAge;
  final int maxAge;
  final bool proOnly;

  /// 海外プロでだけ起きる。
  final bool abroadOnly;

  /// 段階が変わるときに必ず起きる出来事(進学先の選択)。ふだんの抽選には出ない。
  final bool forced;

  /// 起きやすさ(1.0 が普通、小さいほどまれ)。
  final double weight;
}

/// 進学先の選択(中学・高校に上がるとき必ず起きる)。
const schoolEvents = <EventDef>[
  EventDef(
    id: 'school_jh',
    title: '中学の部活選び',
    body: '小学校を卒業する。どこでバスケを続けようか。',
    forced: true,
    options: [
      EventOption(
          '強豪の中学へ。厳しい環境に飛び込む',
          Effect(
              school: 4,
              schoolLabel: '強豪校',
              coach: 15,
              teamwork: -10,
              fatigue: 8,
              morale: -3)),
      EventOption(
          '地元の中学で、のびのびやる',
          Effect(
              school: -2,
              schoolLabel: '地元の学校',
              teamwork: 15,
              morale: 8,
              focusBonus: 2)),
      EventOption(
          '少数精鋭のクラブチームへ',
          Effect(school: 2, schoolLabel: 'クラブチーム', coach: 10, abilities: {Ability.dribble: 1, Ability.pass: 1})),
    ],
  ),
  EventDef(
    id: 'school_hs',
    title: '高校の進路',
    body: '中学を卒業する。三年間をどこで戦おう。',
    forced: true,
    options: [
      EventOption(
          '全国常連の強豪校へ',
          Effect(
              school: 5,
              schoolLabel: '強豪校',
              coach: 15,
              teamwork: -12,
              fatigue: 10,
              morale: -4,
              achievement: 3)),
      EventOption(
          '地元の公立校で、エースを目指す',
          Effect(
              school: -3,
              schoolLabel: '地元の学校',
              teamwork: 15,
              morale: 10,
              focusBonus: 3)),
      EventOption(
          '指導に定評のある私立校へ',
          Effect(school: 2, schoolLabel: '私立校', coach: 12, abilities: {Ability.defense: 1, Ability.midRange: 1})),
    ],
  ),
];

/// プロの入団先・移籍先の選択(入団時と、23・27・31歳で起きる)。
const proEvents = <EventDef>[
  EventDef(
    id: 'pro_join',
    title: '入団先の選択',
    body: 'いくつかのチームから声がかかった。どこで戦う？',
    forced: true,
    options: [
      EventOption(
          '常勝の強豪チーム。試合に出るのが先決だ',
          Effect(school: 5, schoolLabel: '強豪チーム', coach: 12, teamwork: -12, fatigue: 8, morale: -3)),
      EventOption(
          '育成に定評のあるチーム',
          Effect(school: 1, schoolLabel: '育成型のチーム', coach: 20, abilities: {Ability.midRange: 1, Ability.defense: 1})),
      EventOption(
          '地元のチームで、中心選手として',
          Effect(school: -2, schoolLabel: '地元のチーム', teamwork: 20, morale: 10, focusBonus: 2)),
    ],
  ),
  EventDef(
    id: 'pro_move',
    title: '移籍のオファー',
    body: '契約の更新の時期。移籍のオファーも届いている。',
    forced: true,
    options: [
      EventOption(
          '強豪チームへ移籍する',
          Effect(school: 5, schoolLabel: '強豪チーム', coach: -5, teamwork: -15, fatigue: 8, morale: 2, achievement: 3)),
      EventOption(
          '今のチームに残る',
          Effect(teamwork: 12, morale: 6, coach: 8)),
      EventOption(
          '新天地で一から挑戦する',
          Effect(school: -1, schoolLabel: '新天地のチーム', teamwork: -8, morale: 8, abilities: {Ability.speed: 1, Ability.threePoint: 1})),
    ],
  ),
];

/// フリーエージェント(プロで25・29・33歳に必ず起きる)。実世界と同じく、市場に出て条件の良いチームへ移るか、
/// 今のチームと再契約するかを選ぶ。年俸が動く(`Effect.salaryPct`)。
const proFaEvents = <EventDef>[
  EventDef(
    id: 'pro_fa',
    title: 'フリーエージェント',
    body: '契約の年数が満了した。市場に出れば、複数のチームから条件の良いオファーが届きそうだ。',
    forced: true,
    options: [
      EventOption(
          '市場に出て、最高額を出すチームへ',
          Effect(salaryPct: 40, school: 3, schoolLabel: '高額オファーのチーム', coach: -10, teamwork: -15, morale: 4)),
      EventOption(
          '今のチームと再契約する(愛着と信頼)',
          Effect(salaryPct: 12, teamwork: 10, coach: 10, morale: 6)),
      EventOption(
          '優勝を狙える強豪へ(年俸は据え置き)',
          Effect(school: 5, schoolLabel: '強豪チーム', teamwork: -12, coach: -5, achievement: 3, fatigue: 5)),
    ],
  ),
];

/// 長い怪我(3ターン以上)から復帰したときに必ず起きる出来事。
const injuryEvents = <EventDef>[
  EventDef(
    id: 'comeback',
    title: '復帰のとき',
    body: '長い怪我が癒えた。コートに戻る日が来た。どう復帰する？',
    forced: true,
    options: [
      EventOption('焦らず、段階的に復帰する', Effect(fatigue: -10, morale: 5, coach: 6)),
      EventOption('早く試合勘を戻したい(無理をする)', Effect(morale: 10, focusBonus: 2, injuryChance: 0.25)),
      EventOption('離脱中に磨いた武器を試す', Effect(abilities: {Ability.threePoint: 1, Ability.dribble: 1}, morale: 3)),
    ],
  ),
];

/// 日本代表の招集(プロで24・28・32歳、総合60以上のときに必ず届く)。
const nationalEvents = <EventDef>[
  EventDef(
    id: 'national_call',
    title: '日本代表に選ばれた',
    body: '日本代表の強化合宿に招集された。次の冬、世界の舞台が待っている。',
    forced: true,
    options: [
      EventOption('日の丸を背負って戦う', Effect(national: true, fatigue: 10, morale: 12, teamwork: 4)),
      EventOption('所属チームに専念する', Effect(coach: 6, morale: 2)),
    ],
  ),
];

const events = <EventDef>[
  EventDef(
    id: 'coach_menu',
    title: 'コーチの特別メニュー',
    body: '{coach}が「お前だけ特別メニューをやってみるか」と声をかけてきた。',
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
    body: '先輩の{mate}がシュートフォームを見てくれた。「肘の向きを直すといい」',
    options: [
      EventOption('素直に聞く', Effect(abilities: {Ability.threePoint: 2, Ability.midRange: 2})),
      EventOption('自分流を貫く', Effect(morale: 6)),
    ],
  ),
  EventDef(
    id: 'night_practice',
    title: '夜の自主練',
    body: '体育館の灯りがまだついている。{mate}がひとりでシュートを打っている。',
    options: [
      EventOption('自分もやる', Effect(abilities: {Ability.stamina: 3}, fatigue: 15, injuryChance: 0.10)),
      EventOption('今日は帰る', Effect(fatigue: -5)),
    ],
  ),
  EventDef(
    id: 'friends',
    title: '友だちの誘い',
    body: '{mate}が「たまには遊びに行こうぜ」と誘ってきた。',
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
    body: '{mate}と意見がぶつかった。ベンチの空気が重い。',
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
    body: '{coach}が「最近どうだ」と声をかけてくれた。',
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
    id: 'contract_talk',
    title: '契約更改',
    body: '来季の契約についての話し合い。評価は上々だ。',
    minAge: 19,
    proOnly: true,
    options: [
      EventOption('長期契約で腰を据える', Effect(morale: 8, coach: 6, fatigue: -5)),
      EventOption('短い契約で、次の挑戦に備える', Effect(focusBonus: 2, morale: 3)),
    ],
  ),
  EventDef(
    id: 'fan_event',
    title: 'ファン感謝祭',
    body: 'ファンとの交流イベントがあった。大きな声援を浴びた。',
    minAge: 19,
    proOnly: true,
    options: [
      EventOption('笑顔で応える', Effect(morale: 14, teamwork: 5, fatigue: 5, trait: Trait.starPower)),
      EventOption('早めに帰って体を休める', Effect(fatigue: -12)),
    ],
  ),
  EventDef(
    id: 'young_rise',
    title: '若手の台頭',
    body: '同じポジションに、期待の若手が入ってきた。',
    minAge: 24,
    proOnly: true,
    options: [
      EventOption('負けじと自分を磨く', Effect(focusBonus: 3, fatigue: 10, morale: -2)),
      EventOption('先輩として育てる', Effect(teamwork: 12, abilities: {Ability.pass: 1, Ability.defense: 1}, coach: 5)),
    ],
  ),
  EventDef(
    id: 'aging',
    title: '衰えとの向き合い',
    body: '以前のようには体が動かない。どう向き合う？',
    minAge: 30,
    proOnly: true,
    options: [
      EventOption('トレーニングで体を守る', Effect(abilities: {Ability.speed: 2, Ability.stamina: 2}, fatigue: 12, morale: -2)),
      EventOption('技術と経験で補う', Effect(abilities: {Ability.midRange: 2, Ability.pass: 2, Ability.defense: 1}, morale: 4)),
    ],
  ),
  EventDef(
    id: 'language_wall',
    title: '言葉の壁',
    body: '海外のチームで、言葉が通じずに戸惑う場面が続く。',
    minAge: 21,
    proOnly: true,
    abroadOnly: true,
    options: [
      EventOption('通訳に頼らず、自分から話しかける', Effect(teamwork: 14, morale: -3, fatigue: 6, abilities: {Ability.pass: 1})),
      EventOption('プレーで語ると割り切る', Effect(focusBonus: 2, teamwork: -4, morale: 3)),
    ],
  ),
  EventDef(
    id: 'world_stage',
    title: '世界の舞台',
    body: '世界最高峰のスーパースターと、コートで向き合う機会が来た。',
    minAge: 21,
    proOnly: true,
    abroadOnly: true,
    options: [
      EventOption('真っ向から挑む', Effect(abilities: {Ability.physical: 2, Ability.defense: 2}, fatigue: 15, achievement: 5)),
      EventOption('技を盗むつもりで観察する', Effect(abilities: {Ability.dribble: 2, Ability.threePoint: 2}, morale: 4)),
    ],
  ),
  EventDef(
    id: 'ft_practice',
    title: '居残りのフリースロー',
    body: '練習後の体育館。{mate}が「勝負どころで決めるのは、フリースローだ」と言って、黙々と打ち続けている。',
    minAge: 9,
    options: [
      EventOption('一緒に100本打つ', Effect(abilities: {Ability.freeThrow: 4}, fatigue: 8, teamwork: 5)),
      EventOption('フォームの確認だけして帰る', Effect(abilities: {Ability.freeThrow: 2}, fatigue: -3)),
    ],
  ),
  EventDef(
    id: 'breakthrough',
    title: '突然のひらめき',
    body: '練習中、これまで掴めなかった感覚が突然わかった。体が勝手に動く。',
    minAge: 10,
    weight: 0.25,
    options: [
      EventOption('この感覚を逃さず、練習で定着させる', Effect(focusBonus: 4, fatigue: 12, morale: 8)),
      EventOption('次の試合で試してみる', Effect(focusBonus: 2, morale: 14, trait: Trait.clutch)),
    ],
  ),
  EventDef(
    id: 'legend_visit',
    title: '伝説の選手との出会い',
    body: '偶然、往年の名選手と話す機会があった。「お前のプレー、悪くないな」',
    minAge: 12,
    weight: 0.25,
    options: [
      EventOption('教えを乞う', Effect(abilities: {Ability.midRange: 2, Ability.threePoint: 2, Ability.dribble: 2}, coach: 8, morale: 6)),
      EventOption('自分の目で盗む', Effect(abilities: {Ability.defense: 2, Ability.pass: 2}, trait: Trait.genius)),
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
  for (final e in [
    ...events,
    ...schoolEvents,
    ...proEvents,
    ...proFaEvents,
    ...injuryEvents,
    ...nationalEvents,
  ]) {
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
    bool abroad = false,
    List<String> recent = const []}) {
  if (rng.nextDouble() >= eventChance) return null;
  final all = [
    for (final e in events)
      if (p.age >= e.minAge &&
          p.age <= e.maxAge &&
          (!e.proOnly || pro) &&
          (!e.abroadOnly || abroad))
        e,
  ];
  // 最近起きたものは避ける(同じ出来事ばかりにならないように)。
  final fresh = [for (final e in all) if (!recent.contains(e.id)) e];
  final pool = fresh.isEmpty ? all : fresh;
  if (pool.isEmpty) return null;
  // 重みに応じて引く(まれな出来事は少なく)。
  final total = pool.fold(0.0, (s, e) => s + e.weight);
  var x = rng.nextDouble() * total;
  for (final e in pool) {
    x -= e.weight;
    if (x < 0) return e;
  }
  return pool.last;
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
  var injuryName = c.injuryName;
  var gotInjured = false;
  if (!c.injured && e.injuryChance > 0) {
    if (rng.nextDouble() < e.injuryChance * injuryMultiplier(p.traits)) {
      final kind = rollInjury(rng);
      injured = kind.terms(rng);
      injuryName = kind.label;
      if (kind.lasting) {
        for (final x in applyLastingInjury(ab).entries) {
          ab[x.key] = x.value;
        }
      }
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
      injuryName: injuryName,
    ),
    gotInjured: gotInjured,
  );
}
