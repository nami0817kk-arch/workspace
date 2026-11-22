import 'dart:math';

import '../models/attributes.dart';
import '../models/cup.dart';
import '../models/match_result.dart';
import '../models/player.dart';
import '../models/team.dart';
import 'background_match_engine.dart';
import 'match_engine.dart';
import 'weather_engine.dart';
import '../l10n/tr.dart';

class CupEngine {
  static final Random _rng = Random();

  /// 1〜3部の全クラブが出る国内カップ(実在の形。2026-11-22)。
  ///
  /// [byTier]は部(1〜3)ごとのクラブ。[entryRound]は部ごとに何回戦から
  /// 入るか(既定は3部が1回戦、2部が2回戦、1部が3回戦。下の部のクラブが
  /// 先に戦い、上の部は後から入る)。部の違うクラブが当たると下の部の
  /// クラブがホームになる。回戦の人数が2の累乗に合わないときは、上の部の
  /// クラブから不戦勝で次の回戦へ回す(不戦勝の試合は作らない)。
  /// [roundDue]は決勝までの回戦の数から、各回戦を消化できるようになる節を返す。
  /// 決勝は中立の会場。[neutralSemiFinal]なら準決勝も中立(FA カップ)。
  /// [twoLeggedSemiFinal]なら準決勝は2試合合計(スペイン・イタリアの国内
  /// カップ、イングランドのリーグカップ)。
  static Cup createTiered({
    required CupType type,
    required String name,
    required Map<int, List<String>> byTier,
    Map<int, int>? entryRound,
    List<int> Function(int totalRounds)? roundDue,
    String? focusTeamId,
    bool neutralSemiFinal = false,
    bool twoLeggedSemiFinal = false,
    Random? random,
  }) {
    final rng = random ?? _rng;
    final entry = entryRound ?? defaultEntryRound;
    final tiers = <String, int>{};
    final entrants = <int, List<String>>{};
    for (final e in byTier.entries) {
      final r = entry[e.key] ?? 1;
      for (final id in e.value) {
        tiers[id] = e.key;
        (entrants[r] ??= []).add(id);
      }
    }
    if (tiers.length < 2) {
      throw ArgumentError.value(
          byTier,
          'byTier',
          Tr.pick('ノックアウト方式のカップには最低2チーム必要です',
              'A knockout cup needs at least two teams'));
    }
    // 1回戦に誰もいなければ、いちばん早く入る回戦を1回戦にずらす。
    final firstEntry = entrants.keys.reduce(min);
    final shifted = <int, List<String>>{
      for (final e in entrants.entries) e.key - firstEntry + 1: e.value,
    };
    final total = plannedRoundsFor({
      for (final e in shifted.entries) e.key: e.value.length,
    });
    final cup = Cup(
      type: type,
      name: name,
      rounds: [],
      entrants: shifted,
      tiers: tiers,
      plannedRounds: total,
      roundDue: roundDue?.call(total),
      neutralFromRound: neutralSemiFinal && total >= 2 ? total - 1 : total,
      twoLeggedRounds: twoLeggedSemiFinal && total >= 2 ? [total - 1] : null,
    );
    _buildPlannedRound(cup, 1, const [], rng);
    if (focusTeamId != null) putTeamFirst(cup, focusTeamId);
    return cup;
  }

  /// 部ごとの入る回戦の既定(3部 → 1回戦、2部 → 2回戦、1部 → 3回戦)。
  static const Map<int, int> defaultEntryRound = {3: 1, 2: 2, 1: 3};

  /// 回戦ごとの新しく入るクラブの数から、決勝までの回戦の数を求める。
  static int plannedRoundsFor(Map<int, int> entrantsPerRound) {
    if (entrantsPerRound.isEmpty) return 0;
    final lastEntry = entrantsPerRound.keys.reduce(max);
    var carry = 0;
    for (var r = 1; r < 64; r++) {
      final p = carry + (entrantsPerRound[r] ?? 0);
      final future = r < lastEntry;
      if (!future && p <= 2) return p == 2 ? r : r - 1;
      final (m, byes) = _matchesFor(p, future);
      carry = m + byes;
    }
    return 0;
  }

  /// [p]クラブの回戦の試合数と不戦勝の数。後の回戦から入るクラブが
  /// まだいるなら、できるだけ全員が戦う(奇数なら1つ不戦勝)。もう入る
  /// クラブがいなければ、次の回戦が2の累乗になるように数を合わせる。
  static (int, int) _matchesFor(int p, bool future) {
    if (p < 2) return (0, p);
    final pow2 = (p & (p - 1)) == 0;
    if (future || pow2) {
      final m = p ~/ 2;
      return (m, p - 2 * m);
    }
    var big = 1;
    while (big * 2 < p) {
      big *= 2;
    }
    final m = p - big;
    return (m, p - 2 * m);
  }

  /// 回戦[round]を組む。[winners]は前の回戦の勝者。
  static void _buildPlannedRound(
      Cup cup, int round, List<String> winners, Random rng) {
    final pool = [...winners, ...?cup.entrants[round]];
    final future =
        cup.entrants.entries.any((e) => e.key > round && e.value.isNotEmpty);
    final (m, byeCount) = _matchesFor(pool.length, future);
    if (m == 0) return;
    int tierOf(String id) => cup.tiers[id] ?? 99;
    // 不戦勝は上の部のクラブから(同じ部の中はくじ)。
    final order = [...pool]..shuffle(rng);
    order.sort((a, b) => tierOf(a).compareTo(tierOf(b)));
    final byes = order.take(byeCount).toList();
    if (byes.isNotEmpty) {
      (cup.entrants[round + 1] ??= []).addAll(byes);
    }
    final playing = order.skip(byeCount).toList()..shuffle(rng);
    final matches = <CupMatch>[];
    for (var i = 0; i + 1 < playing.length; i += 2) {
      var home = playing[i];
      var away = playing[i + 1];
      // 部の違うクラブが当たると、下の部のクラブのホームで戦う。
      if (tierOf(away) > tierOf(home) && tierOf(away) != 99) {
        final t = home;
        home = away;
        away = t;
      }
      matches.add(CupMatch(
        round: round,
        homeTeamId: home,
        awayTeamId: away,
        twoLegged: cup.twoLeggedRounds.contains(round),
      ));
    }
    cup.rounds.add(matches);
  }

  /// いまの回戦で[teamId]の試合を先頭にする(自クラブの試合を「次の試合」
  /// にするため。回戦の残りは自クラブの試合のあとにまとめて決まる)。
  static void putTeamFirst(Cup cup, String teamId) {
    if (cup.rounds.isEmpty) return;
    final round = cup.rounds.last;
    final i = round
        .indexWhere((m) => m.homeTeamId == teamId || m.awayTeamId == teamId);
    if (i > 0) round.insert(0, round.removeAt(i));
  }

  /// 延長戦(30分)。引き分けの[result]に延長の得点を足したものを返す。
  /// 強さの差から得点を見積もる(90分の3分の1ほどの量)。得点者は
  /// 先発のフィールドプレーヤーからくじで選ぶ(選手のいないクラブは名前なし)。
  /// アシストも、90分の試合と同じ割合(約8割)でほかの選手からくじで選ぶ。
  /// 延長の得点は返した結果の events に新しく足したもので、選手の通算得点
  /// には呼び出し側で数える([extraTimeGoals])。
  static MatchResult extraTime(MatchResult result, Team home, Team away,
      {Random? random}) {
    final rng = random ?? _rng;
    final diff = (home.overallRating - away.overallRating).toDouble();
    final hl = (1.35 + diff / 90 + 0.1).clamp(0.3, 3.6) / 3;
    final al = (1.2 - diff / 90).clamp(0.2, 3.3) / 3;
    final hg = _poisson(hl, rng);
    final ag = _poisson(al, rng);
    final events = [...result.events];
    void addGoals(Team t, int n) {
      final shooters = MatchEngine.lineupOf(t)
          .where((p) => p.position.group != PositionGroup.gk)
          .toList();
      for (var i = 0; i < n; i++) {
        final p =
            shooters.isEmpty ? null : shooters[rng.nextInt(shooters.length)];
        final others = [
          for (final q in MatchEngine.lineupOf(t))
            if (q.id != p?.id) q,
        ];
        final a = others.isEmpty || rng.nextDouble() < 0.22
            ? null
            : others[rng.nextInt(others.length)];
        events.add(MatchEvent(
          minute: 91 + rng.nextInt(30),
          teamId: t.id,
          scorerName: p?.name,
          scorerId: p?.id,
          assistName: a?.name,
          assistId: a?.id,
        ));
      }
    }

    addGoals(home, hg);
    addGoals(away, ag);
    events.sort((a, b) => a.minute.compareTo(b.minute));
    return MatchResult(
      matchday: result.matchday,
      homeTeamId: result.homeTeamId,
      awayTeamId: result.awayTeamId,
      homeGoals: result.homeGoals + hg,
      awayGoals: result.awayGoals + ag,
      events: events,
      playerRatings: result.playerRatings,
      weather: result.weather,
      homePossession: result.homePossession,
      awayPossession: result.awayPossession,
      homeShots: result.homeShots,
      awayShots: result.awayShots,
      homeShotsOnTarget: result.homeShotsOnTarget,
      awayShotsOnTarget: result.awayShotsOnTarget,
    );
  }

  /// [extraTime]が[before]に足した延長の得点([after]にだけある得点)。
  static List<MatchEvent> extraTimeGoals(
      MatchResult before, MatchResult after) {
    final old = Set<MatchEvent>.identity()..addAll(before.events);
    return [
      for (final e in after.events)
        if (e.type == MatchEventType.goal && !old.contains(e)) e,
    ];
  }

  /// 延長の得点を、得点した選手の通算得点に足す([teams]の選手から引く)。
  /// 90分までの得点は試合後の共通処理(MatchEngine.applyPostMatchEffects)
  /// で数えるが、延長の得点はその後に足されるので、ここで足す。
  static void creditExtraTimeGoals(
      MatchResult before, MatchResult after, List<Team> teams) {
    for (final e in extraTimeGoals(before, after)) {
      final id = e.scorerId;
      if (id == null) continue;
      for (final t in teams) {
        final p = t.players.where((x) => x.id == id).firstOrNull;
        if (p != null) {
          p.careerGoals += 1;
          break;
        }
      }
    }
  }

  static int _poisson(double lambda, Random rng) {
    final l = exp(-lambda);
    var k = 0;
    var p = 1.0;
    do {
      k++;
      p *= rng.nextDouble();
    } while (p > l);
    return k - 1;
  }

  /// 自クラブの出ない試合を、裏の試合(他の部の試合と同じ軽い計算)で
  /// 決める。延長・PK戦まで決着させ、回戦が終われば次を組む。2試合制の
  /// 組は、次の1試合(第1戦か第2戦)だけを行う。中立の会場ではホームの利が
  /// 無い。
  static void playInBackground(Cup cup, List<Team> allTeams, CupMatch match) {
    if (match.result != null || match.isBye) return;
    final home = allTeams.where((t) => t.id == match.nextHomeId).firstOrNull;
    final away = allTeams.where((t) => t.id == match.nextAwayId).firstOrNull;
    if (home == null || away == null) {
      // 相手のいない試合(壊れたセーブ)は、いる側の勝ちにする。
      match.result = MatchResult(
        matchday: 0,
        homeTeamId: match.homeTeamId,
        awayTeamId: match.awayTeamId,
        homeGoals: home == null ? 0 : 3,
        awayGoals: home == null ? 3 : 0,
        events: [],
      );
      _advanceRoundIfComplete(cup);
      return;
    }
    final r = BackgroundMatchEngine.simulate(
        home: home, away: away, matchday: 0, neutral: cup.isNeutral(match));
    applyMatchResult(cup, allTeams, match, r);
  }

  /// [match]の次の試合のホームの利の係数(中立の会場なら利なし)。
  /// [home]は中立でないときの係数(既定はCPUの既定値)。
  static double homeAdvantageFor(Cup cup, CupMatch match,
          {double home = MatchEngine.defaultHomeAdvantageFactor}) =>
      cup.isNeutral(match) ? MatchEngine.neutralHomeAdvantageFactor : home;

  /// チームIDのリストからノックアウト方式のカップを作成する。
  /// 参加数が2の累乗でない場合は不戦勝(BYE)で埋める。BYE同士が対戦して
  /// 永久に決着しない事態を避けるため、各BYEは必ず実チーム1つと組ませる
  /// (2の累乗への切り上げである以上、BYE数は必ず組数の半分未満に収まる)。
  static Cup createKnockout({
    required CupType type,
    required String name,
    required List<String> teamIds,
  }) {
    if (teamIds.length < 2) {
      throw ArgumentError.value(
          teamIds,
          'teamIds',
          Tr.pick('ノックアウト方式のカップには最低2チーム必要です',
              'A knockout cup needs at least two teams'));
    }
    final shuffled = [...teamIds]..shuffle(_rng);
    int size = 1;
    while (size < shuffled.length) {
      size *= 2;
    }
    final byeCount = size - shuffled.length;

    final firstRound = <CupMatch>[];
    var idx = 0;
    for (int i = 0; i < byeCount; i++) {
      final match = CupMatch(
        round: 1,
        homeTeamId: shuffled[idx],
        awayTeamId: byeTeamId,
      );
      match.result = MatchResult(
        matchday: 0,
        homeTeamId: match.homeTeamId,
        awayTeamId: byeTeamId,
        homeGoals: 1,
        awayGoals: 0,
        events: [],
      );
      firstRound.add(match);
      idx++;
    }
    while (idx < shuffled.length) {
      firstRound.add(
        CupMatch(
          round: 1,
          homeTeamId: shuffled[idx],
          awayTeamId: shuffled[idx + 1],
        ),
      );
      idx += 2;
    }

    final cup = Cup(type: type, name: name, rounds: [firstRound]);
    _advanceRoundIfComplete(cup);
    return cup;
  }

  /// PK戦を1本ずつシミュレートし、キック順の記録つきで勝者を決める。
  /// ライブ観戦のフルタイム画面で「1本ごとの成否」を演出表示するために使う。
  /// CPU同士のクイック消化は従来通り[decidePenaltyWinner](重み付き抽選1回)で
  /// 軽量に決めるため両者の結果分布は厳密には一致しないが、どちらも
  /// チーム力・キッカーのPK/冷静さ・相手GKの一対一を反映する。
  static PenaltyShootoutResult simulateShootout(Team home, Team away) {
    List<Player> kickersOf(Team t) {
      double kickSkill(Player p) =>
          p.attributeValue(AttributeKeys.penalties) * 0.7 +
          p.attributeValue(AttributeKeys.composure) * 0.3;
      return MatchEngine.lineupOf(t)
          .where((p) => p.position.group != PositionGroup.gk)
          .toList()
        ..sort((a, b) => kickSkill(b).compareTo(kickSkill(a)));
    }

    double gkSkillOf(Team t) {
      final gks = MatchEngine.lineupOf(t)
          .where((p) => p.position.group == PositionGroup.gk)
          .toList();
      if (gks.isEmpty) return 50;
      return gks
              .map((p) => p.attributeValue(AttributeKeys.oneOnOnes))
              .reduce((a, b) => a + b) /
          gks.length;
    }

    final homeKickers = kickersOf(home);
    final awayKickers = kickersOf(away);
    final homeGk = gkSkillOf(home);
    final awayGk = gkSkillOf(away);

    bool kick(List<Player> kickers, int index, double defendingGk) {
      if (kickers.isEmpty) return _rng.nextDouble() < 0.5;
      final k = kickers[index % kickers.length];
      final skill = k.attributeValue(AttributeKeys.penalties) * 0.7 +
          k.attributeValue(AttributeKeys.composure) * 0.3;
      final prob = (0.75 + (skill - 50) / 200 - (defendingGk - 50) / 250)
          .clamp(0.35, 0.95);
      return _rng.nextDouble() < prob;
    }

    String kickerName(List<Player> kickers, int index) =>
        kickers.isEmpty ? '---' : kickers[index % kickers.length].name;

    final kicks = <PenaltyKick>[];
    var homeScore = 0;
    var awayScore = 0;
    var round = 0; // 完了した「両チーム1本ずつ」の往復数
    while (true) {
      final homeScored = kick(homeKickers, round, awayGk);
      if (homeScored) homeScore++;
      kicks.add(PenaltyKick(
        teamId: home.id,
        kickerName: kickerName(homeKickers, round),
        scored: homeScored,
      ));
      if (round < 5) {
        // ホームの残り本数は(4 - round)、アウェイはこの往復をまだ蹴って
        // いないので(5 - round)。届かなくなった時点で即終了する。
        if (homeScore > awayScore + (5 - round) ||
            awayScore > homeScore + (4 - round)) {
          break;
        }
      }

      final awayScored = kick(awayKickers, round, homeGk);
      if (awayScored) awayScore++;
      kicks.add(PenaltyKick(
        teamId: away.id,
        kickerName: kickerName(awayKickers, round),
        scored: awayScored,
      ));
      round++;
      if (round <= 4) {
        final rem = 5 - round;
        if (homeScore > awayScore + rem || awayScore > homeScore + rem) {
          break;
        }
      } else if (homeScore != awayScore) {
        // 5本ずつ終了後はサドンデス: 往復ごとに差がつけば終了。
        break;
      }
      // 異常系の安全弁: 30往復しても決まらなければ重み付き抽選で決める。
      if (round >= 30) {
        if (decidePenaltyWinner(home, away) == home.id) {
          homeScore++;
        } else {
          awayScore++;
        }
        break;
      }
    }
    return PenaltyShootoutResult(
      homeId: home.id,
      awayId: away.id,
      kicks: kicks,
      homeScore: homeScore,
      awayScore: awayScore,
      winnerId: homeScore > awayScore ? home.id : away.id,
    );
  }

  /// 引き分け時のPK戦勝者を、チーム総合力に加えてキッカーのPK精度・冷静さと
  /// 相手GKの一対一対応力を反映した重み付き抽選で決める。
  static String decidePenaltyWinner(Team home, Team away) {
    final homeStrength = _shootoutStrength(home, away);
    final awayStrength = _shootoutStrength(away, home);
    final totalMilli = ((homeStrength + awayStrength) * 1000).round();
    if (totalMilli <= 0) return _rng.nextBool() ? home.id : away.id;
    return _rng.nextInt(totalMilli) < (homeStrength * 1000).round()
        ? home.id
        : away.id;
  }

  /// PK戦における[attacking]チームの強さ。チーム総合力を基準に、
  /// キッカー役(フィールドプレーヤー)のPK精度・冷静さと、相手GKの
  /// 一対一対応力による減点を加味する。
  static double _shootoutStrength(Team attacking, Team defending) {
    final outfield = MatchEngine.lineupOf(attacking)
        .where((p) => p.position.group != PositionGroup.gk)
        .toList();
    final kickerSkill = outfield.isEmpty
        ? 50.0
        : outfield.fold<double>(
              0,
              (s, p) =>
                  s +
                  p.attributeValue(AttributeKeys.penalties) * 0.7 +
                  p.attributeValue(AttributeKeys.composure) * 0.3,
            ) /
            outfield.length;

    final defendingGk = MatchEngine.lineupOf(defending)
        .where((p) => p.position.group == PositionGroup.gk)
        .toList();
    final gkSkill = defendingGk.isEmpty
        ? 50.0
        : defendingGk
                .map((p) => p.attributeValue(AttributeKeys.oneOnOnes))
                .reduce((a, b) => a + b) /
            defendingGk.length;

    final strength = attacking.overallRating +
        (kickerSkill - 50) * 0.6 -
        (gkSkill - 50) * 0.4;
    return strength.clamp(1, 200);
  }

  /// カップの次の未消化試合を1試合消化する。試合結果を返す(BYE戦は既に消化済みなのでnullを返す)。
  /// [month]は試合の日の月(1〜12)。天候をその季節のものにする(渡さないと
  /// 1年をならした割合になり、12月に猛暑が出ることがある)。
  /// 2試合制の組は次の1試合(第1戦か第2戦)だけを行い、第1戦ならその
  /// 結果を返す。中立の会場ではホームの利が無い。
  static MatchResult? playNextMatch(
    Cup cup,
    List<Team> allTeams, {
    int matchday = 0,
    int? month,
  }) {
    final match = cup.nextUnplayedMatch;
    if (match == null || match.isBye) return null;

    final firstLeg = match.awaitingFirstLeg;
    final home = allTeams.firstWhere((t) => t.id == match.nextHomeId);
    final away = allTeams.firstWhere((t) => t.id == match.nextAwayId);
    final result = MatchEngine.simulate(
      home: home,
      away: away,
      matchday: matchday,
      weather: WeatherEngine.roll(month: month),
      homeAdvantageFactor: homeAdvantageFor(cup, match),
    );
    applyMatchResult(cup, allTeams, match, result);
    // 延長戦の得点を含めた結果を返す。
    return firstLeg ? match.firstLeg : match.result;
  }

  /// 外部(ライブ観戦)で確定した[result]を[match]に適用し、引き分けなら
  /// PK戦で勝者を決め、ラウンドが完了していれば次ラウンドを組む。
  /// 自クラブのカップ戦をライブ観戦で戦った場合に、シミュレートの代わりに
  /// この適用だけを行うための分離されたAPI。
  static void applyMatchResult(
    Cup cup,
    List<Team> allTeams,
    CupMatch match,
    MatchResult result,
  ) {
    // 2試合制の第1戦: 結果を控えるだけ(延長・PK戦は第2戦の後)。
    if (match.awaitingFirstLeg) {
      match.firstLeg = result;
      return;
    }
    match.result = result;
    if (match.levelAfter(result)) {
      final home = allTeams.firstWhere((t) => t.id == match.homeTeamId);
      final away = allTeams.firstWhere((t) => t.id == match.awayTeamId);
      // 90分で引き分けなら延長戦(30分)。ライブ観戦側で延長やPK戦を済ませて
      // いれば([CupMatch.extraTime]・決まっている penaltyWinnerId)、
      // もう一度は行わない。スーパーカップは延長なしでPK戦(実在の形)。
      if (!match.extraTime &&
          match.penaltyWinnerId == null &&
          cup.type != CupType.superCup) {
        match.result = extraTime(result, home, away);
        match.extraTime = true;
        // 延長の得点は試合後の共通処理(MatchEngine.simulate の中)の後に
        // 足されるので、ここで選手の通算得点に数える。
        creditExtraTimeGoals(result, match.result!, [home, away]);
      }
      final r = match.result!;
      if (match.levelAfter(r)) {
        // ライブ観戦側で1本ずつのPK戦を先に実施済みの場合はその勝者を尊重する。
        match.penaltyWinnerId ??= decidePenaltyWinner(home, away);
      }
    }
    _advanceRoundIfComplete(cup);
  }

  static bool _advanceRoundIfComplete(Cup cup) {
    if (cup.plannedRounds != null) {
      var advanced = false;
      while (cup.rounds.isNotEmpty &&
          cup.rounds.length < cup.plannedRounds! &&
          cup.rounds.last.every((m) => m.winnerId != null)) {
        final before = cup.rounds.length;
        final winners = cup.rounds.last.map((m) => m.winnerId!).toList();
        _buildPlannedRound(cup, before + 1, winners, _rng);
        if (cup.rounds.length == before) break;
        advanced = true;
      }
      return advanced;
    }
    bool advancedAny = false;
    while (true) {
      final lastRound = cup.rounds.last;
      if (lastRound.any((m) => m.winnerId == null)) break;
      if (lastRound.length == 1) break;
      final winners = lastRound.map((m) => m.winnerId!).toList();
      final nextRoundNum = lastRound.first.round + 1;
      final nextMatches = <CupMatch>[];
      for (int i = 0; i < winners.length; i += 2) {
        final match = CupMatch(
          round: nextRoundNum,
          homeTeamId: winners[i],
          awayTeamId: winners[i + 1],
        );
        if (match.isBye) {
          match.result = MatchResult(
            matchday: 0,
            homeTeamId: match.homeTeamId,
            awayTeamId: match.awayTeamId,
            homeGoals: match.awayTeamId == byeTeamId ? 1 : 0,
            awayGoals: match.homeTeamId == byeTeamId ? 1 : 0,
            events: [],
          );
        }
        nextMatches.add(match);
      }
      cup.rounds.add(nextMatches);
      advancedAny = true;
    }
    return advancedAny;
  }

  /// ラウンド数に応じたラウンド名(準々決勝・準決勝・決勝など)。
  static String roundLabel(int round, int totalRounds) {
    final fromFinal = totalRounds - round;
    return switch (fromFinal) {
      0 => Tr.pick('決勝', 'Final'),
      1 => Tr.pick('準決勝', 'Semi-final'),
      2 => Tr.pick('準々決勝', 'Quarter-final'),
      _ => Tr.pick('第$round回戦', 'Round $round'),
    };
  }
}

/// PK戦の1本ぶんの記録(演出表示用)。
class PenaltyKick {
  final String teamId;
  final String kickerName;
  final bool scored;

  const PenaltyKick({
    required this.teamId,
    required this.kickerName,
    required this.scored,
  });
}

/// PK戦全体の記録。[CupEngine.simulateShootout]が返す。セーブには保存せず、
/// フルタイム画面の演出にのみ使う一時データ。
class PenaltyShootoutResult {
  final String homeId;
  final String awayId;
  final List<PenaltyKick> kicks;
  final int homeScore;
  final int awayScore;
  final String winnerId;

  const PenaltyShootoutResult({
    required this.homeId,
    required this.awayId,
    required this.kicks,
    required this.homeScore,
    required this.awayScore,
    required this.winnerId,
  });
}
