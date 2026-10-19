import 'dart:math';

import 'career.dart';
import 'events.dart';
import 'life.dart';
import 'match.dart';
import 'path.dart';
import 'player.dart';
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
    this.run,
    this.runWinter = false,
    this.termAction = Action.practice,
    this.termInjured = false,
    this.slot = 0,
    this.pendingEventId,
    this.lastFocus = Ability.threePoint,
    this.eventsEnabled = true,
    List<double>? recentAchievements,
    List<YearRecord>? records,
  })  : rng = rng ?? Random(),
        recentAchievements = recentAchievements ?? [],
        records = records ?? [];

  /// 新しく始める。素質・身長の素質・生まれつきの特性を引く。
  factory Game.start(String name, {Random? rng, bool events = true}) {
    final r = rng ?? Random();
    final potential = (30 + r.nextInt(40) + r.nextInt(31)).clamp(30, 100);
    return Game(
      player: newPlayer(name, potential, r.nextDouble(), rollInnateTraits(r)),
      rng: r,
      eventsEnabled: events,
    );
  }

  final Random rng;
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

  /// 進行中の大会(勝負どころで止まっているときだけ残る)。
  TournamentRun? run;
  bool runWinter;

  /// 大会の途中で止まっているターンの過ごし方と、そのターンの怪我。
  Action termAction;
  bool termInjured;

  /// 直近に終えたターンの結果(勝負どころで止まった後、続きを終えたときの結果もここに入る)。
  TermReport? lastReport;
  int slot;

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

  /// 冬の大会(全国選手権)がある段階。高校と大学・実業団。
  bool get hasWinterCup => stage == Stage.highSchool || stage == Stage.college;

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
    final r = playTerm(player, condition, action, focus, rng);
    player = r.player;
    condition = r.condition;
    termAction = action;
    termInjured = r.gotInjured;

    final winter = slot == 3 && hasWinterCup;
    TournamentResult? t;
    var satOut = false;
    if (slot == 1 || winter) {
      if (condition.injured) {
        satOut = true;
      } else {
        final cr = TournamentRun(league);
        cr.advance(
          player,
          form: condition.form,
          rng: rng,
          chooseClutch: chooseClutch,
          askClutch: askClutch && chooseClutch == null,
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
    cr.resolve(player, choice, form: condition.form, rng: rng);
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
    if (eventsEnabled && phase == Phase.season) {
      pendingEventId = rollEvent(player, pro: track == Track.pro, rng: rng)?.id;
    }
    return TermReport(
      action: action,
      gotInjured: gotInjured,
      tournament: t,
      satOut: satOut,
      yearEnded: yearEnded,
    );
  }

  void _record(TournamentResult t, {bool winter = false}) {
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
    return lines;
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
