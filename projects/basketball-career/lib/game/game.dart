import 'dart:math';

import 'career.dart';
import 'difficulty.dart';
import 'events.dart';
import 'goals.dart';
import 'life.dart';
import 'match.dart';
import 'path.dart';
import 'player.dart';
import 'rival.dart';
import 'season.dart';
import 'traits.dart';

/// 画面が見る局面。対応する操作だけを呼ぶ。
enum Phase { season, clutch, event, path, retired }

/// どこでプレーしているか。
enum Track { school, university, corporate, pro }

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
  });

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

  Map<String, dynamic> toJson() => {
        'winter': winter,
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
  })  : rng = rng ?? Random(),
        rival = rival ?? Rival(name: 'ライバル', potential: 60),
        recentEventIds = recentEventIds ?? [],
        growthLog = growthLog ?? [],
        goalOptions = goalOptions ?? [],
        goalStart = goalStart ?? {},
        recentAchievements = recentAchievements ?? [],
        records = records ?? [];

  /// 新しく始める。素質・身長の素質・生まれつきの特性を引く。
  factory Game.start(String name,
      {Random? rng,
      bool events = true,
      Difficulty difficulty = Difficulty.normal}) {
    final r = rng ?? Random();
    final potential = (30 + r.nextInt(40) + r.nextInt(31)).clamp(30, 100);
    final g = Game(
      player: newPlayer(name, potential, r.nextDouble(), rollInnateTraits(r)),
      rival: Rival.random(r),
      difficulty: difficulty,
      rng: r,
      eventsEnabled: events,
    );
    g._rollGoalOptions();
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
  int goalRivalWins;

  /// 今年の大会での最多勝ち数・最高の平均得点(目標の判定に使う)。
  int yearBestWins;
  double yearBestPpg;

  /// 直近の年末の、目標の結果の言葉(画面が見せたら消す)。
  String? lastGoalMessage;
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
          : (run?.pending != null)
              ? Phase.clutch
              : pendingEventId != null
                  ? Phase.event
                  : Phase.season;

  /// 出来事の文中の {rival} をライバルの名前にする。
  String fill(String s) => s.replaceAll('{rival}', rival.name);

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

  /// チームワークによる味方の強さの上乗せ。パスが上手いほど効きが大きい。
  double get teamBonus =>
      (teamwork - 50) * 0.07 * (0.7 + player.of(Ability.pass) / 200);

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
    Clutch Function(int margin)? chooseClutch,
    bool askClutch = false,
  }) {
    if (phase != Phase.season) throw StateError('今は季節を選べない: $phase');
    lastFocus = focus;
    recoveredThisTerm = false;
    lastGoalMessage = null;
    final r = playTerm(player, condition, action, focus, rng,
        growthScale: difficulty.growth * coachBoost);
    player = r.player;
    condition = r.condition;
    termAction = action;
    termInjured = r.gotInjured;
    // 何もしなければ少しずつ薄れる(毎ターン -2)。交流・練習試合で保つ。
    teamwork = (teamwork +
            switch (action) {
              Action.social => 12,
              Action.scrimmage => 6,
              _ => 0,
            } -
            2)
        .clamp(0, 100);
    if (action == Action.practice || action == Action.intense) {
      coachBond = (coachBond + 1).clamp(0, 100);
    }

    final winter = slot == 3 && hasWinterCup;
    TournamentResult? t;
    var satOut = false;
    if (slot == 1 || winter) {
      if (condition.injured) {
        satOut = true;
      } else {
        final cr = TournamentRun(league, teamBonus: teamBonus);
        cr.advance(
          player,
          form: condition.form,
          rng: rng,
          chooseClutch: chooseClutch,
          askClutch: askClutch && chooseClutch == null,
          pickOpponent: _pickOpponent,
        );
        if (cr.pending != null) {
          // 勝負どころで止まる。選ぶまで季節は進まない(`resolveClutch`)。
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
        form: condition.form, rng: rng, pickOpponent: _pickOpponent);
    if (cr.pending != null) {
      return TermReport(
          action: termAction, gotInjured: termInjured, paused: true);
    }
    run = null;
    final t = cr.result();
    _record(t, winter: runWinter);
    return lastReport = _finishTerm(termAction, termInjured, t, false);
  }

  /// 勝負どころで止まっている試合の選択肢と成功率。
  ({int margin, double oppStrength, Map<Clutch, double> chances})? get clutchInfo {
    final s = run?.pending;
    if (s == null) return null;
    return (
      margin: s.margin,
      oppStrength: s.oppStrength,
      chances: {
        for (final c in Clutch.values)
          c: clutchChance(player, c, s.oppStrength, s.form),
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
    if (eventsEnabled && phase == Phase.season) {
      pendingEventId = rollEvent(player,
              pro: track == Track.pro, rng: rng, recent: recentEventIds)
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
  ({String name, bool rival, double bonus}) _pickOpponent(int round, bool isFinal) {
    final l = league;
    final rivalRound = max(1, l.rounds - 2);
    // 小さいうちは勝てないと面白くないので、ミニバスの相手は年齢が低いほど弱い。
    final ease = l == League.minibasket ? min(0, (player.age - 11) * 1.5) : 0.0;
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

  void _record(TournamentResult t, {bool winter = false}) {
    yearBestWins = max(yearBestWins, t.wins);
    yearBestPpg = max(yearBestPpg, t.ppg);
    for (final m in t.matches) {
      if (!m.vsRival) continue;
      if (m.won) {
        rival.wins++;
      } else {
        rival.losses++;
      }
    }
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
    ));
    recentAchievements.add(t.achievement);
    while (recentAchievements.length > _recentCount) {
      recentAchievements.removeAt(0);
    }
  }

  void _endYear() {
    _evaluateGoal();
    growthLog.add(GrowthPoint(player.age, player.overall, player.heightCm));
    final stageBefore = stage;
    slot = 0;
    player = ageUp(player, rng);
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
          _retire('${maxProAge + 1}歳で現役を退いた');
        }
    }
    // 中学・高校に上がると新しいチーム(進路の選択は chooseRoute で)。
    if (!pathPending && !retired && stage != stageBefore) {
      teamwork = 40;
      coachBond = 20;
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
    final r = applyEffect(player, condition, opt.effect, lastFocus, rng);
    player = r.player;
    condition = r.condition;
    pendingEventId = null;
    teamwork = (teamwork + opt.effect.teamwork).clamp(0, 100);
    coachBond = (coachBond + opt.effect.coach).clamp(0, 100);
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
    if (r.gotInjured) lines.add('怪我をした');
    if (opt.effect.achievement != 0) lines.add('評価が上がった');
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
        track = Track.pro;
        teamwork = 40;
        coachBond = 20;
        pathPending = false;
        proRejected = false;
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
  }

  /// プロの選手が自分で引退を決める。
  void retire() {
    if (phase != Phase.season || track != Track.pro) {
      throw StateError('引退できるのはプロの選手だけ');
    }
    _retire('自分で現役を退いた');
  }

  void _retire(String reason) {
    retiredReason = reason;
    pathPending = false;
  }

  // ── 通算 ──

  int get totalGames => records.fold(0, (s, r) => s + r.games);
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
