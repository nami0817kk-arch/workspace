// 特殊能力: 育てながら貯めた「特殊能力ポイント(SP)」で、自分で選んで習得する能力。
// 特性(生まれつき・出来事で身につく)や得意技(条件を満たすと自然に身につく)と違い、
// 何を習得するか・どの順で取るかをプレーヤーが決める(前提のある能力もある)。固有名詞は使わない。
//
// 効き方はこのファイルの関数に集める(他のファイルは能力の名前を直接見ない)。

import 'match.dart';
import 'player.dart';

enum SpecialKind { passive, active }

/// 画面で並べる分類。
enum SpecialCategory {
  clutch('勝負どころ'),
  play('プレーの得意'),
  growth('育成'),
  body('体と心'),
  team('チームと試合運び'),
  pro('プロの世界');

  const SpecialCategory(this.label);
  final String label;
}

enum Special {
  // ── 勝負どころ ──
  calm('冷静沈着', '勝負どころの成功率 +3%。', 3, SpecialCategory.clutch),
  clutchMaster('クラッチの申し子', '勝負どころの成功率 +4%。', 7, SpecialCategory.clutch,
      requires: Special.calm),
  lastShot('ラストショットの主役', '勝負どころの成功率 +3%(さらに)。', 8, SpecialCategory.clutch,
      requires: Special.clutchMaster),
  zone('ゾーン', '大会ごとに1回、勝負どころで使うと成功率 +12%。', 7, SpecialCategory.clutch,
      requires: Special.calm, kind: SpecialKind.active),
  rivalKiller('ライバルキラー', 'ライバル戦の勝負どころの成功率 +4%。', 4, SpecialCategory.clutch),

  // ── プレーの得意(勝負どころの選択ごと) ──
  driveAce('切り込み隊長', '勝負どころの「ドライブ」の成功率 +5%。', 3, SpecialCategory.play),
  threeAce('3Pの鬼', '勝負どころの「3P」の成功率 +5%。', 3, SpecialCategory.play),
  passAce('司令塔の眼', '勝負どころの「パス」の成功率 +5%。', 3, SpecialCategory.play),
  defendAce('最後の砦', '勝負どころの「ディフェンス」の成功率 +5%。', 3, SpecialCategory.play),
  foulAce('審判泣かせ', '勝負どころの「ファウルをもらう」の成功率 +6%。', 3, SpecialCategory.play),

  // ── 育成(能力の伸び) ──
  prodigy('努力の天才', '練習での伸びが +5%(伸びる年だけ)。', 6, SpecialCategory.growth),
  shooterTraining('シューティング特訓', '3P・ミドル・フリースローが +12% 伸びやすい。', 4, SpecialCategory.growth),
  slashTraining('突破力の特訓', 'ゴール下・ドリブルが +12% 伸びやすい。', 4, SpecialCategory.growth),
  passTraining('パスセンス', 'パスが +15% 伸びやすい。', 3, SpecialCategory.growth),
  defenseTraining('守備職人', 'ディフェンス・スピードが +12% 伸びやすい。', 4, SpecialCategory.growth),
  reboundNose('リバウンドの嗅覚', 'リバウンド・ゴール下が +12% 伸びやすい。', 4, SpecialCategory.growth),
  bodyMaking('肉体改造', 'フィジカル・スタミナ・スピードが +12% 伸びやすい。', 4, SpecialCategory.growth),
  longevity('長持ち', '年を重ねたときの衰えが20%遅くなる。', 4, SpecialCategory.growth),

  // ── 体と心 ──
  resilience('不屈', '休養・交流での疲れの回復が +25%。', 3, SpecialCategory.body),
  ironBody('頑丈な体', '怪我をする確率が30%減る。', 4, SpecialCategory.body),
  resetMind('切り替えの早さ', '気持ちが下がる量が30%減る。', 3, SpecialCategory.body),
  positive('ポジティブ', '気持ちが上がる量が +25%。', 3, SpecialCategory.body),

  // ── チームと試合運び ──
  ironWall('鉄壁の守り', 'ファウルが25%減る。', 3, SpecialCategory.team),
  fireSpirit('熱血', '連勝・連敗の勢いの効きが1.5倍。', 3, SpecialCategory.team),
  allSeeing('万能の目', 'ハーフタイムの作戦と相手の相性が、1.3倍効く。', 5, SpecialCategory.team),
  analyst('分析の鬼', '研究したときの相性の上乗せが +0.4。', 4, SpecialCategory.team),
  timeoutMaster('タイムアウトの名手', '大会のタイムアウトが1回増える。', 4, SpecialCategory.team),
  gameMaker('ゲームメイカー', '大会の味方の強さ +0.7。', 5, SpecialCategory.team),
  captainSense('キャプテンの器', '大会の味方の強さ +0.5(さらに)。', 5, SpecialCategory.team,
      requires: Special.gameMaker),
  moodMaker('ムードメーカー', 'チームワークが薄れる速さが半分になる。', 3, SpecialCategory.team),
  popular('人望', '交流・練習試合でのチームワークの上がりが +50%。', 4, SpecialCategory.team),
  favorite('コーチの愛弟子', '練習でのコーチとの信頼の上がりが2倍。', 3, SpecialCategory.team),

  // ── プロの世界 ──
  scoutEye('スカウトの目に留まる', 'プロ契約の評価点 +3。', 4, SpecialCategory.pro),
  fanFavorite('人気者', 'スポンサー契約が +20%。', 4, SpecialCategory.pro),
  negotiator('交渉上手', '契約更改で年俸が +10%。', 4, SpecialCategory.pro);

  const Special(this.label, this.description, this.cost, this.category,
      {this.requires, this.kind = SpecialKind.passive});

  final String label;
  final String description;

  /// 習得に要る特殊能力ポイント。
  final int cost;
  final SpecialCategory category;

  /// 先に習得しておく必要がある能力。
  final Special? requires;
  final SpecialKind kind;

  static Special? parse(String? s) {
    for (final v in values) {
      if (v.name == s) return v;
    }
    return null;
  }
}

/// 習得できるか(ポイントが足り、前提の能力があり、まだ持っていない)。
bool canLearn(Set<Special> have, int sp, Special s) =>
    !have.contains(s) &&
    sp >= s.cost &&
    (s.requires == null || have.contains(s.requires));

/// 習得できない理由(できるなら null)。画面に出す。
String? whyNot(Set<Special> have, int sp, Special s) {
  if (have.contains(s)) return '習得済み';
  if (s.requires != null && !have.contains(s.requires)) {
    return '先に「${s.requires!.label}」が要る';
  }
  if (sp < s.cost) return 'ポイントが足りない(あと${s.cost - sp})';
  return null;
}

// ── 勝負どころ ──

/// 勝負どころの成功率への加算(0〜1の確率)。ゾーンは `zone` で使ったときだけ別に足す。
double specialClutchBonus(Set<Special> s) =>
    (s.contains(Special.calm) ? 0.03 : 0.0) +
    (s.contains(Special.clutchMaster) ? 0.04 : 0.0) +
    (s.contains(Special.lastShot) ? 0.03 : 0.0);

/// 勝負どころの選択ごとの加算。
double specialClutchPlayBonus(Set<Special> s, Clutch c) => switch (c) {
      Clutch.drive => s.contains(Special.driveAce) ? 0.05 : 0.0,
      Clutch.threePoint => s.contains(Special.threeAce) ? 0.05 : 0.0,
      Clutch.pass => s.contains(Special.passAce) ? 0.05 : 0.0,
      Clutch.defend => s.contains(Special.defendAce) ? 0.05 : 0.0,
      Clutch.drawFoul => s.contains(Special.foulAce) ? 0.06 : 0.0,
    };

/// ライバル戦の勝負どころの加算。
double specialRivalBonus(Set<Special> s, bool vsRival) =>
    vsRival && s.contains(Special.rivalKiller) ? 0.04 : 0.0;

/// ゾーンを使ったときの勝負どころの加算。
const zoneBonus = 0.12;

// ── 試合運び ──

/// ファウルの数の倍率。
double specialFoulMultiplier(Set<Special> s) =>
    s.contains(Special.ironWall) ? 0.75 : 1.0;

/// 勢い(連勝・連敗)の効きの倍率。
double specialMomentumMultiplier(Set<Special> s) =>
    s.contains(Special.fireSpirit) ? 1.5 : 1.0;

/// ハーフタイムの相性の効きの倍率。
double specialFitMultiplier(Set<Special> s) =>
    s.contains(Special.allSeeing) ? 1.3 : 1.0;

/// 研究(分析)したときの相性の上乗せへの加算。
double specialScoutBonus(Set<Special> s) =>
    s.contains(Special.analyst) ? 0.4 : 0.0;

/// 大会のタイムアウトの増える回数。
int specialExtraTimeouts(Set<Special> s) =>
    s.contains(Special.timeoutMaster) ? 1 : 0;

// ── 育成 ──

/// 練習での伸びの倍率(伸びる年だけ)。能力ごとの特訓も含む。
double specialGrowthMultiplier(Set<Special> s, Ability a) {
  var m = s.contains(Special.prodigy) ? 1.05 : 1.0;
  bool any(Special x, List<Ability> l) => s.contains(x) && l.contains(a);
  if (any(Special.shooterTraining,
      [Ability.threePoint, Ability.midRange, Ability.freeThrow])) {
    m *= 1.12;
  }
  if (any(Special.slashTraining, [Ability.inside, Ability.dribble])) m *= 1.12;
  if (any(Special.passTraining, [Ability.pass])) m *= 1.15;
  if (any(Special.defenseTraining, [Ability.defense, Ability.speed])) m *= 1.12;
  if (any(Special.reboundNose, [Ability.rebound, Ability.inside])) m *= 1.12;
  if (any(Special.bodyMaking,
      [Ability.physical, Ability.stamina, Ability.speed])) {
    m *= 1.12;
  }
  return m;
}

/// 衰え(能力が下る年)の倍率。
double specialDeclineMultiplier(Set<Special> s) =>
    s.contains(Special.longevity) ? 0.8 : 1.0;

// ── 体と心 ──

/// 疲れの回復(マイナスの疲労変化)の倍率。
double specialRecoveryMultiplier(Set<Special> s) =>
    s.contains(Special.resilience) ? 1.25 : 1.0;

/// 怪我の確率の倍率。
double specialInjuryMultiplier(Set<Special> s) =>
    s.contains(Special.ironBody) ? 0.7 : 1.0;

/// 気持ちが下がる量・上がる量の倍率。
double specialMoraleLossMultiplier(Set<Special> s) =>
    s.contains(Special.resetMind) ? 0.7 : 1.0;
double specialMoraleGainMultiplier(Set<Special> s) =>
    s.contains(Special.positive) ? 1.25 : 1.0;

// ── チーム ──

/// 大会の味方の強さへの加算。
double specialTeamBonus(Set<Special> s) =>
    (s.contains(Special.gameMaker) ? 0.7 : 0.0) +
    (s.contains(Special.captainSense) ? 0.5 : 0.0);

/// チームワークが毎ターン薄れる量(特性のキャプテンシーとは重ねず、小さいほうを取る)。
int specialTeamworkDecay(Set<Special> s, int base) =>
    s.contains(Special.moodMaker) ? (base / 2).ceil().clamp(0, base) : base;

/// 交流・練習試合でのチームワークの上がりの倍率。
double specialTeamworkGainMultiplier(Set<Special> s) =>
    s.contains(Special.popular) ? 1.5 : 1.0;

/// 練習でのコーチとの信頼の上がり(1回あたり)。
int specialCoachGain(Set<Special> s) => s.contains(Special.favorite) ? 2 : 1;

// ── プロの世界 ──

/// プロ契約の評価点への加算。
double specialOfferBonus(Set<Special> s) =>
    s.contains(Special.scoutEye) ? 3.0 : 0.0;

/// スポンサー契約・年俸の倍率。
double specialSponsorMultiplier(Set<Special> s) =>
    s.contains(Special.fanFavorite) ? 1.2 : 1.0;
double specialSalaryMultiplier(Set<Special> s) =>
    s.contains(Special.negotiator) ? 1.1 : 1.0;

// ── ポイント ──

/// 年末に得られる特殊能力ポイント: 毎年1、目標達成+1、優勝+1。夢がかなったときは別に+2。
int spForYear({required bool goalAchieved, required bool champion}) =>
    1 + (goalAchieved ? 1 : 0) + (champion ? 1 : 0);

const dreamSp = 2;

/// 習得の優先順(おまかせ・測定ツール用)。安くて広く効くものから。
const learnPriority = [
  Special.calm,
  Special.prodigy,
  Special.ironWall,
  Special.clutchMaster,
  Special.resilience,
  Special.ironBody,
  Special.gameMaker,
  Special.allSeeing,
  Special.shooterTraining,
  Special.slashTraining,
  Special.defenseTraining,
  Special.passTraining,
  Special.bodyMaking,
  Special.reboundNose,
  Special.scoutEye,
  Special.popular,
  Special.favorite,
  Special.resetMind,
  Special.positive,
  Special.fireSpirit,
  Special.moodMaker,
  Special.analyst,
  Special.timeoutMaster,
  Special.captainSense,
  Special.lastShot,
  Special.longevity,
  Special.driveAce,
  Special.threeAce,
  Special.passAce,
  Special.defendAce,
  Special.foulAce,
  Special.rivalKiller,
  Special.fanFavorite,
  Special.negotiator,
  Special.zone,
];
