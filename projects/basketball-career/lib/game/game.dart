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
enum Phase { season, event, path, retired }

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
  });

  final Action action;
  final bool gotInjured;

  /// 夏の大会の結果。大会の無い季節、出られなかった年は null。
  final TournamentResult? tournament;

  /// 怪我で大会に出られなかった。
  final bool satOut;
  final bool yearEnded;
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
  }) {
    if (phase != Phase.season) throw StateError('今は季節を選べない: $phase');
    lastFocus = focus;
    final r = playTerm(player, condition, action, focus, rng);
    player = r.player;
    condition = r.condition;

    TournamentResult? t;
    var satOut = false;
    final winter = slot == 3 && hasWinterCup;
    if (slot == 1 || winter) {
      if (condition.injured) {
        satOut = true;
      } else {
        t = playTournament(
          player,
          league,
          form: condition.form,
          rng: rng,
          chooseClutch: chooseClutch,
        );
        _record(t, winter: winter);
      }
    }

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
      gotInjured: r.gotInjured,
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
