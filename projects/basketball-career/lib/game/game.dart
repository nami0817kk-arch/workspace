import 'dart:math';

import 'build.dart';
import 'career.dart';
import 'difficulty.dart';
import 'dream.dart';
import 'events.dart';
import 'goals.dart';
import 'honors.dart';
import 'life.dart';
import 'mastery.dart';
import 'match.dart';
import 'money.dart';
import 'path.dart';
import 'player.dart';
import 'rival.dart';
import 'skills.dart';
import 'special.dart';
import 'season.dart';
import 'traits.dart';

/// 画面が見る局面。対応する操作だけを呼ぶ。
enum Phase { season, halftime, clutch, event, path, retired }

/// どこでプレーしているか。
enum Track { school, university, corporate, pro }

/// リーグの呼び名(知らせの文に使う)。
String leagueLabelOf(League l) => l.label;

/// 大会のベストゲームを一言で(得点＋リバウンド＋アシスト×1.5、勝ちは+5で比べる)。試合が無ければ空。
String bestGameOf(List<MatchResult> ms) {
  if (ms.isEmpty) return '';
  double score(MatchResult m) =>
      m.points + m.rebounds + m.assists * 1.5 + (m.won ? 5 : 0);
  final b = ms.reduce((a, c) => score(c) > score(a) ? c : a);
  final parts = [
    '${b.points}点',
    if (b.rebounds >= 5) '${b.rebounds}リバウンド',
    if (b.assists >= 5) '${b.assists}アシスト',
  ];
  return '${parts.join('')}${b.opponent.isEmpty ? '' : ' vs ${b.opponent}'}(${b.won ? '勝ち' : '負け'})';
}

/// 1年の大会の記録。
class YearRecord {
  const YearRecord({
    required this.age,
    required this.league,
    required this.wins,
    required this.games,
    required this.ppg,
    required this.rpg,
    required this.apg,
    required this.champion,
    required this.achievement,
    this.winter = false,
    this.award,
    this.steals = 0,
    this.blocks = 0,
    this.threes = 0,
    this.highPoints = 0,
    this.honors = const [],
    this.box = const BoxScore(),
    this.benchGames = 0,
    this.bestGame = '',
  });

  /// その大会のベストゲーム(「34点12リバウンド vs ○○(勝ち)」)。古いセーブは空。
  final String bestGame;

  /// 控え(ベンチスタート)で出た試合の数。古いセーブは0。
  final int benchGames;

  /// その大会のボックススコアの合計(シュートの本数・フリースロー・出場時間)。古いセーブは空。
  final BoxScore box;

  final int age;
  final League league;
  final int wins;
  final int games;
  final double ppg;
  final double rpg;
  final double apg;
  final bool champion;
  final double achievement;

  /// 冬の大会の記録か。
  final bool winter;

  /// その大会の個人賞(最優秀選手・ベスト5)。なければ null。
  final String? award;

  /// その大会の合計(スティール・ブロック・3P)と、1試合の最多得点。
  final int steals;
  final int blocks;
  final int threes;
  final int highPoints;

  /// その大会で受けた表彰(得点王・新人王・オールスターなど。`Honor`)。
  final List<String> honors;

  Map<String, dynamic> toJson() => {
        'honors': honors,
        'box': box.toJson(),
        'bench': benchGames,
        'best': bestGame,
        'winter': winter,
        'award': award,
        'steals': steals,
        'blocks': blocks,
        'threes': threes,
        'highPoints': highPoints,
        'age': age,
        'league': league.name,
        'wins': wins,
        'games': games,
        'ppg': ppg,
        'rpg': rpg,
        'apg': apg,
        'champion': champion,
        'achievement': achievement,
      };

  factory YearRecord.fromJson(Map<String, dynamic> j) => YearRecord(
        age: (j['age'] as num?)?.toInt() ?? 0,
        league: League.values.firstWhere(
          (l) => l.name == j['league'],
          orElse: () => League.minibasket,
        ),
        wins: (j['wins'] as num?)?.toInt() ?? 0,
        games: (j['games'] as num?)?.toInt() ?? 0,
        ppg: (j['ppg'] as num?)?.toDouble() ?? 0,
        rpg: (j['rpg'] as num?)?.toDouble() ?? 0,
        apg: (j['apg'] as num?)?.toDouble() ?? 0,
        champion: (j['champion'] as bool?) ?? false,
        achievement: (j['achievement'] as num?)?.toDouble() ?? 0,
        winter: (j['winter'] as bool?) ?? false,
        award: j['award'] as String?,
        steals: (j['steals'] as num?)?.toInt() ?? 0,
        blocks: (j['blocks'] as num?)?.toInt() ?? 0,
        threes: (j['threes'] as num?)?.toInt() ?? 0,
        highPoints: (j['highPoints'] as num?)?.toInt() ?? 0,
        honors: [for (final v in (j['honors'] as List?) ?? const []) v as String],
        box: BoxScore.fromJson((j['box'] as Map?)?.cast<String, dynamic>()),
        benchGames: (j['bench'] as num?)?.toInt() ?? 0,
        bestGame: (j['best'] as String?) ?? '',
      );
}

/// 年ごとの成長の記録(成長の軌跡のグラフに使う)。
class GrowthPoint {
  const GrowthPoint(this.age, this.overall, this.heightCm);
  final int age;
  final double overall;
  final double heightCm;

  Map<String, dynamic> toJson() =>
      {'age': age, 'overall': overall, 'heightCm': heightCm};

  factory GrowthPoint.fromJson(Map<String, dynamic> j) => GrowthPoint(
        (j['age'] as num?)?.toInt() ?? 0,
        (j['overall'] as num?)?.toDouble() ?? 0,
        (j['heightCm'] as num?)?.toDouble() ?? 0,
      );
}

/// `choose` 1回の結果。画面はこれを見て演出する。
class TermReport {
  const TermReport({
    required this.action,
    required this.gotInjured,
    this.tournament,
    this.satOut = false,
    this.yearEnded = false,
    this.paused = false,
  });

  final Action action;
  final bool gotInjured;

  /// 夏の大会の結果。大会の無い季節、出られなかった年は null。
  final TournamentResult? tournament;

  /// 怪我で大会に出られなかった。
  final bool satOut;
  final bool yearEnded;

  /// 勝負どころで止まっている(大会はまだ終わっていない)。
  final bool paused;
}

const _recentCount = 4;

/// 人気の背番号(はじめの画面の候補と、ランダムの抽選に使う)。
const popularNumbers = [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 23, 24, 30, 32, 33, 34];

/// 選手育成ゲームの本体。画面に依存しない。
///
/// 1年 = 春夏秋冬の4回の `choose`。夏(slot 1)の `choose` の中で大会が行われる。
/// 高校卒業(19歳)と、大学・実業団の卒業で `Phase.path` になり、`chooseRoute` / `giveUp` を呼ぶ。
/// プロでは `goAbroad` / `retire` も呼べる。段階に合わない操作は `StateError`。
class Game {
  Game({
    required this.player,
    Random? rng,
    this.condition = const Condition(),
    this.track = Track.school,
    this.collegeYearsLeft = 0,
    this.abroad = false,
    this.secondChance = false,
    this.proRejected = false,
    this.pathPending = false,
    this.retiredReason,
    this.lowYears = 0,
    this.archived = false,
    this.recoveredThisTerm = false,
    this.teamwork = 40,
    this.coachBond = 20,
    this.rivalMet = false,
    this.nationalPending = false,
    this.draftPick = 0,
    this.injuredStreak = 0,
    this.habit = 0,
    this.buildLabel = '',
    Set<String>? buildsSeen,
    this.comebackPending = false,
    this.salary = 0,
    this.sponsor = 0,
    this.totalEarnings = 0,
    this.caps = 0,
    this.number = 0,
    this.mate = '',
    this.teamName = '',
    this.coachLabel = '',
    List<Action>? recentActions,
    this.schoolBonus = 0,
    this.schoolLabel = '',
    List<String>? recentEventIds,
    List<GrowthPoint>? growthLog,
    this.run,
    this.runWinter = false,
    this.termAction = Action.practice,
    this.termInjured = false,
    this.slot = 0,
    Rival? rival,
    this.difficulty = Difficulty.normal,
    List<Goal>? goalOptions,
    this.goal,
    Map<Ability, int>? goalStart,
    this.goalRivalWins = 0,
    this.yearBestWins = 0,
    this.yearBestPpg = 0,
    this.lastGoalMessage,
    this.pendingEventId,
    this.lastFocus = Ability.threePoint,
    this.eventsEnabled = true,
    List<double>? recentAchievements,
    List<YearRecord>? records,
    this.dream = Dream.pro,
    this.dreamAge = 0,
    this.sp = 0,
    this.positionAuto = true,
    Map<Ability, int>? yearStart,
    Map<Ability, int>? mastery,
  })  : rng = rng ?? Random(),
        rival = rival ?? Rival(name: 'ライバル', potential: 60),
        recentEventIds = recentEventIds ?? [],
        growthLog = growthLog ?? [],
        recentActions = recentActions ?? [],
        buildsSeen = buildsSeen ?? {},
        goalOptions = goalOptions ?? [],
        goalStart = goalStart ?? {},
        yearStart = yearStart ?? {},
        mastery = mastery ?? {},
        recentAchievements = recentAchievements ?? [],
        records = records ?? [];

  /// 新しく始める。素質・身長の素質・生まれつきの特性を引く。
  factory Game.start(String name,
      {Random? rng,
      bool events = true,
      Difficulty difficulty = Difficulty.normal,
      int legacyBonus = 0,
      Dream dream = Dream.pro,
      Build? style,
      Set<Trait>? traits,
      int? number}) {
    final r = rng ?? Random();
    final potential = (30 + r.nextInt(40) + r.nextInt(31)).clamp(30, 100);
    final first = newPlayer(
            name, potential, r.nextDouble(), traits ?? rollInnateTraits(r),
            bonus: legacyBonus)
        .copyWith(style: style);
    final g = Game(
      // ポジションは節目にしか見直さない(身長や能力が動くたびに入れ替わって弱くならないように)。
      player: first.copyWith(positionLock: first.suggestedPosition),
      rival: Rival.random(r),
      difficulty: difficulty,
      dream: dream,
      rng: r,
      eventsEnabled: events,
      number: number ?? popularNumbers[r.nextInt(popularNumbers.length)],
    );
    g._rollGoalOptions();
    g._newTeamNames();
    return g;
  }

  final Random rng;

  /// 同じ時代を走るライバル。
  final Rival rival;

  /// 難しさ(始めるときに決める)。
  final Difficulty difficulty;

  /// 年のはじめに出る目標の候補。選ぶと `goal` になる(選ばなくてもよい)。
  List<Goal> goalOptions;
  Goal? goal;

  /// 目標を選んだ時点の能力・ライバルへの勝ち数(達成の判定に使う)。
  Map<Ability, int> goalStart;

  /// 年のはじめの能力(能力の画面に「今年 +n」を出すため。保存あり。古いセーブは空=差を出さない)。
  Map<Ability, int> yearStart;

  /// 能力ごとの熟練度の累計(`mastery.dart`。保存あり。古いセーブは空=0から)。
  Map<Ability, int> mastery;

  /// 直前のターンで熟練の段が上がった能力と、その新しい段(画面が見せる。保存しない)。
  List<(Ability, int)> lastMasteryUps = const [];

  int masteryOf(Ability a) => masteryLevel(mastery[a] ?? 0);

  /// 重点にした能力へ熟練度を足し、段が上がればごほうびを当てる。
  void _addMastery(Action action, Ability focus, Ability? focus2, bool injured) {
    final g = masteryGain(action, injured: injured);
    final ups = <(Ability, int)>[];
    var ab = player.abilities;
    for (final (a, n) in [(focus, g.first), if (focus2 != null && focus2 != focus) (focus2, g.second)]) {
      if (n <= 0) continue;
      final before = masteryLevel(mastery[a] ?? 0);
      mastery[a] = (mastery[a] ?? 0) + n;
      final after = masteryLevel(mastery[a]!);
      for (var lv = before + 1; lv <= after; lv++) {
        ups.add((a, lv));
        ab = {...ab, a: ((ab[a] ?? 0) + masteryAbilityBonus(lv)).clamp(0, abilityCap)};
        sp += masterySp(lv);
      }
    }
    if (ups.isNotEmpty) player = player.copyWith(abilities: ab);
    lastMasteryUps = ups;
  }

  int goalRivalWins;

  /// 今年の大会での最多勝ち数・最高の平均得点(目標の判定に使う)。
  int yearBestWins;
  double yearBestPpg;

  /// 直近の年末の、目標の結果の言葉(画面が見せたら消す)。
  String? lastGoalMessage;

  /// 直近の大会で受けた表彰(画面に出す。保存はしない。記録は `YearRecord.honors`)。
  List<String> lastHonors = const [];
  Player player;
  Condition condition;
  Track track;
  int collegeYearsLeft;
  bool abroad;

  /// 大学・実業団を経た(再挑戦は1度だけ)。
  bool secondChance;

  /// 今の進路選択でプロ契約に落ちた。
  bool proRejected;
  bool pathPending;
  String? retiredReason;
  int lowYears;

  /// 殿堂に書き込み済みか(引退のとき1度だけ)。
  bool archived;

  /// このターンに回復を使ったか(1ターンに1回まで)。
  bool recoveredThisTerm;

  /// チームワーク 0〜100。仲間との息の合い方で、大会での味方の強さが±4ほど変わる。
  /// 交流・練習試合で上がり、進学・移籍で新しいチームになると40に戻る。
  int teamwork;

  /// コーチとの信頼 0〜100。練習・特訓で少しずつ増え、高いと伸びに最大+20%。
  /// 進学・移籍で新しいコーチになると20に戻る。
  int coachBond;

  /// 進学先の環境(大会の味方の強さへの上乗せ)と、その呼び名。段階が変わると決め直す。
  double schoolBonus;
  String schoolLabel;

  /// 信頼による伸びの倍率。
  double get coachBoost => 1 + coachBond / 500;

  /// 進行中の大会(勝負どころで止まっているときだけ残る)。
  TournamentRun? run;
  bool runWinter;

  /// 大会の途中で止まっているターンの過ごし方と、そのターンの怪我。
  Action termAction;
  bool termInjured;

  /// 直近に終えたターンの結果(勝負どころで止まった後、続きを終えたときの結果もここに入る)。
  TermReport? lastReport;
  int slot;

  /// チームメイトの名前とコーチの名前(段階が変わると替わる。出来事の文に入る)。
  String mate;

  /// いま所属しているチームの名前(架空。進学・移籍・プロ入り・海外挑戦で変わる)。古いセーブは空。
  String teamName;

  /// 画面に出すチームの名前(古いセーブで空なら「自チーム」)。
  String get teamLabel => teamName.isEmpty ? '自チーム' : teamName;
  String coachLabel;

  /// プロ契約のときのドラフト指名順位(1〜60)。0 は指名なし(古いセーブ・プロ以外)。
  int draftPick;

  /// 長い怪我が治ったターンで true(復帰の出来事を起こしたら戻す)。大会の途中で保存しても残る。
  bool comebackPending;

  /// いまのビルド(型とティア)の表示名。変わったときだけ知らせるために覚えておく。ビルドなしは空。
  String buildLabel;

  /// これまでに到達したビルドとティア(`Build.name:tier`)。図鑑に使う。
  final Set<String> buildsSeen;

  /// 直近のターンでビルドが決まった・変わったときの知らせ(画面に出す。保存はしない)。
  String? lastBuildNote;

  int _buildCool = 0;

  /// 幼少期(17歳まで)の生活習慣(-10〜+10)。睡眠・食事・外遊び・無理のしすぎで動き、身長の伸びに±10%まで効く。
  double habit;

  /// いまの怪我で、続けて休んだターン数(長い怪我から復帰したとき出来事を起こす)。
  int injuredStreak;

  /// プロの年俸(万円)。プロ以外は 0。1年目は新人契約、年の終わりの契約更改で変わる。
  int salary;

  /// スポンサー契約の年収(万円)。人気(表彰・優勝・華がある・上位指名・日本代表・海外)で決まる。年俸とは別に毎年入る。
  int sponsor;

  /// 直近の年の終わりの、スポンサー契約の知らせ(新しく付いた・増えた)。画面に出す。保存はしない。
  String? lastSponsorNote;

  /// プロでもらった年俸とスポンサー収入の合計(万円)。
  int totalEarnings;

  /// 直近の年の終わりの、契約更改の知らせ(年俸アップ・ダウン)。画面に出す。保存はしない。
  String? lastSalaryNote;

  /// 直近の大会で超えた通算記録の節目(「通算1000得点を達成!」など)。画面に出す。保存はしない。
  List<String> lastCareerLines = const [];

  /// 通算記録の節目(得点・リバウンド・アシスト)。
  static const careerLadder = <String, List<int>>{
    '得点': [500, 1000, 2000, 3000],
    'リバウンド': [300, 600, 1000, 1500],
    'アシスト': [200, 500, 800, 1000],
  };

  /// 日本代表に参加することにした(次の冬に世界大会に出る)。
  bool nationalPending;

  /// 日本代表として出た世界大会の回数。
  int caps;

  /// 背番号(0〜99)。ユニフォームに付き、活躍すると永久欠番になる。
  int number;

  /// ライバルとはじめて対戦したか(出会いの演出を1度だけ出すため)。
  bool rivalMet;

  /// 直前のターンで、ライバルとはじめて出会った。
  bool lastMetRival = false;

  /// 直前の操作で新しく身についた得意技(画面が知らせたら使い終わり)。
  Set<Skill> lastNewSkills = {};

  /// 始めるときに決めた夢(一生の目標)。かなった年齢は `dreamAge`(0 はまだ)。保存あり。
  final Dream dream;
  int dreamAge;

  /// ポジションを節目(13・16・19・22歳)に自動で見直すか。自分で選んで固定したら false(保存あり)。
  bool positionAuto;

  /// 控えから先発になった知らせ(画面が知らせたら使い終わり。保存しない)。
  String? lastRoleNote;

  /// 直前に起きたポジションの変更の知らせ(画面が知らせたら使い終わり。保存しない)。
  String? lastPositionNote;

  /// ポジションを見直す年齢。身長が大きく動く時期の節目と、プロに入る前後だけ。
  static const positionReviewAges = {13, 16, 19, 22};

  /// ポジションを見直す(おまかせのときだけ)。変わったら知らせる。
  void _reviewPosition() {
    if (!positionAuto) return;
    final now = player.suggestedPosition;
    if (now == player.positionLock) return;
    final before = player.positionLock;
    player = player.copyWith(positionLock: now);
    if (before != null) {
      lastPositionNote =
          'ポジションが ${before.label} から ${now.label} に変わった(身長と能力の変化で)。${now.perk}';
    }
  }

  /// ポジションを自分で選ぶ。null でおまかせ(いまのおすすめに合わせ、節目ごとに見直す)。
  /// 選ぶと、そのポジションで固定される(総合評価の重みもそのポジションのもの)。
  void setPosition(Position? p) {
    if (phase == Phase.retired) throw StateError('引退後は変えられない');
    if (p == null) {
      positionAuto = true;
      player = player.copyWith(positionLock: player.suggestedPosition);
    } else {
      positionAuto = false;
      player = player.copyWith(positionLock: p);
    }
  }

  /// 特殊能力ポイント(年末にたまる。`learnSpecial` で使う。保存あり)。
  int sp;

  /// 直前の年末に得たポイント(画面が見せたら使い終わり。保存しない)。
  int lastSpGain = 0;

  /// 特殊能力ポイントを増やす(動画を見たごほうび)。
  void grantSp(int n) {
    if (phase == Phase.retired) throw StateError('引退後はもらえない');
    sp += n;
  }

  /// 特殊能力を習得する。ポイントと前提が足りなければ `StateError`。
  void learnSpecial(Special s) {
    if (phase == Phase.retired) throw StateError('引退後は習得できない');
    final why = whyNot(player.specials, sp, s);
    if (why != null) throw StateError('習得できない: ${s.label}($why)');
    sp -= s.cost;
    player = player.copyWith(specials: {...player.specials, s});
  }

  /// 直前の操作で夢がかなった知らせ(画面が知らせたら使い終わり。保存しない)。
  String? lastDreamNote;

  /// 直前の過ごし方で動いた能力と、その量(能力の画面で「今回 +n」を出す。保存しない)。
  Map<Ability, int> lastGains = {};

  /// 直前の年末の「今年の成長」のまとめ(画面が見せたら使い終わり。保存しない)。
  String? lastYearSummary;

  /// 年のはじめと今の能力を比べて、今年の成長を一言にまとめる(年のはじめの記録が無ければ null)。
  String? _yearSummary() {
    if (yearStart.isEmpty) return null;
    final base = player.copyWith(abilities: {
      for (final a in Ability.values) a: yearStart[a] ?? player.of(a),
    });
    var topGain = 0;
    Ability? top;
    for (final a in Ability.values) {
      final d = player.of(a) - (yearStart[a] ?? player.of(a));
      if (d > topGain) {
        topGain = d;
        top = a;
      }
    }
    final before = base.overall.round(), now = player.overall.round();
    // この年の記録はまだ growthLog に入っていない(最後は前の年の終わり)。
    final grew =
        growthLog.isEmpty ? 0.0 : player.heightCm - growthLog.last.heightCm;
    // 今年の大会(夏・冬)のベストゲーム。
    final best = records
        .where((r) => r.age == player.age && r.bestGame.isNotEmpty)
        .map((r) => r.bestGame)
        .lastOrNull;
    return '今年の成長: 総合 $before → $now(${now - before >= 0 ? '+' : ''}${now - before})'
        '${top == null ? '' : ' / いちばん伸びた能力 ${top.label} +$topGain'}'
        '${grew >= 0.5 ? ' / 身長 +${grew.toStringAsFixed(1)}cm' : ''}'
        '${best == null ? '' : ' / 今年のベストゲーム: $best'}';
  }

  DreamStats get dreamStats => DreamStats(
        turnedPro: track == Track.pro,
        points: totalPoints,
        titles: titles,
        honors: honorTotal,
        caps: caps,
      );

  /// 夢の進み具合(0〜1)。かなっていれば1。
  double get dreamProgress =>
      dreamAge > 0 ? 1.0 : dream.progress(dreamStats);

  /// 夢がかなったかを見る。かなった瞬間に1度だけ、全能力+1と気持ちのごほうびを与えて知らせる。
  void _checkDream() {
    if (dreamAge > 0 || !dream.achieved(dreamStats)) return;
    dreamAge = player.age;
    sp += dreamSp;
    player = player.copyWith(abilities: {
      for (final e in player.abilities.entries)
        e.key: (e.value + Dream.rewardAbilityBonus).clamp(0, abilityCap),
    });
    condition = condition.copyWith(morale: condition.morale + Dream.rewardMorale);
    lastDreamNote =
        '夢「${dream.label}」がかなった! ごほうび: 全能力 +${Dream.rewardAbilityBonus}、気持ち +${Dream.rewardMorale}、特殊能力ポイント +$dreamSp';
  }

  /// 目指すプレースタイルを選ぶ・変える(null でおまかせ)。育成中いつでも変えられる。
  /// 選んだ型に効く能力は伸びやすくなる(`styleGrowthMultiplier`)。変えても、いまの能力は変わらない。
  void setStyle(Build? style) {
    if (phase == Phase.retired) throw StateError('引退後は変えられない');
    player = player.copyWith(style: style, clearStyle: style == null);
    buildLabel = buildOf(player)?.label ?? '';
  }

  /// 条件を満たした得意技を身につける。新しく身についたものを返す。
  /// 能力が変わったあとに、ビルド(型とティア)を見直す。変わったら知らせる。
  /// 境目でころころ変わって知らせすぎないよう、知らせたあと2ターンは黙る。
  void _updateBuild() {
    final b = buildOf(player);
    final label = b == null ? '' : b.label;
    if (b != null) buildsSeen.add('${b.build.name}:${b.tier}');
    if (_buildCool > 0) _buildCool--;
    if (label.isNotEmpty && label != buildLabel && _buildCool == 0) {
      lastBuildNote = buildLabel.isEmpty
          ? 'ビルドが決まった: $label'
          : 'ビルドが変わった: $label';
      _buildCool = 2;
    }
    buildLabel = label;
  }

  Set<Skill> _learnSkills() {
    final n = newlyQualified(player);
    if (n.isNotEmpty) {
      player = player.copyWith(skills: {...player.skills, ...n});
      lastNewSkills = {...lastNewSkills, ...n};
    }
    return n;
  }

  /// 直前のターンがマンネリだったか(画面の知らせ用)。
  bool lastWasRut = false;

  /// 直近の過ごし方(同じ練習が続くと効きが落ちる「マンネリ」の判定に使う)。
  final List<Action> recentActions;

  /// 同じ練習を3回続けると、伸びが0.85倍になる。
  static const slumpScale = 0.85;

  /// 次に `a` を選ぶとマンネリか(練習・特訓・研究・練習試合を、直近2回と同じで選ぶ)。
  bool isRut(Action a) =>
      a != Action.rest &&
      a != Action.social &&
      recentActions.length >= 2 &&
      recentActions[recentActions.length - 1] == a &&
      recentActions[recentActions.length - 2] == a;

  /// 年ごとの成長の記録(年末に1つ足す)。
  final List<GrowthPoint> growthLog;

  /// 最近起きた出来事の id(同じものが続かないように)。
  final List<String> recentEventIds;

  /// 起きている出来事(選ぶまで次へ進めない)。
  String? pendingEventId;

  /// 直近に重点にした能力(出来事の効果で使う)。
  Ability lastFocus;

  /// 出来事を起こすか。テストでは切って、出来事なしの流れを固定する。
  final bool eventsEnabled;
  final List<double> recentAchievements;
  final List<YearRecord> records;

  bool get retired => retiredReason != null;

  Phase get phase => retired
      ? Phase.retired
      : pathPending
          ? Phase.path
          : (run?.pendingHalf != null)
              ? Phase.halftime
              : (run?.pending != null)
                  ? Phase.clutch
                  : pendingEventId != null
                      ? Phase.event
                      : Phase.season;

  /// 出来事の文中の {rival} をライバルの名前にする。
  String fill(String s) => s
      .replaceAll('{rival}', rival.name)
      .replaceAll('{mate}', mate.isEmpty ? '仲間' : mate)
      .replaceAll('{coach}', coachLabel.isEmpty ? 'コーチ' : '$coachLabelコーチ');

  /// 新しいチームになったときに、チームメイトとコーチの名前を引き直す。
  void _newTeamNames() {
    mate = mateName(rng);
    coachLabel = coachName(rng);
    teamName = opponentTeamName(league, rng);
  }

  EventDef? get pendingEvent =>
      pendingEventId == null ? null : eventById(pendingEventId!);

  Stage get stage {
    if (retired) return Stage.retired;
    return switch (track) {
      Track.pro => Stage.pro,
      Track.university || Track.corporate => Stage.college,
      Track.school => pathPending
          ? Stage.pathChoice
          : stageOf(player.age),
    };
  }

  League get league => switch (stage) {
        Stage.minibasket => League.minibasket,
        Stage.juniorHigh => League.juniorHigh,
        Stage.college =>
          track == Track.corporate ? League.corporate : League.university,
        Stage.pro => abroad ? League.proAbroad : League.proDomestic,
        _ => League.highSchool,
      };

  /// 大会での動きの良さ(体調に、SFの持ち味を足す)。
  double get formNow =>
      condition.form + (player.position == Position.smallForward ? 0.03 : 0.0);

  /// チームワークによる味方の強さの上乗せ。パスが上手いほど効きが大きい。
  /// 大会の直前(この季節か前の季節)に研究をしていれば、相手を分析済み(相性の良い作戦が +0.6)。
  double get scoutBonus =>
      recentActions.reversed.take(2).contains(Action.study)
          ? 0.6 + specialScoutBonus(player.specials)
          : 0.0;

  double get teamBonus =>
      (teamwork - 50) *
      0.07 *
      (0.7 + player.of(Ability.pass) / 200) *
      (player.position == Position.pointGuard ? 1.4 : 1.0) +
      player.skills.fold(0.0, (s, k) => s + k.teamBonus) +
      traitTeamBonus(player.traits) +
      buildTeamBonus(player) +
      specialTeamBonus(player.specials);

  /// 冬の大会(全国選手権)がある段階。高校と大学・実業団。
  bool get hasWinterCup => stage == Stage.highSchool || stage == Stage.college;

  /// いまのプロ契約の評価点と見込み(進路の前に位置を伝える)。
  double get offerNow => offerScore(player, achievement);
  Outlook get outlook => outlookOf(offerNow);

  /// 直近の大会の実績の平均(進路の評価に使う)。まだ無ければ 30。
  double get achievement => recentAchievements.isEmpty
      ? 30
      : recentAchievements.reduce((a, b) => a + b) / recentAchievements.length;

  /// 進路で選べるもの。プロに落ちた直後は大学・実業団だけ、再挑戦ではプロだけ。
  List<Route> get availableRoutes => [
        if (!proRejected) Route.pro,
        if (!secondChance) ...[Route.university, Route.corporate],
      ];

  bool get canGoAbroad =>
      phase == Phase.season &&
      track == Track.pro &&
      !abroad &&
      pathCanGoAbroad(player);

  // ── 季節 ──

  /// 季節を1つ進める。`focus` は練習・特訓・研究の重点の能力(他の過ごし方では無視)。
  TermReport choose(
    Action action,
    Ability focus, {
    Ability? focus2,
    Clutch Function(int margin)? chooseClutch,
    bool askClutch = false,
    bool askHalftime = false,
  }) {
    if (phase != Phase.season) throw StateError('今は季節を選べない: $phase');
    lastFocus = focus;
    recoveredThisTerm = false;
    lastGoalMessage = null;
    lastHonors = const [];
    lastSalaryNote = null;
    lastSponsorNote = null;
    lastBuildNote = null;
    lastDreamNote = null;
    lastYearSummary = null;
    lastPositionNote = null;
    lastRoleNote = null;
    lastTournamentFatigue = 0;
    lastSpGain = 0;
    lastCareerLines = const [];
    lastMetRival = false;
    lastNewSkills = {};
    lastMasteryUps = const [];
    final rut = isRut(action);
    final wasInjured = condition.injured;
    final abilitiesBefore = Map<Ability, int>.of(player.abilities);
    final r = playTerm(player, condition, action, focus, rng,
        focus2: focus2,
        growthScale: difficulty.growth * coachBoost * (rut ? slumpScale : 1.0));
    recentActions.add(action);
    while (recentActions.length > 3) {
      recentActions.removeAt(0);
    }
    lastWasRut = rut;
    player = r.player;
    _addMastery(action, focus, focus2, wasInjured || r.gotInjured);
    lastGains = {
      for (final a in Ability.values)
        if (player.of(a) != abilitiesBefore[a]) a: player.of(a) - abilitiesBefore[a]!,
    };
    condition = r.condition;
    // 長い怪我(3ターン以上)から治ったら、復帰の出来事が起きる。
    if (condition.injured) {
      injuredStreak++;
    } else {
      comebackPending = wasInjured && injuredStreak >= 3;
      injuredStreak = 0;
    }
    if (player.age <= 17) {
      habit = (habit + habitDelta(action, condition.fatigue)).clamp(-10.0, 10.0);
    }
    termAction = action;
    termInjured = r.gotInjured;
    _learnSkills();
    _updateBuild();
    _checkDream();
    // 何もしなければ少しずつ薄れる(毎ターン -2)。交流・練習試合で保つ。
    teamwork = (teamwork +
            switch (action) {
              Action.social =>
                (12 * specialTeamworkGainMultiplier(player.specials)).round(),
              Action.scrimmage =>
                (6 * specialTeamworkGainMultiplier(player.specials)).round(),
              _ => 0,
            } -
            specialTeamworkDecay(player.specials, teamworkDecay(player.traits)))
        .clamp(0, 100);
    if (action == Action.practice || action == Action.intense) {
      coachBond = (coachBond + specialCoachGain(player.specials)).clamp(0, 100);
    }

    final national = slot == 3 && nationalPending && track == Track.pro;
    final winter = slot == 3 && (hasWinterCup || national);
    TournamentResult? t;
    var satOut = false;
    if (slot == 1 || winter) {
      if (condition.injured) {
        satOut = true;
        if (national) nationalPending = false; // 怪我で代表を辞退
      } else {
        final cr = TournamentRun(national ? League.national : league,
            teamBonus: teamBonus + schoolBonus,
            scout: scoutBonus,
            zones: player.specials.contains(Special.zone) ? 1 : 0,
            timeouts: (national ? League.national : league).timeouts +
                specialExtraTimeouts(player.specials),
            momentumMul: specialMomentumMultiplier(player.specials),
            askHalftime: askHalftime && chooseClutch == null);
        cr.advance(
          player,
          form: formNow,
          rng: rng,
          chooseClutch: chooseClutch,
          askClutch: askClutch && chooseClutch == null,
          pickOpponent: _picker(cr.league),
        );
        if (cr.pending != null || cr.pendingHalf != null) {
          // ハーフタイムの作戦か勝負どころで止まる。選ぶまで季節は進まない(`resolveHalftime` / `resolveClutch`)。
          run = cr;
          runWinter = winter;
          lastReport = null;
          return TermReport(action: action, gotInjured: r.gotInjured, paused: true);
        }
        t = cr.result();
        _record(t, winter: winter);
      }
    }
    return lastReport = _finishTerm(action, r.gotInjured, t, satOut);
  }

  /// 勝負どころで止まっている大会に、選んだプレーを渡して続きを進める。
  /// 大会が終われば、そのターンの結果を返す。また勝負どころが来たら止まる(`paused`)。
  TermReport resolveClutch(Clutch choice) {
    final cr = run;
    if (phase != Phase.clutch || cr == null) {
      throw StateError('今は勝負どころではない: $phase');
    }
    cr.resolve(player, choice,
        form: formNow, rng: rng, pickOpponent: _picker(cr.league));
    return _afterRun(cr);
  }

  /// 勝負どころで、タイムアウトを取って作戦を練る(残りがあるときだけ。最後の攻防の成功率+5%)。
  void useTimeout() {
    final cr = run;
    final s = cr?.pending;
    if (phase != Phase.clutch || cr == null || s == null) {
      throw StateError('今は勝負どころではない: $phase');
    }
    if (s.timeout) throw StateError('この試合ではもうタイムアウトを取った');
    if (cr.timeouts <= 0) throw StateError('タイムアウトの残りがない');
    cr.timeouts--;
    cr.pending = s.withTimeout();
  }

  /// 勝負どころで、ゾーン(特殊能力)に入る(習得していて、この大会でまだ使っていないときだけ。成功率+12%)。
  void useZone() {
    final cr = run;
    final s = cr?.pending;
    if (phase != Phase.clutch || cr == null || s == null) {
      throw StateError('今は勝負どころではない: $phase');
    }
    if (s.zone) throw StateError('この試合ではもうゾーンに入っている');
    if (cr.zones <= 0) throw StateError('ゾーンは使えない');
    cr.zones--;
    cr.pending = s.withZone();
  }

  /// ハーフタイムで止まっている試合に、選んだ作戦を渡して続きを進める。
  TermReport resolveHalftime(Halftime choice) {
    final cr = run;
    if (phase != Phase.halftime || cr == null) {
      throw StateError('今はハーフタイムではない: $phase');
    }
    cr.resolveHalftime(player, choice,
        form: formNow, rng: rng, pickOpponent: _picker(cr.league));
    return _afterRun(cr);
  }

  /// 大会を進めたあと: また止まっていれば `paused`、終わっていれば記録してターンを締める。
  TermReport _afterRun(TournamentRun cr) {
    if (cr.pending != null || cr.pendingHalf != null) {
      return TermReport(
          action: termAction, gotInjured: termInjured, paused: true);
    }
    run = null;
    final t = cr.result();
    _record(t, winter: runWinter);
    return lastReport = _finishTerm(termAction, termInjured, t, false);
  }

  /// ハーフタイムで止まっている試合の前半の結果と点差。
  MatchHalf? get halftimeInfo => run?.pendingHalf;

  /// 勝負どころで止まっている試合の選択肢と成功率。
  ({int margin, double oppStrength, Map<Clutch, double> chances})? get clutchInfo {
    final s = run?.pending;
    if (s == null) return null;
    return (
      margin: s.margin,
      oppStrength: s.oppStrength,
      chances: {
        for (final c in Clutch.values)
          c: clutchChance(player, c, s.oppStrength, s.form,
              timeout: s.timeout, zone: s.zone, vsRival: s.vsRival),
      },
    );
  }

  /// ターンの締め: 季節を進め、年末の処理と出来事の抽選をする。
  TermReport _finishTerm(
      Action action, bool gotInjured, TournamentResult? t, bool satOut) {
    slot++;
    var yearEnded = false;
    if (slot >= 4) {
      _endYear();
      yearEnded = true;
    }
    if (yearEnded && !retired) _rollGoalOptions();
    // プロでは、24・28・32歳(総合60以上)で日本代表に招集される(出来事が有効なときだけ)。
    if (eventsEnabled &&
        yearEnded &&
        !retired &&
        phase == Phase.season &&
        track == Track.pro &&
        !nationalPending &&
        const {24, 28, 32}.contains(player.age) &&
        player.overall >= 60) {
      pendingEventId = 'national_call';
      return TermReport(
        action: action,
        gotInjured: gotInjured,
        tournament: t,
        satOut: satOut,
        yearEnded: yearEnded,
      );
    }
    // プロでは、23・27・31歳で移籍のオファーが届く(出来事が有効なときだけ)。
    if (eventsEnabled &&
        yearEnded &&
        !retired &&
        phase == Phase.season &&
        track == Track.pro &&
        const {23, 27, 31}.contains(player.age)) {
      pendingEventId = 'pro_move';
      return TermReport(
        action: action,
        gotInjured: gotInjured,
        tournament: t,
        satOut: satOut,
        yearEnded: yearEnded,
      );
    }
    // プロでは、25・29・33歳でフリーエージェントの権利を得る(出来事が有効なときだけ)。
    if (eventsEnabled &&
        yearEnded &&
        !retired &&
        phase == Phase.season &&
        track == Track.pro &&
        const {25, 29, 33}.contains(player.age)) {
      pendingEventId = 'pro_fa';
      return TermReport(
        action: action,
        gotInjured: gotInjured,
        tournament: t,
        satOut: satOut,
        yearEnded: yearEnded,
      );
    }
    // 中学・高校に上がるときは、進学先を選ぶ(出来事が有効なときだけ)。
    if (eventsEnabled && yearEnded && !retired && phase == Phase.season) {
      final forced = switch (stage) {
        Stage.juniorHigh when player.age == 13 => 'school_jh',
        Stage.highSchool when player.age == 16 => 'school_hs',
        _ => null,
      };
      if (forced != null) {
        pendingEventId = forced;
        return TermReport(
          action: action,
          gotInjured: gotInjured,
          tournament: t,
          satOut: satOut,
          yearEnded: yearEnded,
        );
      }
    }
    if (eventsEnabled && comebackPending && phase == Phase.season && !retired) {
      comebackPending = false;
      pendingEventId = 'comeback';
      return TermReport(
        action: action,
        gotInjured: gotInjured,
        tournament: t,
        satOut: satOut,
        yearEnded: yearEnded,
      );
    }
    if (eventsEnabled && phase == Phase.season) {
      pendingEventId = rollEvent(player,
              pro: track == Track.pro,
              abroad: abroad,
              rng: rng,
              recent: recentEventIds)
          ?.id;
      if (pendingEventId != null) {
        recentEventIds.add(pendingEventId!);
        while (recentEventIds.length > 5) {
          recentEventIds.removeAt(0);
        }
      }
    }
    return TermReport(
      action: action,
      gotInjured: gotInjured,
      tournament: t,
      satOut: satOut,
      yearEnded: yearEnded,
    );
  }

  /// 大会の対戦相手を決める。準決勝のあたりでライバルが現れ、あとは架空のチーム。
  OpponentPicker _picker(League l) => (round, isFinal) => _pickOpponent(l, round);

  ({String name, bool rival, double bonus}) _pickOpponent(League l, int round) {
    final rivalRound = max(1, l.rounds - 2);
    // 小さいうちは勝てないと面白くないので、ミニバスの相手は年齢が低いほど弱い。
    final ease = l == League.minibasket ? min(0, (player.age - 11) * 1.5) : 0.0;
    if (l == League.national) {
      // 世界大会の相手は各国代表。強さは回戦ごとに上がる(ライバルは出ない)。
      return (
          name: opponentTeamName(l, rng),
          rival: false,
          bonus: difficulty.opponent);
    }
    // 決勝(プレーオフの決勝シリーズ)は、勝ち上がってきたライバルとの再戦になることがある(素質が高いほど勝ち上がる)。
    final finalRound = l.rounds + l.playoffRounds - 1;
    if (l.playoffRounds > 0 &&
        round == finalRound &&
        rival.activeAt(player.age) &&
        rng.nextDouble() < rival.potential / 130) {
      return (
          name: rival.name,
          rival: true,
          bonus: rival.edgeAt(player.age) + difficulty.opponent + ease);
    }
    if (round == rivalRound && rival.activeAt(player.age)) {
      return (
          name: rival.name,
          rival: true,
          bonus: rival.edgeAt(player.age) + difficulty.opponent + ease);
    }
    return (
        name: opponentTeamName(l, rng),
        rival: false,
        bonus: difficulty.opponent + ease);
  }

  /// 大会の連戦で残る疲れ。6試合を超えた分(プレーオフ・決勝トーナメントまで勝ち進んだ分)1試合あたり2、最大12(プレーオフを長く戦うほど疲れる)。
  static int tournamentFatigue(int games) => min(12, max(0, games - 6) * 2);

  /// 直前の大会で残った疲れ(画面が知らせたら使い終わり。保存しない)。
  int lastTournamentFatigue = 0;

  void _record(TournamentResult t, {bool winter = false}) {
    lastTournamentFatigue = tournamentFatigue(t.games);
    condition = condition.copyWith(fatigue: condition.fatigue + lastTournamentFatigue);
    if (t.league == League.national) {
      nationalPending = false;
      caps++;
    }
    yearBestWins = max(yearBestWins, t.wins);
    yearBestPpg = max(yearBestPpg, t.ppg);
    for (final m in t.matches) {
      if (!m.vsRival) continue;
      if (!rivalMet) {
        rivalMet = true;
        lastMetRival = true;
      }
      if (m.won) {
        rival.wins++;
      } else {
        rival.losses++;
      }
    }
    final before = (totalPoints, totalRebounds, totalAssists);
    final firstPro = !records.any(
        (r) => r.league == League.proDomestic || r.league == League.proAbroad);
    lastHonors = t.honors(rookie: firstPro);
    records.add(YearRecord(
      age: player.age,
      league: t.league,
      wins: t.wins,
      games: t.games,
      ppg: t.ppg,
      rpg: t.rpg,
      apg: t.apg,
      champion: t.champion,
      achievement: t.achievement,
      winter: winter,
      award: t.award,
      steals: t.steals,
      blocks: t.blocks,
      threes: t.threes,
      highPoints: t.highPoints,
      honors: lastHonors,
      box: t.box,
      benchGames: t.matches.where((m) => !m.starter).length,
      bestGame: bestGameOf(t.matches),
    ));
    // 控えから先発へ(同じリーグの前の大会は控えが多く、今回は全部先発)。
    final prevSame = records.reversed.skip(1).where((r) => r.league == t.league).firstOrNull;
    if (prevSame != null &&
        prevSame.benchGames * 2 >= prevSame.games &&
        t.matches.isNotEmpty &&
        t.matches.every((m) => m.starter)) {
      lastRoleNote = '控えから先発の座をつかんだ!(${leagueLabelOf(t.league)})';
    }
    final after = (totalPoints, totalRebounds, totalAssists);
    final lines = <String>[];
    void crossed(String name, int b, int a) {
      for (final v in careerLadder[name]!) {
        if (b < v && a >= v) lines.add('通算$v$name達成!');
      }
    }

    crossed('得点', before.$1, after.$1);
    crossed('リバウンド', before.$2, after.$2);
    crossed('アシスト', before.$3, after.$3);
    lastCareerLines = lines;
    recentAchievements.add(t.achievement);
    while (recentAchievements.length > _recentCount) {
      recentAchievements.removeAt(0);
    }
  }

  void _endYear() {
    _evaluateGoal();
    _checkDream();
    lastYearSummary = _yearSummary();
    // 特殊能力ポイント: 毎年1、目標達成+1、優勝+1。
    lastSpGain = spForYear(
      goalAchieved: lastGoalMessage?.startsWith('目標達成') ?? false,
      champion: records.any((r) => r.age == player.age && r.champion),
    );
    sp += lastSpGain;
    if (track == Track.pro) totalEarnings += salary + sponsor; // その年の年俸とスポンサー収入
    growthLog.add(GrowthPoint(player.age, player.overall, player.heightCm));
    final stageBefore = stage;
    slot = 0;
    player = ageUp(player, rng, habit: habit);
    if (positionReviewAges.contains(player.age)) _reviewPosition();
    switch (track) {
      case Track.school:
        if (player.age >= 19) pathPending = true;
      case Track.university || Track.corporate:
        collegeYearsLeft--;
        if (collegeYearsLeft <= 0) {
          pathPending = true;
          proRejected = false;
        }
      case Track.pro:
        lowYears = player.overall < releaseOverall ? lowYears + 1 : 0;
        if (lowYears >= releaseYears) {
          _retire('戦力外通告を受けた');
        } else if (player.age > maxProAge) {
          _retire('年齢を重ね、現役を退いた');
        } else {
          // 契約更改: 総合評価と、その年の表彰で来年の年俸が決まる。
          final honorsLast = records
              .where((r) => r.age == player.age - 1)
              .fold(0, (s, r) => s + r.honors.length);
          final next = (salaryOf(
                      overall: player.overall,
                      honorsLastYear: honorsLast,
                      abroad: abroad) *
                  specialSalaryMultiplier(player.specials))
              .round();
          if (next >= salary * 1.25) {
            lastSalaryNote = '契約更改: 年俸アップ! ${moneyLabel(salary)} → ${moneyLabel(next)}';
          } else if (next <= salary * 0.8) {
            lastSalaryNote = '契約更改: 年俸ダウン… ${moneyLabel(salary)} → ${moneyLabel(next)}';
          }
          salary = next;
          // スポンサー契約: 前の年の活躍・人気で来年の契約が決まる。
          final lastYear = records.where((r) => r.age == player.age - 1);
          final nextSponsor = (sponsorOf(
                    overall: player.overall,
                    honorsLastYear:
                        lastYear.fold(0, (s, r) => s + r.honors.length),
                    champion: lastYear.any((r) => r.champion),
                    star: player.traits.contains(Trait.starPower),
                    draftPick: draftPick,
                    caps: caps,
                    abroad: abroad,
                  ) *
                  specialSponsorMultiplier(player.specials))
              .round();
          if (sponsor == 0 && nextSponsor > 0) {
            lastSponsorNote = 'スポンサー契約が決まった! 年${moneyLabel(nextSponsor)}';
          } else if (nextSponsor >= sponsor + 600) {
            lastSponsorNote = 'スポンサー契約が増えた: 年${moneyLabel(sponsor)} → 年${moneyLabel(nextSponsor)}';
          }
          sponsor = nextSponsor;
        }
    }
    // 中学・高校に上がると新しいチーム(進路の選択は chooseRoute で)。
    if (!pathPending && !retired && stage != stageBefore) {
      teamwork = 40;
      coachBond = 20;
      schoolBonus = 0;
      schoolLabel = '';
      _newTeamNames();
    }
  }

  // ── 回復 ──

  /// 回復の対象か(疲れ・気持ち・怪我のどれかが悪い)。
  bool get needsRecovery =>
      condition.fatigue >= 30 || condition.morale < 45 || condition.injured;

  /// 回復を使えるか。1ターンに1回まで、季節の局面だけ。
  bool get canRecover =>
      phase == Phase.season && !recoveredThisTerm && needsRecovery;

  /// 動画広告と引き換えの回復。疲れ -40・気持ち +10・怪我が1ターン早く治る。
  void recover() {
    if (!canRecover) throw StateError('今は回復できない');
    condition = condition.copyWith(
      fatigue: condition.fatigue - 40,
      morale: condition.morale + 10,
      injuredTerms: condition.injuredTerms - 1,
    );
    recoveredThisTerm = true;
  }

  // ── 出来事 ──

  /// 起きている出来事の選択肢 `i` を選ぶ。結果を行にして返す。
  List<String> resolveEvent(int i) {
    final e = pendingEvent;
    if (phase != Phase.event || e == null) {
      throw StateError('今は出来事が無い: $phase');
    }
    if (i < 0 || i >= e.options.length) throw RangeError.index(i, e.options);
    final opt = e.options[i];
    final before = player;
    final c0 = condition;
    salaryChangeLine = null;
    final r = applyEffect(player, condition, opt.effect, lastFocus, rng);
    player = r.player;
    condition = r.condition;
    pendingEventId = null;
    lastNewSkills = {};
    _learnSkills();
    _updateBuild();
    _checkDream();
    teamwork = (teamwork + opt.effect.teamwork).clamp(0, 100);
    coachBond = (coachBond + opt.effect.coach).clamp(0, 100);
    if (opt.effect.national) nationalPending = true;
    if (opt.effect.school != null) {
      schoolBonus = opt.effect.school!;
      schoolLabel = opt.effect.schoolLabel ?? '';
      // 進学先・入団先・移籍先を選んだ: 新しいチームの名前。
      teamName = opponentTeamName(league, rng);
    }
    if (opt.effect.salaryPct != 0 && salary > 0) {
      final next = (salary * (100 + opt.effect.salaryPct) / 100 / 10).round() * 10;
      salaryChangeLine = '年俸 ${moneyLabel(salary)} → ${moneyLabel(next)}';
      salary = next;
    }
    if (opt.effect.achievement != 0) {
      final base = recentAchievements.isEmpty ? 30.0 : recentAchievements.removeLast();
      recentAchievements.add((base + opt.effect.achievement).clamp(0, 100).toDouble());
    }
    final lines = <String>[];
    String sgn(num d) => d > 0 ? '+$d' : '$d';
    for (final a in Ability.values) {
      final d = player.of(a) - before.of(a);
      if (d != 0) lines.add('${a.label} ${sgn(d)}');
    }
    if (opt.effect.habit != 0) {
      habit = (habit + opt.effect.habit).clamp(-10.0, 10.0);
    }
    final dm = condition.morale - c0.morale;
    if (dm != 0) lines.add('気持ち ${sgn(dm)}');
    final df = condition.fatigue - c0.fatigue;
    if (df != 0) lines.add('疲れ ${sgn(df)}');
    if (player.heightCm != before.heightCm) {
      lines.add('身長 ${sgn(double.parse((player.heightCm - before.heightCm).toStringAsFixed(1)))}cm');
    }
    for (final t in player.traits.difference(before.traits)) {
      lines.add('特性「${t.label}」を得た');
    }
    if (r.gotInjured) lines.add('${condition.injuryName}をした');
    if (opt.effect.achievement != 0) lines.add('評価が上がった');
    if (opt.effect.habit != 0) {
      lines.add('生活習慣 ${opt.effect.habit > 0 ? '良くなった(身長が伸びやすい)' : '乱れた(身長の伸びが鈍る)'}');
    }
    final sc = salaryChangeLine;
    if (sc != null) lines.add(sc);
    if (opt.effect.national) lines.add('日本代表に参加する(次の冬に世界大会)');
    if (opt.effect.schoolLabel != null) {
      lines.add('進学先: ${opt.effect.schoolLabel}');
    }
    if (opt.effect.coach != 0) {
      lines.add('コーチとの信頼 ${opt.effect.coach > 0 ? '+' : ''}${opt.effect.coach}');
    }
    if (opt.effect.teamwork != 0) {
      lines.add('チームワーク ${opt.effect.teamwork > 0 ? '+' : ''}${opt.effect.teamwork}');
    }
    return lines;
  }

  // ── 目標 ──

  /// 選んだ目標の進み具合(「いま +2 / 目標 +3」など)。目標が無ければ null。
  String? get goalProgress {
    final g = goal;
    if (g == null) return null;
    return switch (g.kind) {
      GoalKind.abilityUp =>
        'いま +${player.of(g.ability!) - (goalStart[g.ability!] ?? player.of(g.ability!))} / 目標 +${g.target}',
      GoalKind.tournamentWins => '今年の最多 $yearBestWins勝 / 目標 ${g.target}勝',
      GoalKind.beatRival => rival.wins > goalRivalWins ? '勝った!' : 'まだ勝てていない',
      GoalKind.scorer =>
        '今年の最高 ${yearBestPpg.toStringAsFixed(1)}点 / 目標 ${g.target}点',
    };
  }

  /// 年のはじめの目標を選ぶ(選ばなくてもよい)。
  void adoptGoal(int i) {
    if (goal != null || i < 0 || i >= goalOptions.length) {
      throw StateError('今は目標を選べない');
    }
    goal = goalOptions[i];
    goalStart = Map<Ability, int>.of(player.abilities);
    goalRivalWins = rival.wins;
  }

  bool _goalMet(Goal g) => switch (g.kind) {
        GoalKind.abilityUp =>
          player.of(g.ability!) - (goalStart[g.ability!] ?? player.of(g.ability!)) >=
              g.target,
        GoalKind.tournamentWins => yearBestWins >= g.target,
        GoalKind.beatRival => rival.wins > goalRivalWins,
        GoalKind.scorer => yearBestPpg >= g.target,
      };

  /// 年末に目標を判定し、達成ならごほうびを当てる。そのあと次の年の候補を引く。
  void _evaluateGoal() {
    final g = goal;
    if (g != null) {
      if (_goalMet(g)) {
        final r = applyEffect(player, condition, g.reward, lastFocus, rng);
        player = r.player;
        condition = r.condition;
        lastGoalMessage = '目標達成!「${g.label}」  ${g.rewardText}';
      } else {
        lastGoalMessage = '目標に届かなかった…「${g.label}」';
      }
    }
    goal = null;
    yearBestWins = 0;
    yearBestPpg = 0;
  }

  /// 次の年の目標の候補を引く(年が明けて、舞台が決まってから)。
  void _rollGoalOptions() {
    yearStart = Map<Ability, int>.of(player.abilities);
    goalOptions = rollGoals(
      player,
      league: league,
      rivalActive: rival.activeAt(player.age),
      focus: lastFocus,
      rng: rng,
    );
  }

  // ── 進路 ──

  /// 進路を選ぶ。プロ契約を取れたら true。落ちたら false(再挑戦なら引退)。
  bool chooseRoute(Route route) {
    if (phase != Phase.path) throw StateError('今は進路を選べない: $phase');
    if (!availableRoutes.contains(route)) {
      throw StateError('選べない進路: $route');
    }
    if (route == Route.pro) {
      final win = winsContract(player, achievement, rng);
      if (win) {
        draftPick = draftPickOf(offerScore(player, achievement), rng);
        salary = rookieSalary(draftPick);
        if (draftPick <= 10) {
          // 上位指名は期待されている: 気持ちが高い状態ではじまる。
          condition = condition.copyWith(morale: condition.morale + 10);
        }
        track = Track.pro;
        teamwork = 40;
        coachBond = 20;
        schoolBonus = 0;
        schoolLabel = '';
        _newTeamNames();
        if (eventsEnabled) pendingEventId = 'pro_join';
        pathPending = false;
        proRejected = false;
        _checkDream();
        return true;
      }
      if (secondChance) {
        _retire('プロ契約に届かなかった');
      } else {
        proRejected = true;
      }
      return false;
    }
    track = route == Route.university ? Track.university : Track.corporate;
    teamwork = 40;
    coachBond = 20;
    schoolBonus = 0;
    schoolLabel = '';
    _newTeamNames();
    collegeYearsLeft = route.years;
    secondChance = true;
    pathPending = false;
    proRejected = false;
    return true;
  }

  /// 進路の途中で競技をやめる。
  void giveUp() {
    if (phase != Phase.path) throw StateError('今はやめられない: $phase');
    _retire('競技の道を離れた');
  }

  // ── プロ ──

  void goAbroad() {
    if (!canGoAbroad) throw StateError('海外挑戦はできない');
    abroad = true;
    teamName = opponentTeamName(League.proAbroad, rng);
  }

  /// プロの選手が自分で引退を決める。
  void retire() {
    if (phase != Phase.season || track != Track.pro) {
      throw StateError('引退できるのはプロの選手だけ');
    }
    _retire('自分で現役を退いた');
  }

  /// 出来事の選択で年俸が変わったときの行(一時的。`resolveEvent` の返り値に入れる)。
  String? salaryChangeLine;

  void _retire(String reason) {
    retiredReason = reason;
    pathPending = false;
  }

  // ── 通算 ──

  int get totalGames => records.fold(0, (s, r) => s + r.games);

  /// 通算の得点・リバウンド・アシスト(年ごとの平均×試合数の合計)。
  int get totalPoints =>
      records.fold(0.0, (s, r) => s + r.ppg * r.games).round();
  int get totalRebounds =>
      records.fold(0.0, (s, r) => s + r.rpg * r.games).round();
  int get totalAssists =>
      records.fold(0.0, (s, r) => s + r.apg * r.games).round();
  int get totalSteals => records.fold(0, (s, r) => s + r.steals);
  int get totalBlocks => records.fold(0, (s, r) => s + r.blocks);
  int get totalThrees => records.fold(0, (s, r) => s + r.threes);

  /// 通算のボックススコア(シュート成功率の計算に使う。古い記録は入らない)。
  BoxScore get careerBox => records.fold(const BoxScore(), (s, r) => s + r.box);

  /// ボックススコアのある年だけの3P成功数(成功率の分子をそろえるため)。
  int get boxedThrees => records.where((r) => !r.box.isEmpty).fold(0, (s, r) => s + r.threes);

  /// キャリアハイ(1試合の最多得点)とその年齢。記録が無ければ null。
  ({int points, int age})? get careerHigh {
    ({int points, int age})? best;
    for (final r in records) {
      if (r.highPoints > (best?.points ?? 0)) {
        best = (points: r.highPoints, age: r.age);
      }
    }
    return best;
  }

  int get awardCount => records.where((r) => r.award != null).length;

  /// 個人タイトル・表彰ごとの受賞回数(`Honor`)。
  Map<String, int> get honorCounts {
    final m = <String, int>{};
    for (final r in records) {
      for (final h in r.honors) {
        m[h] = (m[h] ?? 0) + 1;
      }
    }
    return m;
  }

  int get honorTotal => records.fold(0, (s, r) => s + r.honors.length);
  double get careerPpg => totalGames == 0
      ? 0
      : records.fold(0.0, (s, r) => s + r.ppg * r.games) / totalGames;
  int get titles => records.where((r) => r.champion).length;

  // ── 保存 ──

  Map<String, dynamic> toJson() => {
        'player': player.toJson(),
        'condition': condition.toJson(),
        'track': track.name,
        'collegeYearsLeft': collegeYearsLeft,
        'abroad': abroad,
        'secondChance': secondChance,
        'proRejected': proRejected,
        'pathPending': pathPending,
        'retiredReason': retiredReason,
        'lowYears': lowYears,
        'archived': archived,
        'recoveredThisTerm': recoveredThisTerm,
        'teamwork': teamwork,
        'coachBond': coachBond,
        'rivalMet': rivalMet,
        'nationalPending': nationalPending,
        'draftPick': draftPick,
        'injuredStreak': injuredStreak,
        'habit': habit,
        'buildLabel': buildLabel,
        'buildsSeen': buildsSeen.toList()..sort(),
        'comebackPending': comebackPending,
        'salary': salary,
        'sponsor': sponsor,
        'totalEarnings': totalEarnings,
        'caps': caps,
        'dream': dream.name,
        'dreamAge': dreamAge,
        'sp': sp,
        'posAuto': positionAuto,
        'yearStart': {for (final e in yearStart.entries) e.key.name: e.value},
        'mastery': {for (final e in mastery.entries) e.key.name: e.value},
        'number': number,
        'mate': mate,
        'teamName': teamName,
        'coachLabel': coachLabel,
        'recentActions': [for (final a in recentActions) a.name],
        'schoolBonus': schoolBonus,
        'schoolLabel': schoolLabel,
        'recentEventIds': recentEventIds,
        'growthLog': [for (final p in growthLog) p.toJson()],
        'difficulty': difficulty.name,
        'goalOptions': [for (final g in goalOptions) g.toJson()],
        'goal': goal?.toJson(),
        'goalStart': {for (final e in goalStart.entries) e.key.name: e.value},
        'goalRivalWins': goalRivalWins,
        'yearBestWins': yearBestWins,
        'yearBestPpg': yearBestPpg,
        'lastGoalMessage': lastGoalMessage,
        'rival': rival.toJson(),
        'run': run?.toJson(),
        'runWinter': runWinter,
        'termAction': termAction.name,
        'termInjured': termInjured,
        'slot': slot,
        'pendingEventId': pendingEventId,
        'lastFocus': lastFocus.name,
        'recentAchievements': recentAchievements,
        'records': [for (final r in records) r.toJson()],
      };

  /// 項目を足すときは既定値を置く(既存セーブを壊さない)。
  factory Game.fromJson(Map<String, dynamic> j, {Random? rng}) => Game(
        player: Player.fromJson((j['player'] as Map).cast<String, dynamic>()),
        rng: rng,
        condition: Condition.fromJson((j['condition'] as Map?)?.cast<String, dynamic>()),
        track: Track.values.firstWhere(
          (t) => t.name == j['track'],
          orElse: () => Track.school,
        ),
        collegeYearsLeft: (j['collegeYearsLeft'] as num?)?.toInt() ?? 0,
        abroad: (j['abroad'] as bool?) ?? false,
        secondChance: (j['secondChance'] as bool?) ?? false,
        proRejected: (j['proRejected'] as bool?) ?? false,
        pathPending: (j['pathPending'] as bool?) ?? false,
        retiredReason: j['retiredReason'] as String?,
        lowYears: (j['lowYears'] as num?)?.toInt() ?? 0,
        archived: (j['archived'] as bool?) ?? false,
        recoveredThisTerm: (j['recoveredThisTerm'] as bool?) ?? false,
        teamwork: (j['teamwork'] as num?)?.toInt() ?? 40,
        coachBond: (j['coachBond'] as num?)?.toInt() ?? 20,
        number: (j['number'] as num?)?.toInt() ?? 0,
        nationalPending: (j['nationalPending'] as bool?) ?? false,
        draftPick: (j['draftPick'] as num?)?.toInt() ?? 0,
        injuredStreak: (j['injuredStreak'] as num?)?.toInt() ?? 0,
        habit: (j['habit'] as num?)?.toDouble() ?? 0,
        buildLabel: (j['buildLabel'] as String?) ?? '',
        buildsSeen: {
          for (final v in (j['buildsSeen'] as List?) ?? const [])
            if (v is String) v,
        },
        comebackPending: (j['comebackPending'] as bool?) ?? false,
        salary: (j['salary'] as num?)?.toInt() ?? 0,
        sponsor: (j['sponsor'] as num?)?.toInt() ?? 0,
        totalEarnings: (j['totalEarnings'] as num?)?.toInt() ?? 0,
        caps: (j['caps'] as num?)?.toInt() ?? 0,
        dream: Dream.parse(j['dream'] as String?),
        dreamAge: (j['dreamAge'] as num?)?.toInt() ?? 0,
        sp: (j['sp'] as num?)?.toInt() ?? 0,
        positionAuto: (j['posAuto'] as bool?) ?? true,
        mate: (j['mate'] as String?) ?? '',
        teamName: (j['teamName'] as String?) ?? '',
        coachLabel: (j['coachLabel'] as String?) ?? '',
        rivalMet: (j['rivalMet'] as bool?) ?? (((j['rival'] as Map?)?['wins'] as num? ?? 0) + ((j['rival'] as Map?)?['losses'] as num? ?? 0) > 0),
        recentActions: [
          for (final v in (j['recentActions'] as List?) ?? const [])
            if (Action.values.any((a) => a.name == v))
              Action.values.firstWhere((a) => a.name == v)
        ],
        schoolBonus: (j['schoolBonus'] as num?)?.toDouble() ?? 0,
        schoolLabel: (j['schoolLabel'] as String?) ?? '',
        growthLog: [
          for (final p in (j['growthLog'] as List?) ?? const [])
            GrowthPoint.fromJson((p as Map).cast<String, dynamic>()),
        ],
        recentEventIds: [
          for (final v in (j['recentEventIds'] as List?) ?? const []) v as String
        ],
        difficulty: Difficulty.parse(j['difficulty'] as String?),
        goalOptions: [
          for (final g in (j['goalOptions'] as List?) ?? const [])
            Goal.fromJson((g as Map).cast<String, dynamic>()),
        ],
        goal: j['goal'] == null
            ? null
            : Goal.fromJson((j['goal'] as Map).cast<String, dynamic>()),
        goalStart: {
          for (final e in ((j['goalStart'] as Map?) ?? const {}).entries)
            if (Ability.parse(e.key as String) != null)
              Ability.parse(e.key as String)!: (e.value as num).toInt(),
        },
        yearStart: {
          for (final e in ((j['yearStart'] as Map?) ?? const {}).entries)
            if (Ability.parse(e.key as String) != null)
              Ability.parse(e.key as String)!: (e.value as num).toInt(),
        },
        mastery: {
          for (final e in ((j['mastery'] is Map ? j['mastery'] as Map : null) ?? const {}).entries)
            if (e.key is String && Ability.parse(e.key as String) != null && e.value is num)
              Ability.parse(e.key as String)!: (e.value as num).toInt(),
        },
        goalRivalWins: (j['goalRivalWins'] as num?)?.toInt() ?? 0,
        yearBestWins: (j['yearBestWins'] as num?)?.toInt() ?? 0,
        yearBestPpg: (j['yearBestPpg'] as num?)?.toDouble() ?? 0,
        lastGoalMessage: j['lastGoalMessage'] as String?,
        rival: j['rival'] == null
            ? null
            : Rival.fromJson((j['rival'] as Map).cast<String, dynamic>()),
        run: j['run'] == null
            ? null
            : TournamentRun.fromJson((j['run'] as Map).cast<String, dynamic>()),
        runWinter: (j['runWinter'] as bool?) ?? false,
        termAction: Action.values.firstWhere(
          (a) => a.name == j['termAction'],
          orElse: () => Action.practice,
        ),
        termInjured: (j['termInjured'] as bool?) ?? false,
        slot: (j['slot'] as num?)?.toInt() ?? 0,
        pendingEventId: j['pendingEventId'] as String?,
        lastFocus: Ability.parse((j['lastFocus'] as String?) ?? '') ??
            Ability.threePoint,
        recentAchievements: [
          for (final v in (j['recentAchievements'] as List?) ?? const [])
            (v as num).toDouble(),
        ],
        records: [
          for (final r in (j['records'] as List?) ?? const [])
            YearRecord.fromJson((r as Map).cast<String, dynamic>()),
        ],
      );
}

/// `path.dart` の `canGoAbroad` を `Game` のゲッター名と衝突させずに使う。
bool pathCanGoAbroad(Player p) => canGoAbroad(p);
