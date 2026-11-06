import 'dart:math' as math;

import 'draft.dart';
import 'league.dart';
import 'names.dart';
import 'player.dart';
import 'rng.dart';
import 'trade.dart';

/// 任される年数。
const careerSeasons = 10;

/// 任されたときのチームの状態(強さの順位から決まる。0始まり)。
enum Outlook {
  contender('優勝候補', '主力がそろい、すぐに優勝を狙える。オーナーの期待も高い。'),
  playoff('プレーオフ圏', 'プレーオフには届く力。あと一押しで上を狙える。'),
  bubble('瀬戸際', 'プレーオフに届くかどうか。補強しだいで上にも下にも行く。'),
  rebuild('立て直し', '下位のチーム。若手を育て、指名権を集めて先を見る。オーナーは気長に待ってくれる。');

  const Outlook(this.label, this.text);
  final String label;
  final String text;

  static Outlook of(int rank) => rank < 6
      ? Outlook.contender
      : rank < 14
          ? Outlook.playoff
          : rank < 22
              ? Outlook.bubble
              : Outlook.rebuild;
}

/// はじめのオーナーの信頼。
const startTrust = 50;

/// 進み具合。
enum Phase {
  /// シーズン前。トレードと補強ができる。
  preseason,

  /// シーズン中(20〜21試合ずつ4区切り)。
  season,

  /// レギュラーシーズンを終えた。次はプレーオフ。
  playoffs,

  /// シーズンを終えた(結果とオーナーの評価)。
  seasonEnd,

  /// オフ: 成長と引退の知らせを見たあと、ドラフト。
  draft,

  /// オフ: 契約切れの選手との再契約と、自由契約の選手との契約。
  contracts,

  /// 任期が終わった(10年を終えた・解任された)。
  over,
}

/// 1シーズンの記録。
class SeasonRecord {
  SeasonRecord({required this.season, required this.wins, required this.losses, required this.rank, required this.result, required this.trustAfter, required this.target});

  final int season;
  final int wins;
  final int losses;
  final int rank;

  /// 0: プレーオフに出られず、1: 1回戦で敗退、2: 2回戦で敗退、3: 地区決勝で敗退、4: ファイナルで敗退、5: 優勝。
  final int result;
  final int trustAfter;
  final int target;

  bool get champion => result == 5;

  String get resultLabel => resultLabels[result.clamp(0, 5)];

  Map<String, dynamic> toJson() => {'s': season, 'w': wins, 'l': losses, 'r': rank, 'x': result, 't': trustAfter, 'g': target};

  static SeasonRecord fromJson(Map<String, dynamic> j) => SeasonRecord(
        season: j['s'] as int,
        wins: j['w'] as int,
        losses: j['l'] as int,
        rank: j['r'] as int,
        result: j['x'] as int,
        trustAfter: j['t'] as int,
        target: (j['g'] as int?) ?? 0,
      );
}

const resultLabels = ['プレーオフ届かず', '1回戦で敗退', '2回戦で敗退', '地区決勝で敗退', 'ファイナルで敗退', '優勝'];

/// プレーオフの結果ごとに増えるオーナーの信頼。
const resultTrust = [0, 4, 8, 13, 19, 28];

/// 契約切れの選手が求める条件。
class Ask {
  const Ask(this.salary, this.maxYears);
  final int salary;
  final int maxYears;
}

/// GMの任期1回分。仕組みはすべてここにあり、画面はこれを呼ぶだけ。
class Career {
  Career._({required this.seed, required this.mine, required this.rng, required this.teams});

  /// 新しく任される。リーグは [seed] だけで決まる(どのチームを選んでも同じリーグになる)。[team] が自分のチーム。
  factory Career.start({required int seed, int team = 0}) {
    final rng = Rng(seed);
    final c = Career._(seed: seed, mine: team.clamp(0, teamDefs.length - 1), rng: rng, teams: []);
    c._build();
    c.startRank = c.strengthRank(c.mine);
    return c;
  }

  final int seed;
  final Rng rng;
  final List<Team> teams;

  /// 自分のチーム。
  final int mine;
  Team get me => teams[mine];

  /// 任されたときの強さの順位(0始まり)と、そこから決まるチームの状態。
  int startRank = 0;
  Outlook get outlook => Outlook.of(startRank);

  int season = 1;
  Phase phase = Phase.preseason;

  /// 今のシーズンで終えた区切り(0〜4)。
  int block = 0;

  /// 直前の区切りの、自分のチームの試合。
  List<GameResult> lastGames = [];

  /// プレーオフ(プレーイン・1回戦・2回戦・地区決勝・ファイナルの順)。
  List<Series> playoffs = [];

  /// 自由契約の選手。
  List<Player> freeAgents = [];

  /// 指名権(今年と来年の分)。
  List<DraftPick> picks = [];

  /// ドラフトの候補・順番・何番目まで進んだか。
  List<Prospect> prospects = [];
  List<int> order = [];
  int draftAt = 0;

  /// 指名された順の候補(prospects の番号)。
  List<int> draftLog = [];
  int scoutsLeft = 0;
  bool scoutAdUsed = false;

  /// 契約の話し合いを待っている自分の選手(id)。
  List<int> expiring = [];

  /// オーナーの信頼(0で解任)と、今シーズンの勝ち数の目標。
  int trust = 50;
  int target = 0;

  /// 解任を1度だけ取り消せる(動画)。
  bool rescueUsed = false;
  bool fired = false;

  List<SeasonRecord> history = [];

  /// オフの知らせ(成長・引退など)。
  List<String> news = [];

  /// 相手から届いているトレードの申し込み。
  TradeOffer? incoming;

  int tradesDone = 0;

  /// リーグのニュース(新しい順、[logLimit] 件まで)。トレード・大物の移籍・ドラフト1位・優勝・引退。
  List<String> log = [];
  static const logLimit = 60;

  void _log(String text) {
    log.insert(0, '$season年目 $text');
    if (log.length > logLimit) log.removeRange(logLimit, log.length);
  }

  String _names(List<Player> ps) => ps.map((p) => p.name).join('・');

  /// トレードの中身を1行にする。
  String _tradeText(int a, int b, TradeOffer o, List<Player> give, List<Player> get) {
    String side(List<Player> ps, List<int> ix) => [
          if (ps.isNotEmpty) _names(ps),
          for (final i in ix) '指名権(${picks[i].label(teams, season)})',
        ].join('・');
    return 'トレード: ${teams[a].def.short}が${side(give, o.givePicks)}を出し、${teams[b].def.short}から${side(get, o.getPicks)}を獲得';
  }

  /// 前のシーズンのぜいたく税で下がった信頼。
  int lastTax = 0;

  /// 指名して入団した選手の id(生え抜き)。
  List<int> draftedIds = [];

  int _nextId = 1;
  int nextId() => _nextId++;

  // ---------------------------------------------------------------- はじめ

  void _build() {
    trust = startTrust;
    final qualities = [for (var i = 0; i < teamDefs.length; i++) -5.5 + 10 * i / (teamDefs.length - 1)];
    rng.shuffle(qualities);
    for (var i = 0; i < teamDefs.length; i++) {
      final q = qualities[i];
      // 弱いチームは若く、強いチームの一部は主力が年寄りで年俸が高い(チームごとに違う状態にする)
      final style = q <= -3 && rng.chance(0.7)
          ? 1
          : q >= 3 && rng.chance(0.5)
              ? 2
              : 0;
      teams.add(Team(index: i, roster: _makeRoster(q, style)));
    }
    for (final s in [season, season + 1]) {
      for (final r in [1, 2]) {
        for (var t = 0; t < teams.length; t++) {
          picks.add(DraftPick(season: s, round: r, from: t, owner: t));
        }
      }
    }
    freeAgents = [for (var i = 0; i < 12; i++) _filler()];
    _setModes();
  }

  /// 14人の選手を作る。[q] はチームの強さのずれ、[style] は 1: 若い、2: 年寄りで年俸が高い。
  List<Player> _makeRoster(double q, int style) {
    const tmpl = [80, 75, 72, 70, 68, 66, 64, 62, 60, 57, 55, 53, 50, 48];
    // ポジションはチームごとに並べ替える(エースがどのチームも同じポジションにならないように)。
    // 先発の5人は5つのポジションに1人ずつ、控えも2・3人ずつ
    final posCycle = <Pos>[];
    for (final n in [5, 5, 4]) {
      final ps = [...Pos.values];
      rng.shuffle(ps);
      posCycle.addAll(ps.take(n));
    }
    final roster = <Player>[];
    for (var k = 0; k < tmpl.length; k++) {
      final ovr = (tmpl[k] + q + rng.nextInt(5) - 2).round().clamp(42, 92);
      int age;
      if (style == 1) {
        age = 20 + rng.nextInt(6);
      } else if (style == 2 && k < 5) {
        age = 30 + rng.nextInt(4);
      } else {
        age = 21 + rng.nextInt(12);
      }
      final room = age <= 22 ? 10 + rng.nextInt(14) : age <= 25 ? 4 + rng.nextInt(10) : age <= 27 ? rng.nextInt(5) : 0;
      final pot = (ovr + room + (style == 1 ? 4 : 0)).clamp(ovr, 96);
      var sal = (fairSalary(ovr, age) * (0.8 + rng.nextInt(45) / 100)).round();
      if (style == 2 && k < 5) sal = (sal * 1.2).round();
      roster.add(Player(
        id: nextId(),
        name: randomName(rng),
        pos: posCycle[k],
        age: age,
        ovr: ovr,
        pot: pot,
        salary: sal.clamp(minSalary, maxSalary),
        years: 1 + rng.nextInt(4),
      ));
    }
    // 年俸の合計が上限の外へ大きく出ないように整える。チームごとに空きの大きさを散らす
    final limit = style == 2 ? hardCap - 80 - rng.nextInt(120) : salaryCap - (style == 1 ? 260 : 20) - rng.nextInt(220) + 80;
    var total = roster.fold(0, (s, p) => s + p.salary);
    if (total > limit) {
      final f = limit / total;
      for (final p in roster) {
        p.salary = (p.salary * f).round().clamp(minSalary, maxSalary);
      }
    } else if (total < 950) {
      // 若いチームでも、年俸の合計が少なすぎないようにする(上限の3分の2ほどまでは払っている)
      final f = 950 / total;
      for (final p in roster) {
        p.salary = (p.salary * f).round().clamp(minSalary, maxSalary);
      }
    }
    if (style == 2) {
      total = roster.fold(0, (s, p) => s + p.salary);
      if (total < salaryCap + 120) {
        final f = (salaryCap + 120) / total;
        for (final p in roster.take(5)) {
          p.salary = (p.salary * f).round().clamp(minSalary, maxSalary);
        }
      }
    }
    return roster;
  }

  /// 最低年俸で来てくれる控えの選手。
  Player _filler() {
    final age = 23 + rng.nextInt(10);
    final ovr = 50 + rng.nextInt(9);
    return Player(id: nextId(), name: randomName(rng), pos: Pos.values[rng.nextInt(5)], age: age, ovr: ovr, pot: ovr + (age < 26 ? rng.nextInt(5) : 0), salary: minSalary, years: 1);
  }

  /// 各チームの考え方を、強さの順と年俸から決める。
  void _setModes() {
    final st = {for (final t in teams) t.index: t.strength};
    final order = [...teams]..sort((a, b) => st[b.index]!.compareTo(st[a.index]!));
    for (var r = 0; r < order.length; r++) {
      final t = order[r];
      if (t.payroll > salaryCap + 150 && r >= 6) {
        t.mode = TeamMode.cutCost;
      } else if (r < 6) {
        t.mode = TeamMode.contend;
      } else if (r >= order.length - 10) {
        t.mode = TeamMode.rebuild;
      } else {
        t.mode = TeamMode.balanced;
      }
    }
  }

  /// 強さの順位(0が1位)。
  int strengthRank(int team) {
    final mine = teams[team].strength;
    return teams.where((t) => t.index != team && t.strength > mine).length;
  }

  // ---------------------------------------------------------------- シーズン

  /// シーズンを始められない理由(始められるなら null)。
  String? get startProblem {
    if (me.roster.length < minRoster) return '選手が$minRoster人そろっていない(いま${me.roster.length}人)';
    if (me.roster.length > maxRoster) return '選手が$maxRoster人を超えている(いま${me.roster.length}人)';
    if (me.payroll > hardCap) return '年俸の合計が上限(${money(hardCap)})を超えている';
    return null;
  }

  bool get canTrade => phase == Phase.preseason || phase == Phase.contracts || (phase == Phase.season && block < tradeDeadlineBlock);

  /// 自由契約の選手と契約できるか(シーズン中も最低年俸の選手なら取れる)。
  bool get canSign => phase == Phase.preseason || phase == Phase.contracts || phase == Phase.season;

  void startSeason() {
    if (phase != Phase.preseason || startProblem != null) return;
    for (final t in teams) {
      t.wins = 0;
      t.losses = 0;
      if (t.index != mine) _aiTrim(t);
    }
    _setModes();
    final r = strengthRank(mine);
    target = (gamesPerSeason * (0.72 - r * 0.016)).round();
    block = 0;
    lastGames = [];
    playoffs = [];
    incoming = null;
    phase = Phase.season;
  }

  /// 次の区切り(20〜21試合)を進める。
  void playBlock() {
    if (phase != Phase.season || block >= blocksPerSeason) return;
    incoming = null;
    final games = <GameResult>[];
    final start = blockStart(block);
    for (final round in seasonSchedule(teams.length).sublist(start, start + blockSizes[block])) {
      for (final (h, a) in round) {
        final g = playGame(teams[h], teams[a], rng, mine: mine);
        if (g.involves(mine)) games.add(g);
      }
    }
    lastGames = games;
    block++;
    if (block <= tradeDeadlineBlock && rng.chance(0.5)) _aiTrades(1);
    if (block >= blocksPerSeason) {
      phase = Phase.playoffs;
    } else if (rng.chance(0.6)) {
      _makeIncoming();
    }
  }

  void _makeIncoming() {
    if (block >= tradeDeadlineBlock) return;
    final others = [for (var i = 0; i < teams.length; i++) if (i != mine) i];
    rng.shuffle(others);
    for (final t in others.take(4)) {
      final o = makeIncomingOffer(teams, picks, mine, t, season);
      if (o != null) {
        incoming = o;
        return;
      }
    }
  }

  /// 届いた申し込みを受ける。
  bool acceptIncoming() {
    final o = incoming;
    if (o == null || !canTrade) return false;
    incoming = null;
    if (!judgeTrade(teams, picks, mine, o, season).ok) return false;
    _logTrade(mine, o);
    applyTrade(teams, picks, mine, o);
    tradesDone++;
    return true;
  }

  void declineIncoming() => incoming = null;

  /// プレーオフ。地区ごとに1〜6位はそのまま、7〜10位はプレーインで2枠を争う。どの回戦も4勝で勝ち抜け。
  void playPlayoffs() {
    if (phase != Phase.playoffs) return;
    playoffs = [];
    final champs = <int>[];
    for (final east in [true, false]) {
      final st = standings(teams, east: east).map((t) => t.index).toList();
      // プレーイン: 7位と8位の勝者が7番目。敗者と、9位と10位の勝者が8番目を争う
      final a = _series(st[6], st[7], 1, 0);
      final b = _series(st[8], st[9], 1, 0);
      final c = _series(a.loser, b.winner, 1, 0);
      final seeds = [...st.take(directSeeds), a.winner, c.winner];
      // 1回戦: 1-8・4-5・2-7・3-6。勝ち上がりは山の形のまま
      var alive = [seeds[0], seeds[7], seeds[3], seeds[4], seeds[1], seeds[6], seeds[2], seeds[5]];
      for (var round = 1; alive.length > 1; round++) {
        final next = <int>[];
        for (var k = 0; k < alive.length; k += 2) {
          final hi = st.indexOf(alive[k]) < st.indexOf(alive[k + 1]) ? alive[k] : alive[k + 1];
          final lo = hi == alive[k] ? alive[k + 1] : alive[k];
          next.add(_series(hi, lo, 4, round).winner);
        }
        alive = next;
      }
      champs.add(alive.single);
    }
    // ファイナルは、シーズンの成績が上のほうがホーム
    final all = standings(teams).map((t) => t.index).toList();
    final hi = all.indexOf(champs[0]) < all.indexOf(champs[1]) ? champs[0] : champs[1];
    _series(hi, hi == champs[0] ? champs[1] : champs[0], 4, 4);
    _closeSeason();
    _log('優勝: ${teams[champion].name}(ファイナルで${teams[finals!.loser].def.short}を${finals!.winner == finals!.high ? finals!.highWins : finals!.lowWins}勝${finals!.winner == finals!.high ? finals!.lowWins : finals!.highWins}敗)');
    phase = Phase.seasonEnd;
  }

  Series _series(int high, int low, int need, int round) {
    final s = Series(high: high, low: low, need: need, round: round)..play(teams, rng, mine);
    playoffs.add(s);
    return s;
  }

  /// ファイナル。
  Series? get finals => playoffs.isNotEmpty && playoffs.last.round == 4 ? playoffs.last : null;

  int get champion => finals?.winner ?? -1;

  /// 自分のチームのプレーオフの結果(0〜5)。
  int get myResult {
    if (finals == null) return 0;
    if (champion == mine) return 5;
    for (final s in playoffs) {
      if (s.round >= 1 && s.loser == mine) return s.round;
    }
    return 0;
  }

  /// 自分の地区での順位(1始まり)。
  int get confRank => standings(teams, east: me.east).indexWhere((t) => t.index == mine) + 1;

  void _closeSeason() {
    final res = myResult;
    lastTax = luxuryTaxTrust(me.payroll);
    final delta = ((me.wins - target) * 1.5).round() + resultTrust[res] - lastTax;
    trust = (trust + delta).clamp(0, 100);
    history.add(SeasonRecord(season: season, wins: me.wins, losses: me.losses, rank: confRank, result: res, trustAfter: trust, target: target));
    if (trust <= 0) fired = true;
  }

  /// 前のシーズンの、オーナーの信頼の変わり方。
  int get lastTrustDelta {
    if (history.isEmpty) return 0;
    final prev = history.length >= 2 ? history[history.length - 2].trustAfter : startTrust;
    return history.last.trustAfter - prev;
  }

  /// 解任を取り消す(動画を見たとき。1度だけ)。信頼は少し戻る。
  bool get canRescue => fired && !rescueUsed && phase == Phase.seasonEnd;

  void rescue() {
    if (!canRescue) return;
    rescueUsed = true;
    fired = false;
    trust = 15;
    history.last = SeasonRecord(
      season: history.last.season,
      wins: history.last.wins,
      losses: history.last.losses,
      rank: history.last.rank,
      result: history.last.result,
      trustAfter: trust,
      target: history.last.target,
    );
  }

  // ---------------------------------------------------------------- オフ

  /// シーズンを閉じてオフへ(成長・引退・契約の年数を進め、ドラフトの準備をする)。
  void toOffseason() {
    if (phase != Phase.seasonEnd) return;
    if (fired || season >= careerSeasons) {
      phase = Phase.over;
      return;
    }
    news = [];
    for (final t in teams) {
      t.deadCap = 0;
      final retired = <Player>[];
      for (final p in t.roster) {
        final d = ageOneYear(p, rng);
        p.years--;
        if (t.index == mine) {
          if (d >= 4) news.add('${p.name}が大きく伸びた(力 ${p.ovr}、+$d)');
          if (d <= -4) news.add('${p.name}の力が落ちた(力 ${p.ovr}、$d)');
        }
        if (retires(p, rng)) retired.add(p);
      }
      for (final p in retired) {
        t.roster.remove(p);
        if (t.index == mine) news.add('${p.name}(${p.age}歳)が引退した');
        if (p.ovr >= 72 || t.index == mine) _log('引退: ${p.name}(${t.def.short}・${p.age}歳)');
      }
    }
    for (final p in freeAgents) {
      ageOneYear(p, rng);
    }
    freeAgents.removeWhere((p) => retires(p, rng) || p.ovr < 45);
    // ドラフト
    // 1回戦に出たチーム(プレーインを勝ち抜いたチームを含む)は、くじに入らない
    final inPlayoffs = {for (final s in playoffs.where((s) => s.round == 1)) ...[s.high, s.low]}.toList();
    order = draftOrder(teams, picks, season, inPlayoffs, rng);
    prospects = makeProspects(rng, nextId, order.length + 8);
    draftAt = 0;
    draftLog = [];
    scoutsLeft = 3;
    scoutAdUsed = false;
    phase = Phase.draft;
    _advanceDraft();
  }

  /// 今の指名権(ドラフト中)。
  DraftPick? get currentPick => phase == Phase.draft && draftAt < order.length ? picks[order[draftAt]] : null;

  bool get myTurn => currentPick?.owner == mine;

  /// 自分の番まで、相手のチームの指名を進める。
  void _advanceDraft() {
    while (phase == Phase.draft && draftAt < order.length && picks[order[draftAt]].owner != mine) {
      final pick = picks[order[draftAt]];
      final t = teams[pick.owner];
      final p = aiDraftChoice(prospects, t.mode, rng);
      _sign(t, p, draftAt);
      draftAt++;
    }
    if (draftAt >= order.length) _endDraft();
  }

  void _sign(Team t, Prospect p, int overall) {
    p.pickedBy = t.index;
    draftLog.add(prospects.indexOf(p));
    if (overall == 0) _log('ドラフト全体1位: ${p.player.name}(${t.def.short})');
    final (sal, yrs) = rookieContract(overall);
    p.player
      ..salary = sal
      ..years = yrs
      ..drafted = t.name;
    t.roster.add(p.player);
    if (t.index == mine) draftedIds.add(p.player.id);
  }

  /// 自分の番で、候補を指名する。
  void pickProspect(Prospect p) {
    if (!myTurn || p.pickedBy != null) return;
    _sign(me, p, draftAt);
    draftAt++;
    _advanceDraft();
  }

  /// 自分の番を飛ばす(指名しない)。
  void passPick() {
    if (!myTurn) return;
    draftAt++;
    _advanceDraft();
  }

  void scoutProspect(Prospect p) {
    if (phase != Phase.draft || scoutsLeft <= 0 || p.scouted || p.pickedBy != null) return;
    scoutsLeft--;
    scout(p, rng);
  }

  /// 動画を見てスカウトを2回増やす(ドラフトごとに1度)。
  bool get canAddScouts => phase == Phase.draft && !scoutAdUsed && draftAt < order.length;

  void addScouts() {
    if (!canAddScouts) return;
    scoutAdUsed = true;
    scoutsLeft += 2;
  }

  void _endDraft() {
    // 指名されなかった候補の一部は、最低年俸の自由契約に
    for (final p in prospects.where((p) => p.pickedBy == null).take(4)) {
      p.player
        ..salary = minSalary
        ..years = 1;
      freeAgents.add(p.player);
    }
    // 指名権を1年進める
    picks.removeWhere((p) => p.season <= season);
    for (final r in [1, 2]) {
      for (var t = 0; t < teams.length; t++) {
        picks.add(DraftPick(season: season + 2, round: r, from: t, owner: t));
      }
    }
    _startContracts();
  }

  void _startContracts() {
    phase = Phase.contracts;
    expiring = [for (final p in me.roster) if (p.years <= 0) p.id];
    // 相手のチームの契約切れ
    for (final t in teams) {
      if (t.index == mine) continue;
      for (final p in [...t.roster.where((p) => p.years <= 0)]) {
        final ask = askOf(p, t);
        final keep = (p.ovr >= 62 || playerValue(p, t.mode) > 10) && t.payroll - p.salary + ask.salary <= hardCap - 40 && rng.chance(0.95);
        if (keep) {
          p
            ..salary = ask.salary
            ..years = 1 + rng.nextInt(ask.maxYears);
        } else {
          t.roster.remove(p);
          freeAgents.add(p);
        }
      }
    }
    while (freeAgents.where((p) => p.salary <= minSalary).length < 6) {
      freeAgents.add(_filler());
    }
    for (final p in freeAgents) {
      p.salary = askOf(p, me).salary;
    }
    freeAgents.sort((a, b) => b.ovr.compareTo(a.ovr));
  }

  /// 選手が求める年俸。弱いチームには高く、強いチームには少し安く言う。
  Ask askOf(Player p, Team t) {
    final last = history.isEmpty ? null : history.last;
    var f = 1.0;
    if (t.index == mine && last != null) {
      if (last.champion) {
        f = 0.92;
      } else if (last.wins < gamesPerSeason * 0.4) {
        f = 1.12;
      }
    }
    final sal = p.ovr < 58 ? minSalary : (fairSalary(p.ovr, p.age) * f).round().clamp(minSalary, maxSalary);
    final maxYears = p.age >= 33 ? 1 : p.age >= 30 ? 2 : 4;
    return Ask(sal, maxYears);
  }

  Player? _mineById(int id) {
    for (final p in me.roster) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// 契約切れの選手と再契約できない理由(できるなら null)。再契約は年俸の上限を超えてもよい(合計の上限までは)。
  String? resignProblem(Player p) {
    final ask = askOf(p, me);
    if (me.payroll - p.salary + ask.salary > hardCap) return '年俸の合計が上限(${money(hardCap)})を超える';
    return null;
  }

  void resign(int id, int years) {
    final p = _mineById(id);
    if (phase != Phase.contracts || p == null || !expiring.contains(id) || resignProblem(p) != null) return;
    final ask = askOf(p, me);
    p
      ..salary = ask.salary
      ..years = years.clamp(1, ask.maxYears);
    expiring.remove(id);
  }

  void letGo(int id) {
    final p = _mineById(id);
    if (phase != Phase.contracts || p == null || !expiring.contains(id)) return;
    expiring.remove(id);
    me.roster.remove(p);
    p.salary = askOf(p, teams[(mine + 1) % teams.length]).salary;
    freeAgents
      ..add(p)
      ..sort((a, b) => b.ovr.compareTo(a.ovr));
  }

  /// 自由契約の選手と契約できない理由。
  String? signProblem(Player p) {
    if (!canSign) return '今は契約できない';
    if (me.roster.length - expiring.length >= maxRoster) return '登録が15人いっぱい';
    final ask = askOf(p, me);
    if (phase == Phase.season && ask.salary > minSalary) return 'シーズン中は最低年俸の選手だけ';
    if (ask.salary > minSalary && me.payroll + ask.salary > salaryCap) return '年俸の上限まで${money(math.max(0, me.capRoom))}しか空きがない';
    return null;
  }

  void signFreeAgent(int id, int years) {
    final i = freeAgents.indexWhere((p) => p.id == id);
    if (i < 0) return;
    final p = freeAgents[i];
    if (signProblem(p) != null) return;
    final ask = askOf(p, me);
    p
      ..salary = ask.salary
      ..years = years.clamp(1, ask.maxYears);
    freeAgents.removeAt(i);
    me.roster.add(p);
  }

  /// 選手を放す。今シーズンの年俸は、そのまま合計に残る。
  void release(int id) {
    final p = _mineById(id);
    if (p == null || expiring.contains(id) || !(phase == Phase.preseason || phase == Phase.season || phase == Phase.contracts)) return;
    me.roster.remove(p);
    me.deadCap += p.salary;
    p
      ..salary = askOf(p, teams[(mine + 1) % teams.length]).salary
      ..years = 1;
    freeAgents
      ..add(p)
      ..sort((a, b) => b.ovr.compareTo(a.ovr));
  }

  /// オフを終えてシーズン前へ。残った契約切れの選手は放し、相手のチームが自由契約の選手を取る。
  void finishContracts() {
    if (phase != Phase.contracts) return;
    for (final id in [...expiring]) {
      letGo(id);
    }
    _aiFreeAgency();
    for (final t in teams) {
      if (t.index != mine) _aiTrim(t);
    }
    season++;
    _setModes();
    _aiTrades(1);
    phase = Phase.preseason;
    _setModes();
  }

  void _aiFreeAgency() {
    final others = [for (final t in teams) if (t.index != mine) t];
    for (final p in [...freeAgents]..sort((a, b) => b.ovr.compareTo(a.ovr))) {
      rng.shuffle(others);
      for (final t in others) {
        final ask = askOf(p, t);
        if (t.roster.length >= 15) continue;
        if (ask.salary > minSalary && t.payroll + ask.salary > salaryCap) continue;
        if (p.ovr < 60 && t.roster.length >= 13) continue;
        p
          ..salary = ask.salary
          ..years = 1 + rng.nextInt(ask.maxYears);
        t.roster.add(p);
        freeAgents.remove(p);
        if (p.ovr >= 70) _log('移籍: ${p.name}(力${p.ovr})が${t.def.short}と${p.years}年契約');
        break;
      }
    }
    for (final t in others) {
      while (t.roster.length < 13) {
        t.roster.add(_filler());
      }
    }
    while (freeAgents.where((p) => p.salary <= minSalary).length < 6) {
      freeAgents.add(_filler());
    }
  }

  /// 相手のチームの人数を15人以内に保つ(力の低い順に放す)。
  void _aiTrim(Team t) {
    while (t.roster.length > maxRoster) {
      final worst = t.roster.reduce((a, b) => a.ovr <= b.ovr ? a : b);
      t.roster.remove(worst);
    }
  }

  // ---------------------------------------------------------------- トレード

  TradeVerdict judge(TradeOffer o) {
    if (!canTrade) return const TradeVerdict(false, '今はトレードできない(締め切りを過ぎた)', 0);
    if (o.give.any(expiring.contains)) return const TradeVerdict(false, '契約の話し合い中の選手は出せない', 0);
    return judgeTrade(teams, picks, mine, o, season);
  }

  bool propose(TradeOffer o) {
    final v = judge(o);
    if (!v.ok) return false;
    _logTrade(mine, o);
    applyTrade(teams, picks, mine, o);
    tradesDone++;
    incoming = null;
    return true;
  }

  void _logTrade(int from, TradeOffer o) {
    final give = [for (final id in o.give) teams[from].roster.firstWhere((p) => p.id == id)];
    final get = [for (final id in o.get) teams[o.partner].roster.firstWhere((p) => p.id == id)];
    _log(_tradeText(from, o.partner, o, give, get));
  }

  /// 「相手に聞く」: [partner] から [get] を受け取るのに、こちらが出せばよい組み合わせ。契約の話し合い中の選手は出さない。
  TradeOffer? askPartner(int partner, {List<int> get = const [], List<int> getPicks = const []}) {
    if (!canTrade || (get.isEmpty && getPicks.isEmpty)) return null;
    return findPackage(teams, picks, mine, partner, get: get, getPicks: getPicks, exclude: expiring, nowSeason: season);
  }

  /// 相手のチーム同士のトレード。優勝を狙うチームが、立て直し中・年俸を減らしたいチームのベテランを、若手や指名権で取る。
  /// どちらの見方でも損にならないときだけ成立する。
  void _aiTrades(int count) {
    final buyers = [for (final t in teams) if (t.index != mine && (t.mode == TeamMode.contend || t.mode == TeamMode.balanced)) t.index];
    final sellers = [for (final t in teams) if (t.index != mine && (t.mode == TeamMode.rebuild || t.mode == TeamMode.cutCost)) t.index];
    rng.shuffle(buyers);
    var done = 0;
    // 探すのは重いので、試す組み合わせの数を絞る(買い手4つ×売り手2つまで)
    for (final a in buyers.take(4)) {
      if (done >= count) break;
      rng.shuffle(sellers);
      for (final b in sellers.take(2)) {
        final vets = teams[b].roster.where((p) => p.age >= 27 && p.ovr >= 68).toList()..sort((x, y) => y.ovr.compareTo(x.ovr));
        if (vets.isEmpty) continue;
        final target = vets.first;
        final o = findPackage(teams, picks, a, b, get: [target.id], nowSeason: season);
        if (o == null) continue;
        // 取る側から見ても得か
        final give = [for (final id in o.give) teams[a].roster.firstWhere((p) => p.id == id)];
        final out = give.fold(0.0, (s, p) => s + playerValue(p, teams[a].mode)) +
            o.givePicks.fold(0.0, (s, i) => s + pickValue(picks[i], teams[a].mode, slotGuess(teams, picks[i].from), season));
        if (playerValue(target, teams[a].mode) < out) continue;
        _log(_tradeText(a, b, o, give, [target]));
        applyTrade(teams, picks, a, o);
        done++;
        break;
      }
    }
  }

  /// 自分の持っている指名権(全体の並びでの番号)。
  List<int> picksOf(int team) => [for (var i = 0; i < picks.length; i++) if (picks[i].owner == team) i];

  // ---------------------------------------------------------------- 保存

  Map<String, dynamic> toJson() => {
        'v': 1,
        'seed': seed,
        'mine': mine,
        'sr': startRank,
        'rng': rng.state,
        'teams': [for (final t in teams) t.toJson()],
        'season': season,
        'phase': phase.index,
        'block': block,
        'lg': [for (final g in lastGames) g.toJson()],
        'po': [for (final s in playoffs) s.toJson()],
        'fa': [for (final p in freeAgents) p.toJson()],
        'picks': [for (final p in picks) p.toJson()],
        'pros': [for (final p in prospects) p.toJson()],
        'order': order,
        'da': draftAt,
        'dl': draftLog,
        'sl': scoutsLeft,
        'sau': scoutAdUsed,
        'exp': expiring,
        'trust': trust,
        'target': target,
        'ru': rescueUsed,
        'fired': fired,
        'hist': [for (final h in history) h.toJson()],
        'news': news,
        if (incoming != null) 'inc': incoming!.toJson(),
        'td': tradesDone,
        'log': log,
        'tax': lastTax,
        'dr': draftedIds,
        'nid': _nextId,
      };

  static Career fromJson(Map<String, dynamic> j) {
    List<Map<String, dynamic>> maps(String k) => [for (final x in (j[k] as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
    final c = Career._(
      seed: j['seed'] as int,
      mine: ((j['mine'] as int?) ?? 0).clamp(0, teamDefs.length - 1),
      rng: Rng(j['seed'] as int)..state = j['rng'] as int,
      teams: [for (final t in maps('teams')) Team.fromJson(t)],
    );
    if (c.teams.length != teamDefs.length) throw const FormatException('teams');
    c
      ..startRank = (j['sr'] as int?) ?? 0
      ..season = j['season'] as int
      ..phase = Phase.values[(j['phase'] as int).clamp(0, Phase.values.length - 1)]
      ..block = j['block'] as int
      ..lastGames = [for (final g in maps('lg')) GameResult.fromJson(g)]
      ..playoffs = [for (final s in maps('po')) Series.fromJson(s)]
      ..freeAgents = [for (final p in maps('fa')) Player.fromJson(p)]
      ..picks = [for (final p in maps('picks')) DraftPick.fromJson(p)]
      ..prospects = [for (final p in maps('pros')) Prospect.fromJson(p)]
      ..order = [for (final x in (j['order'] as List? ?? const [])) x as int]
      ..draftAt = (j['da'] as int?) ?? 0
      ..draftLog = [for (final x in (j['dl'] as List? ?? const [])) x as int]
      ..scoutsLeft = (j['sl'] as int?) ?? 0
      ..scoutAdUsed = (j['sau'] as bool?) ?? false
      ..expiring = [for (final x in (j['exp'] as List? ?? const [])) x as int]
      ..trust = (j['trust'] as int?) ?? 50
      ..target = (j['target'] as int?) ?? 0
      ..rescueUsed = (j['ru'] as bool?) ?? false
      ..fired = (j['fired'] as bool?) ?? false
      ..history = [for (final h in maps('hist')) SeasonRecord.fromJson(h)]
      ..news = [for (final x in (j['news'] as List? ?? const [])) x as String]
      ..incoming = j['inc'] == null ? null : TradeOffer.fromJson(Map<String, dynamic>.from(j['inc'] as Map))
      ..tradesDone = (j['td'] as int?) ?? 0
      ..log = [for (final x in (j['log'] as List? ?? const [])) x as String]
      ..lastTax = (j['tax'] as int?) ?? 0
      ..draftedIds = [for (final x in (j['dr'] as List? ?? const [])) x as int]
      .._nextId = (j['nid'] as int?) ?? 100000;
    return c;
  }

  /// 優勝の回数。
  int get titles => history.where((h) => h.champion).length;
}
