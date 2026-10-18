import 'dart:math';

import 'calendar.dart';
import 'career.dart';
import 'characters.dart';
import 'exp.dart';
import 'life.dart';
import 'path.dart';
import 'player.dart';
import 'difficulty.dart';
import 'goals.dart';
import 'life_log.dart';
import 'records.dart';
import 'flavor.dart';
import 'world.dart';
import 'season.dart';
import 'tactics.dart';
import 'traits.dart';

/// いま何を待っているか。画面はこれを見て出すものを決める。
enum Phase {
  term, // 季節の過ごし方を選ぶ
  event, // 出来事の選択肢を選ぶ
  pathChoice, // ドラフトに外れた。大学/社会人を選ぶか、諦めるか
  retired, // 終わり
}

/// 引退時のまとめ。
class Ending {
  const Ending({
    required this.title,
    required this.madePro,
    required this.proYears,
    required this.peakOverall,
    required this.championships,
    required this.wasTwoWay,
    this.rivalWins = 0,
    this.rivalLosses = 0,
    this.partnerName,
    this.titles = const [],
  });

  final String title;
  final bool madePro;
  final int proYears;
  final int peakOverall;
  final int championships;
  final bool wasTwoWay;
  final int rivalWins;
  final int rivalLosses;

  /// 絆が深かった恋人の名前(いれば結婚した)。
  final String? partnerName;
  bool get married => partnerName != null;

  /// 獲得したタイトル(年ごとに1つずつ、重複あり)。
  final List<String> titles;
}

/// 6歳から引退までの一代記を進める本体。画面には依存しない。
/// 乱数は注入する(テストで再現できる)。
class Game {
  Game._(this.rng, this.player, this.cast,
      [this.difficulty = Difficulty.normal]);

  /// 新しい選手で始める。`potential` を省くと乱数で決まる。
  factory Game.newGame({
    required String name,
    required Role role,
    required Random rng,
    int? potential,
    Difficulty difficulty = Difficulty.normal,
  }) {
    final p = Player(
      name: name,
      role: role,
      age: startAge,
      potential: potential ?? 30 + rng.nextInt(61),
      abilities: {for (final a in abilitiesOf(role)) a: 15},
      traits: rollInnateTraits(rng, role),
    );
    final g = Game._(rng, p, Cast.initial(rng, role, p.traits), difficulty)
      .._wasTwoWay = role == Role.twoWay;
    g.overallHistory.add(overall(p).round());
    g._note('stage', '${stageNameOf(Stage.youth)}を始めた');
    g._newGoal();
    return g;
  }

  final Random rng;

  /// 難しさ。はじめに選び、その一生ずっと変わらない。
  final Difficulty difficulty;
  Player player;
  Condition condition = const Condition();
  int slot = 0; // 今年の何ターン目か(0始まり)。月単位か季節かは段階で決まる
  Cast cast; // 家族・ライバル・仲間・コーチ・恋人
  ExpPool exp = const ExpPool(); // 貯めた経験点。`spend` で能力に振り分ける
  Phase phase = Phase.term;
  GameEvent? pendingEvent;
  Ability _eventFocus = Ability.contact;

  Course? route; // 大学/社会人を選んだか
  bool turnedPro = false;
  int lowYears = 0;
  int proYears = 0;
  int peakOverall = 0;
  int championships = 0;
  bool _wasTwoWay = false;
  final List<double> achievements = []; // 夏の大会ごとの実績
  final List<String> log = []; // 画面に出す出来事の記録
  Outcome lastOutcome = Outcome.normal; // 直前のターンの出来(保存しない・画面の表示用)
  Map<Category, int> lastGain = const {}; // 直前のターンで貯まった経験点(保存しない・画面の表示用)
  Ending? ending;

  /// 引退後、殿堂(過去の選手の記録)に書き込み済みか。
  bool archived = false;

  /// 総合評価の推移。[0] が6歳の始まり、以降は年の終わりごとに1つずつ(人生のグラフ用)。
  final List<int> overallHistory = [];

  /// プロ入りした年齢。入っていなければ null。
  int? proStartAge;

  /// 入団した球団(架空)。プロ入りしてから。
  String? proTeam;

  /// 自分で決めた守備位置・役割。決めていなければ null(適性がいちばん高い所を守る)。
  Pos? position;

  /// 実際に守るポジション。
  Pos get effectivePos => effectivePosition(player, position);

  /// ポジションを決められる時: 中学・高校・進路(大学・社会人)の最初の年と、プロの毎年の最初。
  bool get canChoosePosition {
    if (phase != Phase.term || slot != 0) return false;
    if (stage == Stage.pro) return true;
    if (stage == Stage.youth || stage == Stage.retired) return false;
    return stageOf(player.age - 1) != stageOf(player.age);
  }

  /// ポジションを決める。決められる時だけ。選べないポジション(役割に合わない)は拒否。
  void choosePosition(Pos pos) {
    _require(Phase.term);
    if (!canChoosePosition) throw StateError('いまはポジションを決められない');
    if (!positionsFor(player.role).contains(pos)) {
      throw ArgumentError('この役割では選べない: ${pos.label}');
    }
    position = pos;
    final adj = positionTeamAdjust(player, pos);
    log.add('ポジションを${pos.label}に決めた。'
        '${adj == 0 ? '' : '(適性が低く、チーム力$adj)'}');
    _note('position', 'ポジションを${pos.label}に決めた');
  }

  /// 年ごとの成績(大会・シーズン)。成績画面とエンディングに出す。
  final List<SeasonRecord> records = [];

  /// 日本代表として出た世界大会(U-12・U-15・U-18・U-23・プロ)の結果。
  final List<WorldRecord> worldRecords = [];

  /// 直前に起きた出来事(同じものが続かないようにする)。
  String? _lastEventId;

  /// 最近起きた出来事(同じものが続かないように。保存はしない)。
  final List<String> _recentEvents = [];

  /// 今年の目標。年の初めに決まり、大会(プロはシーズン)の成績で達成かどうかが決まる。
  Goal? goal;

  /// 大会・シーズン最終月の作戦。その大会が終わると「堅実」に戻る。
  Tactic tactic = Tactic.steady;

  /// 人生の節目(入学・進路・ドラフト・特性の習得・転向・引退)。経歴の年表に出す。
  final List<LifeEvent> lifeLog = [];

  void _note(String kind, String text) =>
      lifeLog.add(LifeEvent(player.age, kind, text));

  Stage get stage => phase == Phase.retired
      ? Stage.retired
      : stageOf(player.age, turnedPro: turnedPro);

  /// ドラフトにかかるときの実績: 直近3回の大会の平均。
  double get recentAchievement {
    if (achievements.isEmpty) return 0;
    final r = achievements.length > 3
        ? achievements.sublist(achievements.length - 3)
        : achievements;
    return r.reduce((a, b) => a + b) / r.length;
  }

  // ── ターンの選択 ──

  /// 今のターンの表示名。月単位なら「7月」、季節なら「夏」。
  String get slotName => slotLabel(stage, slot);

  /// 今の年のターン数(12 または 4)。
  int get slotsInYear => slotsPerYear(stage);

  Motivation get motivation => motivationOf(condition.morale);

  /// 今のターンの過ごし方を決める。`focus` は練習・特訓・研究で伸ばす能力。
  /// 能力は直接は上がらず、経験点が貯まる。`spend` / `autoSpend` で振り分ける。
  void choose(Plan action, [Ability? focus]) {
    _require(Phase.term);
    final f = focus ?? abilitiesOf(player.role).first;
    if (!abilitiesOf(player.role).contains(f)) {
      throw ArgumentError('${player.role.name} にその能力は無い: ${f.name}');
    }
    final share = slotShare(stage);
    final wasInjured = condition.injured;
    final r = playTerm(player, condition, action, f, rng, share: share);
    player = r.player;
    condition = r.condition;
    // _afterCast が経験点(コーチのボーナス)を直接足すことがあるので、先に評価する。
    var gained = wasInjured ? r.exp : _afterCast(action, f, r.exp);
    if (difficulty != Difficulty.normal) {
      gained = {
        for (final e in gained.entries)
          e.key: (e.value * difficulty.expMultiplier).round(),
      };
    }
    exp = exp.add(gained);
    lastGain = gained;
    lastOutcome = wasInjured ? Outcome.normal : r.outcome;
    if (r.gotInjured) log.add('怪我をしてしまった。');
    if (isTournamentSlot(stage, slot)) _playSummer();

    final e = drawEvent(rng,
        share: share,
        stage: stage,
        cast: cast,
        exclude: _lastEventId,
        recent: _recentEvents.toSet());
    if (e == null) {
      _nextSlot();
    } else {
      pendingEvent = e;
      _lastEventId = e.id;
      _recentEvents.add(e.id);
      if (_recentEvents.length > 4) _recentEvents.removeAt(0);
      _eventFocus = f;
      phase = Phase.event;
    }
  }

  void resolveEvent(int index) {
    _require(Phase.event);
    final ch = pendingEvent!.choices[index];
    final before = player.traits;
    final r = ch.risky != null
        ? ch.risky!(player, condition, _eventFocus, rng)
        : ch.apply(player, condition, _eventFocus);
    player = r.player;
    condition = r.condition;
    ch.onCast?.call(cast, rng);
    for (final t in player.traits.difference(before)) {
      _note('trait', '特性「${t.label}」を習得');
    }
    _checkCoach();
    pendingEvent = null;
    phase = Phase.term;
    _nextSlot();
  }

  // ── 経験点の振り分け ──

  /// 能力を1つ上げる。足りなければ false。
  bool spend(Ability a) {
    final r = buy(player, exp, a);
    if (r == null) return false;
    player = r.player;
    exp = r.pool;
    return true;
  }

  /// 買えるだけ上げる。上がった数を返す。
  int spendAll(Ability a) {
    final r = buyAll(player, exp, a);
    player = r.player;
    exp = r.pool;
    return r.bought;
  }

  /// おまかせ: 種類ごとに低い能力から順に振り分ける。
  void autoSpend() {
    final r = autoSpendExp(player, exp);
    player = r.player;
    exp = r.pool;
  }

  /// 大会・シーズン最終月の作戦を選ぶ。
  void setTactic(Tactic t) {
    tactic = t;
  }

  /// 大会(プロはシーズン最終月)の前後か。作戦を選ぶ画面を出す目安。
  bool get tacticRelevant {
    final t = stage == Stage.pro ? 6 : (isMonthly(stage) ? 3 : 1);
    return slot >= t - 1 && slot <= t;
  }

  /// プロの間はいつでも役割を変えられる(二刀流にする/戻す)。
  void changeRole(Role to) {
    _require(Phase.term);
    player = switchRole(player, to, stage);
    if (to == Role.twoWay) _wasTwoWay = true;
    log.add('${roleNameOf(to)}に転向した。');
    _note('role', '${roleNameOf(to)}になった');
  }

  /// プロの間は自分で引退を決められる。
  void retire() {
    _require(Phase.term);
    if (!canChooseRetire(stage)) throw StateError('引退を選べるのはプロの間だけ');
    _retire('自ら引退を決めた');
  }

  // ── ドラフトに外れたとき ──

  void chooseRoute(Course r) {
    _require(Phase.pathChoice);
    route = r;
    phase = Phase.term;
    log.add('${courseNameOf(r)}で再挑戦する。');
    _note('route', '${courseNameOf(r)}で再挑戦');
  }

  void giveUp() {
    _require(Phase.pathChoice);
    _retire('プロを諦めた');
  }

  // ── 管理者機能(調整・検証用。ホーム画面のタイトルを7回タップで有効) ──
  //
  // 通常の遊びでは使わない。上限(特性は4つまで)や矛盾(大器晩成と早熟など)も無視して書き換える。

  /// 素質(0〜100)を書き換える。
  void adminSetPotential(int v) {
    player = player.copyWith(potential: v.clamp(0, 100));
  }

  /// 特性を、上限や矛盾を無視して丸ごと置き換える。
  void adminSetTraits(Set<Trait> t) {
    player = player.copyWith(traits: Set.of(t));
  }

  void adminSetAbility(Ability a, int v) {
    if (!abilitiesOf(player.role).contains(a)) return;
    player =
        player.copyWith(abilities: {...player.abilities, a: v.clamp(0, 99)});
  }

  /// 経験点を全種類に足す(負でも可。0未満にはならない)。
  void adminAddExp(int n) {
    exp = ExpPool({for (final c in Category.values) c: max(0, exp.of(c) + n)});
  }

  /// コーチのコツを書き換える。`tipsNeeded` 以上にすると、その場で特性を習得する。
  void adminSetCoachTips(int n) {
    final coach = cast.coach;
    if (coach == null) return;
    coach.tips = n.clamp(0, tipsNeeded);
    _checkCoach();
  }

  /// コーチが教える特性を差し替える(null なら教えられない)。
  void adminSetCoachTeaches(Trait? t) {
    final i = cast.members.indexWhere((m) => m.kind == Kind.coach);
    if (i < 0) return;
    final c = cast.members[i];
    cast.members[i] = Character(
      id: c.id,
      name: c.name,
      kind: c.kind,
      bond: c.bond,
      specialty: c.specialty,
      teaches: t,
      tips: c.tips,
      talent: c.talent,
    );
  }

  // ── 内部 ──

  /// 友情タッグ・コーチ・恋人/家族への影響。経験点の量を返す。
  Map<Category, int> _afterCast(
      Plan action, Ability focus, Map<Category, int> gained) {
    final out = Map<Category, int>.of(gained);
    final trains = action == Plan.train ||
        action == Plan.special ||
        action == Plan.match ||
        action == Plan.lesson;
    if (trains && gained.isNotEmpty) {
      final mate = cast.pickTagMate(focus, rng);
      if (mate != null) {
        for (final k in out.keys.toList()) {
          out[k] = (out[k]! * tagMultiplier * tagTraitMultiplier(player.traits))
              .round();
        }
        mate.addBond(8);
        log.add('${mate.name}と友情タッグ練習!');
      }
    }
    if (action == Plan.lesson) {
      final coach = cast.coach;
      if (coach != null) {
        coach.tips++;
        _checkCoach();
      }
    }
    if (action == Plan.social) {
      (cast.lover ?? cast.family)?.addBond(10);
    }
    return out;
  }

  /// コツが貯まったら、コーチの教える特性を習得する。
  void _checkCoach() {
    final coach = cast.coach;
    if (coach == null || coach.tips < tipsNeeded) return;
    coach.tips = 0;
    final t = coach.teaches;
    if (t != null && canGain(player.traits, t)) {
      player = player.copyWith(traits: gain(player.traits, t));
      log.add('${coach.name}のコツをつかんだ! 特性「${t.label}」を習得。');
      _note('trait', '特性「${t.label}」を習得(コーチ ${coach.name})');
    } else {
      exp = exp.add(spreadExp(player.role, 40));
      log.add('${coach.name}から多くを学んだ。(経験点を獲得)');
    }
  }

  void _require(Phase p) {
    if (phase != p) throw StateError('いまは ${phase.name} の段階: ${p.name} は選べない');
  }

  ({int team, List<int> opponents}) get _league => switch (stage) {
        Stage.youth => (team: 35, opponents: const [25, 30, 35, 40]),
        Stage.juniorHigh => (team: 42, opponents: const [32, 38, 44, 50]),
        Stage.highSchool => (team: 50, opponents: const [40, 46, 52, 58, 64]),
        Stage.pathChoice => (team: 58, opponents: const [48, 54, 60, 66]),
        _ => (team: 65, opponents: const [55, 60, 66, 72, 78]),
      };

  /// 年の初めに、今年の目標を決める。
  void _newGoal() {
    if (phase == Phase.retired) return;
    goal = makeGoal(
      stage: stage,
      role: player.role,
      ov: overall(player),
      rounds: _league.opponents.length,
      pick: rng.nextDouble(),
    );
  }

  /// 成績が出たら、目標を判定して、達成なら経験点と気持ちをもらう。
  void _judgeGoal(SeasonRecord r) {
    final g = goal;
    if (g == null || g.achieved != null) return;
    g.achieved = g.judge(r);
    if (g.achieved!) {
      final n = goalRewardExp(stage);
      exp = exp.add(spreadExp(player.role, n));
      condition =
          condition.copyWith(morale: condition.morale + goalRewardMorale);
      log.add('今年の目標「${g.text}」を達成! 経験点+$n(全種類)');
    } else {
      condition = condition.copyWith(morale: condition.morale + goalMissMorale);
      log.add('今年の目標「${g.text}」には届かなかった。');
    }
  }

  /// 大会(アマチュア)またはシーズン(プロ)を行い、成績を残す。
  void _playSummer() {
    final l = _league;
    final isPro = stage == Stage.pro;
    // 作戦: その大会だけ能力が変わる。研究はチーム力が上がる。
    final fighter = traitAdjusted(tacticAdjusted(player, tactic));
    final team = l.team +
        tacticTeamBonus(tactic) +
        traitTeamBonus(player.traits) +
        positionTeamAdjust(player, effectivePos);
    final tournament = isPro
        ? null
        : playTournament(
            fighter,
            teamLevel: team,
            opponents: l.opponents,
            rng: rng,
            condition: condition.value,
          );
    final league = isPro
        ? playLeagueSeason(
            fighter,
            teamLevel: team,
            opponents: l.opponents,
            rng: rng,
            condition: condition.value,
          )
        : null;

    var ach = tournament?.achievement ?? 0;
    bool? rivalWon;
    final rival = cast.rival;
    if (rival != null) {
      final mine = overall(player) + (rng.nextDouble() * 2 - 1) * 8;
      if (mine >= rivalLevel(rival, player.age)) {
        rivalWon = true;
        cast.rivalWins++;
        ach = min(100, ach + 5);
        condition = condition.copyWith(morale: condition.morale + 10);
        log.add('${rival.name}に勝った!');
      } else {
        rivalWon = false;
        cast.rivalLosses++;
        condition = condition.copyWith(morale: condition.morale - 8);
        log.add('${rival.name}に負けた…');
      }
      rival.addBond(5);
    }

    tactic = Tactic.steady;
    if (league != null) {
      final titles =
          titlesOf(league.line, games: league.games, rank: league.rank);
      final rec = SeasonRecord(
        age: player.age,
        stage: stage,
        line: league.line,
        teamWins: league.wins,
        teamLosses: league.losses,
        rank: league.rank,
        titles: titles,
        rivalWon: rivalWon,
      );
      records.add(rec);
      _judgeGoal(rec);
      if (league.rank == 1) {
        championships++;
        log.add('リーグ優勝!');
      } else {
        log.add('今季は${league.rank}位(${league.wins}勝${league.losses}敗)。');
      }
      final d = describeLine(league.line);
      if (d.isNotEmpty) log.add('今季成績: $d');
      for (final t in titles) {
        log.add('タイトル獲得: $t!');
      }
      // 契約更改(前の年からの増減)。保存はせず、成績から計算する。
      final pro = records.where((r) => r.stage == Stage.pro).toList();
      final now = salaryOf(rec);
      if (pro.length >= 2) {
        final prev = salaryOf(pro[pro.length - 2]);
        final diff = now - prev;
        final mark = diff > 0
            ? '(アップ)'
            : diff < 0
                ? '(ダウン)'
                : '(現状維持)';
        log.add('契約更改: 年俸 ${fmtSalary(prev)} → ${fmtSalary(now)} $mark');
      } else {
        log.add('契約更改: 年俸 ${fmtSalary(now)}');
      }
    } else if (tournament != null) {
      achievements.add(ach);
      final rec = SeasonRecord(
        age: player.age,
        stage: stage,
        line: tournament.line,
        roundsWon: tournament.roundsWon,
        rounds: tournament.rounds,
        rivalWon: rivalWon,
      );
      records.add(rec);
      _judgeGoal(rec);
      _logRounds(tournament);
      if (tournament.champion) {
        championships++;
        log.add('夏の大会で優勝した!');
      } else {
        log.add(tournament.roundsWon == 0
            ? '夏の大会は初戦で敗れた。'
            : '夏の大会は${tournament.roundsWon}回戦突破。');
      }
      final d = describeLine(tournament.line);
      if (d.isNotEmpty) log.add('大会成績: $d');
    }
    _playWorld();
  }

  /// 勝ち抜き戦の各試合を、ログに残す(相手・勝ち負け・自分の出来)。
  void _logRounds(Tournament t) {
    final own = affiliationOf(stage, player.name, proTeam: proTeam);
    for (var i = 0; i < t.games.length; i++) {
      final g = t.games[i];
      final name = opponentName(stage, player.age, i,
          corporate: route == Course.corporate, own: own);
      final d = describeGame(g.line);
      log.add('${g.won ? '○' : '●'} ${roundLabel(i, t.rounds)} vs $name'
          '${d.isEmpty ? '' : ' — $d'}');
    }
  }

  /// この年に世界大会があれば、代表に選ばれたかを決め、選ばれたら日本代表として戦う。
  /// 選ばれるのは総合評価が目安を上回る選手(運±6)。怪我中は辞退。
  void _playWorld() {
    final ev =
        worldEventFor(stage: stage, age: player.age, hasRoute: route != null);
    if (ev == null) return;
    if (condition.injured) {
      log.add('${ev.name}の代表候補だったが、怪我で辞退した。');
      return;
    }
    final score = overall(player) + (rng.nextDouble() * 2 - 1) * 6;
    if (score < ev.selectLine) return;
    log.add('${ev.name}の日本代表に選ばれた!');
    _note('world', '${ev.name}の日本代表に選出');
    final t = playTournament(
      traitAdjusted(tacticAdjusted(player, Tactic.steady)),
      teamLevel: ev.team +
          traitTeamBonus(player.traits) +
          positionTeamAdjust(player, effectivePos),
      opponents: ev.opponents,
      rng: rng,
      condition: condition.value + worldBonus(player.traits),
    );
    final w = wrapWorld(event: ev, age: player.age, tournament: t);
    for (var i = 0; i < t.games.length; i++) {
      final d = describeGame(t.games[i].line);
      log.add('${t.games[i].won ? '○' : '●'} ${roundLabel(i, t.rounds)} '
          'vs ${ev.countries[i]}${d.isEmpty ? '' : ' — $d'}');
    }
    worldRecords.add(w.record);
    final rec = w.record;
    if (rec.champion) {
      log.add('${ev.name}で優勝! 日本が世界一になった!');
      _note('world', '${ev.name}で優勝(世界一)');
      condition = condition.copyWith(morale: condition.morale + 25);
      exp = exp.add(spreadExp(player.role, goalRewardExp(stage)));
    } else {
      log.add('${ev.name}は${rec.lostTo}に敗れ、${rec.resultText}。');
      _note('world', '${ev.name} ${rec.resultText}');
      condition = condition.copyWith(morale: condition.morale + 8);
    }
    final d = describeLine(rec.line);
    if (d.isNotEmpty) log.add('${ev.name}の成績: $d');
  }

  void _nextSlot() {
    if (slot + 1 >= slotsPerYear(stage)) {
      _endYear();
    } else {
      slot++;
    }
  }

  void _endYear() {
    final before = stage;
    slot = 0;
    player = endOfYear(player);
    condition = endOfYearCondition(condition);
    final partner = cast.lover ?? cast.family;
    if (partner != null && partner.bond >= 50) {
      condition = condition.copyWith(fatigue: condition.fatigue - 5); // 支えてくれる
    }
    peakOverall = max(peakOverall, overall(player).round());
    overallHistory.add(overall(player).round());

    if (turnedPro) {
      proYears++;
      lowYears = nextLowYears(player, lowYears);
      if (mustRetire(player, lowYears)) {
        final why = isReleased(lowYears) ? '戦力外になった' : '年齢により引退した';
        log.add('$why。');
        _retire(isReleased(lowYears) ? '戦力外通告を受けて引退' : '年齢により引退');
      }
    } else if (route == null && player.age == proEntryAge + 1) {
      _draft();
    } else if (route != null && player.age == graduationAge(route!)) {
      _draft();
    }
    _rotateCast(before);
    _newGoal();
  }

  /// 段階が変わったら、仲間とコーチが替わる(高校で恋人が現れる)。
  void _rotateCast(Stage before) {
    if (phase == Phase.retired) return;
    final after = stage;
    if (after != before) {
      cast.rotate(after, rng, player.role, player.traits);
      if (after != Stage.pro && after != Stage.pathChoice) {
        _note('stage', '${stageNameOf(after)}に進んだ');
      }
    }
  }

  void _draft() {
    final luck = (rng.nextDouble() * 2 - 1) * draftLuck;
    final margin = draftScore(player, recentAchievement) +
        luck -
        (draftLine + difficulty.draftShift);
    if (margin >= 0) {
      turnedPro = true;
      proStartAge = player.age;
      final team = draftTeams[rng.nextInt(draftTeams.length)];
      proTeam = team;
      final round = draftRound(margin);
      log.add('ドラフトで指名された! $team から$round位指名。');
      _note('draft', '$team から$round位指名を受けて、プロ入り');
    } else if (route == null) {
      log.add('ドラフトで指名されなかった。');
      _note('draft', 'ドラフトで指名されなかった');
      phase = Phase.pathChoice;
    } else {
      log.add('再挑戦も実らなかった。');
      _note('draft', '再挑戦のドラフトでも指名されなかった');
      _retire('再挑戦も実らず引退');
    }
  }

  void _retire(String reason) {
    _note('retire', reason);
    phase = Phase.retired;
    pendingEvent = null;
    ending = _buildEnding();
  }

  Ending _buildEnding() {
    final String title;
    if (!turnedPro && proYears == 0) {
      title = 'プロにはなれなかった';
    } else if (peakOverall >= 80) {
      title = 'レジェンド';
    } else if (peakOverall >= 65) {
      title = '一流選手';
    } else if (peakOverall >= 50) {
      title = 'レギュラー';
    } else {
      title = '無名の選手';
    }
    return Ending(
      title: title,
      madePro: turnedPro,
      proYears: proYears,
      peakOverall: peakOverall,
      championships: championships,
      wasTwoWay: _wasTwoWay,
      rivalWins: cast.rivalWins,
      rivalLosses: cast.rivalLosses,
      partnerName: (cast.lover != null && cast.lover!.bond >= 80)
          ? cast.lover!.name
          : null,
      titles: [for (final r in records) ...r.titles],
    );
  }

  // ── 保存 ──

  Map<String, dynamic> toJson() => {
        'player': player.toJson(),
        'condition': condition.toJson(),
        'slot': slot,
        'exp': exp.toJson(),
        'cast': cast.toJson(),
        'phase': phase.name,
        'pendingEvent': pendingEvent?.id,
        'eventFocus': _eventFocus.name,
        'route': route?.name,
        'turnedPro': turnedPro,
        'lowYears': lowYears,
        'proYears': proYears,
        'peakOverall': peakOverall,
        'championships': championships,
        'wasTwoWay': _wasTwoWay,
        'achievements': achievements,
        'archived': archived,
        'overallHistory': overallHistory,
        'proStartAge': proStartAge,
        'proTeam': proTeam,
        'position': position?.name,
        'records': [for (final r in records) r.toJson()],
        'worldRecords': [for (final r in worldRecords) r.toJson()],
        'lifeLog': [for (final e in lifeLog) e.toJson()],
        'tactic': tactic.name,
        'goal': goal?.toJson(),
        'difficulty': difficulty.name,
      };

  /// 項目を足すときは既定値を置く(既存セーブを壊さない)。
  factory Game.fromJson(Map<String, dynamic> j, Random rng) {
    T pick<T extends Enum>(List<T> all, Object? name, T orElse) {
      for (final v in all) {
        if (v.name == name) return v;
      }
      return orElse;
    }

    final player =
        Player.fromJson((j['player'] as Map?)?.cast<String, dynamic>() ?? {});
    final castJson = (j['cast'] as Map?)?.cast<String, dynamic>();
    final g = Game._(
      rng,
      player,
      castJson != null
          ? Cast.fromJson(castJson)
          : Cast.initial(rng, player.role, player.traits),
      Difficulty.parse(j['difficulty']),
    );
    g.condition = Condition.fromJson(
        (j['condition'] as Map?)?.cast<String, dynamic>() ?? {});
    g.slot = (j['slot'] as num?)?.toInt() ?? 0;
    g.exp = ExpPool.fromJson((j['exp'] as Map?)?.cast<String, dynamic>() ?? {});
    g.phase = pick(Phase.values, j['phase'], Phase.term);
    g.pendingEvent = events.where((e) => e.id == j['pendingEvent']).firstOrNull;
    if (g.phase == Phase.event && g.pendingEvent == null) g.phase = Phase.term;
    g._eventFocus = pick(Ability.values, j['eventFocus'], Ability.contact);
    g.route = Course.values.where((r) => r.name == j['route']).firstOrNull;
    g.turnedPro = (j['turnedPro'] as bool?) ?? false;
    g.lowYears = (j['lowYears'] as num?)?.toInt() ?? 0;
    g.proYears = (j['proYears'] as num?)?.toInt() ?? 0;
    g.peakOverall = (j['peakOverall'] as num?)?.toInt() ?? 0;
    g.championships = (j['championships'] as num?)?.toInt() ?? 0;
    g.archived = (j['archived'] as bool?) ?? false;
    g.overallHistory.addAll(((j['overallHistory'] as List?) ?? const [])
        .map((e) => (e as num).toInt()));
    g.proStartAge = (j['proStartAge'] as num?)?.toInt();
    g.proTeam = j['proTeam'] as String?;
    g.position = Pos.parse(j['position'] as String?);
    g.goal = Goal.fromJson(j['goal']);
    g.tactic = Tactic.values
        .firstWhere((t) => t.name == j['tactic'], orElse: () => Tactic.steady);
    g.lifeLog.addAll([
      for (final e in (j['lifeLog'] as List?) ?? const [])
        LifeEvent.fromJson((e as Map).cast<String, dynamic>()),
    ]);
    g.worldRecords.addAll([
      for (final r in (j['worldRecords'] as List?) ?? const [])
        WorldRecord.fromJson((r as Map).cast<String, dynamic>()),
    ]);
    g.records.addAll([
      for (final r in (j['records'] as List?) ?? const [])
        SeasonRecord.fromJson((r as Map).cast<String, dynamic>()),
    ]);
    g._wasTwoWay = (j['wasTwoWay'] as bool?) ?? g.player.role == Role.twoWay;
    g.achievements.addAll(((j['achievements'] as List?) ?? const [])
        .map((e) => (e as num).toDouble()));
    g.slot = g.slot.clamp(0, slotsPerYear(g.stage) - 1);
    if (g.phase == Phase.retired) g.ending = g._buildEnding();
    return g;
  }
}
