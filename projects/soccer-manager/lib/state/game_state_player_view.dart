part of 'game_state.dart';

/// 選手の画面(スカッドの表・選手の詳しい画面・比較)に出す数字と、
/// 自クラブの外の選手の探し方(2026-11-25。FM に寄せた第3段)。
extension GameStatePlayerView on GameState {
  /// [ids]の選手の今季のリーグ戦の成績。試合の結果を1回なめて全員分を
  /// 集める(1人ずつ [seasonStatsFor] を呼ぶと、表の行の数だけ全試合を
  /// なめていた)。
  Map<String, PlayerSeasonStats> seasonStatsForAll(Iterable<String> ids) {
    final want = ids.toSet();
    final apps = <String, int>{};
    final goals = <String, int>{};
    final yellows = <String, int>{};
    final reds = <String, int>{};
    final ratingSum = <String, double>{};
    if (_save != null) {
      for (final f in _save!.league.fixtures) {
        final r = f.result;
        if (r == null) continue;
        for (final e in r.playerRatings.entries) {
          if (!want.contains(e.key)) continue;
          apps[e.key] = (apps[e.key] ?? 0) + 1;
          ratingSum[e.key] = (ratingSum[e.key] ?? 0) + e.value;
        }
        for (final e in r.events) {
          final id = e.scorerId;
          if (id == null || !want.contains(id)) continue;
          switch (e.type) {
            case MatchEventType.goal:
              goals[id] = (goals[id] ?? 0) + 1;
            case MatchEventType.yellowCard:
              yellows[id] = (yellows[id] ?? 0) + 1;
            case MatchEventType.redCard:
              reds[id] = (reds[id] ?? 0) + 1;
            case MatchEventType.chance:
            case MatchEventType.substitution:
              break;
          }
        }
      }
    }
    return {
      for (final id in want)
        id: PlayerSeasonStats(
          appearances: apps[id] ?? 0,
          goals: goals[id] ?? 0,
          yellowCards: yellows[id] ?? 0,
          redCards: reds[id] ?? 0,
          averageRating: (apps[id] ?? 0) == 0
              ? null
              : ratingSum[id]! / apps[id]!,
        ),
    };
  }

  /// 調子: 直近[last]試合(リーグ戦)の採点の平均。出ていなければ null。
  Map<String, double?> recentFormForAll(Iterable<String> ids,
      {int last = 5}) {
    final want = ids.toSet();
    final ratings = <String, List<double>>{};
    if (_save != null) {
      final played = [
        for (final f in _save!.league.fixtures)
          if (f.result != null) f
      ]..sort((a, b) => b.matchday.compareTo(a.matchday));
      for (final f in played) {
        for (final e in f.result!.playerRatings.entries) {
          if (!want.contains(e.key)) continue;
          final list = ratings.putIfAbsent(e.key, () => []);
          if (list.length < last) list.add(e.value);
        }
      }
    }
    return {
      for (final id in want)
        id: (ratings[id] == null || ratings[id]!.isEmpty)
            ? null
            : ratings[id]!.reduce((a, b) => a + b) / ratings[id]!.length,
    };
  }

  /// 自クラブ・ほかのクラブ(他国の1部も)・移籍市場・所属なし・ユースの
  /// どこにいても選手を探す。もういなければ null。
  ///
  /// 選手の詳しい画面は他クラブの選手でも開ける(2026-11-25。移籍の一覧から
  /// 他クラブの選手を開けなかった)。
  Player? anyPlayerById(String id) {
    if (_save == null) return null;
    final p = playerById(id) ?? talkPlayer(id);
    if (p != null) return p;
    for (final t in _worldTeams) {
      for (final q in t.players) {
        if (q.id == id) return q;
      }
    }
    return null;
  }

  /// 選手のいるクラブ(自クラブを含む)。所属なし・市場の選手は null。
  Team? clubOfPlayer(String id) {
    if (_save == null) return null;
    if (userTeam.players.any((p) => p.id == id)) return userTeam;
    for (final t in _worldTeams) {
      if (t.players.any((p) => p.id == id)) return t;
    }
    return null;
  }

  /// 自クラブの選手か。
  bool isMyPlayer(String id) =>
      _save != null && userTeam.players.any((p) => p.id == id);

  /// 移籍の歴に1行足す(選手の詳しい画面の「経歴」に出す)。
  void _logMove(Player p,
      {required String from,
      required String to,
      required PlayerMoveKind kind,
      int fee = 0}) {
    if (_save == null) return;
    p.moveLog.add(PlayerMoveLine(
        date: today, from: from, to: to, kind: kind, fee: fee));
    // 長く遊んでも大きくならないよう、古いものから捨てる。
    if (p.moveLog.length > 20) p.moveLog.removeAt(0);
  }

  /// 季の終わりに、自分のリーグの全クラブの選手の経歴に今季の1行を足す
  /// (2026-11-25 から。成績は今季のリーグ戦の結果から作る)。
  void _recordCareerLines() {
    final save = _save;
    if (save == null) return;
    final year = Player.contractClockYear;
    final teams = save.league.teams;
    final stats = seasonStatsForAll([
      for (final t in teams)
        for (final p in t.players) p.id
    ]);
    for (final t in teams) {
      for (final p in t.players) {
        if (p.careerLog.any((l) => l.seasonEndYear == year && l.club == t.name)) {
          continue;
        }
        final st = stats[p.id] ?? const PlayerSeasonStats();
        p.careerLog.add(PlayerCareerLine(
          seasonEndYear: year,
          club: t.name,
          apps: st.appearances,
          goals: st.goals,
          rating: st.averageRating,
          loan: p.isLoan,
        ));
        if (p.careerLog.length > 25) p.careerLog.removeAt(0);
      }
    }
    // 自クラブから貸し出している選手は、貸し出し先の名前で1行(成績は別の
    // リーグなので分からない)。
    for (final p in userTeam.players) {
      final away = p.loanedOutToClubName;
      if (!p.isLoanedOut || away == null) continue;
      if (p.careerLog.any((l) => l.seasonEndYear == year && l.club == away)) {
        continue;
      }
      p.careerLog.add(
          PlayerCareerLine(seasonEndYear: year, club: away, loan: true));
    }
  }

  @visibleForTesting
  void debugRecordCareerLines() => _recordCareerLines();

  /// 伸びしろの段(0〜3)。自クラブの選手は本当の値から、ユースの子は
  /// ユースコーチの見立て(推定幅の真ん中)から。ほかのクラブの選手は
  /// 見えない(null。スカウトの見立てが要る)。
  int? growthRoomLevelFor(Player p) {
    if (_save == null) return null;
    if (isMyPlayer(p.id)) {
      return RatingWords.growthRoomLevel(p.overall, p.potential);
    }
    final youth = _save!.pendingYouthIntake.any((q) => q.id == p.id) ||
        _save!.youthProspects.any((q) => q.id == p.id);
    if (!youth) return null;
    final r = ScoutingEngine.estimatedPotentialRange(p,
        scoutLevel: youthCoachJudgingLevel);
    return RatingWords.growthRoomLevel(p.overall, ((r.$1 + r.$2) / 2).round());
  }

  /// 伸びしろの言葉([growthRoomLevelFor])。見えなければ「分からない」。
  String growthRoomWordFor(Player p) => switch (growthRoomLevelFor(p)) {
        null => Tr.pick('分からない(見立てが要る)', 'Unknown (needs scouting)'),
        0 => Tr.pick('ほぼ上限', 'Almost none'),
        1 => Tr.pick('少しある', 'A little'),
        2 => Tr.pick('まだ伸びる', 'Still improving'),
        _ => Tr.pick('大きい', 'Plenty'),
      };

  /// 似た選手(FM の「似た選手」)。同じ大分類のポジションで、年齢が
  /// ±3歳、総合力の近いほかのクラブ(自国の全部の部)の選手を近い順に。
  List<({Player player, Team club})> similarPlayers(Player p,
      {int count = 4}) {
    if (_save == null) return const [];
    final out = <({Player player, Team club, int gap})>[];
    for (final t in _save!.allTeams) {
      for (final q in t.players) {
        if (q.id == p.id) continue;
        if (q.position.group != p.position.group) continue;
        if ((q.age - p.age).abs() > 3) continue;
        // 伸びしろ(潜在能力)は他クラブの選手では見えないので、総合力と
        // 年齢だけで近さを測る。
        out.add((
          player: q,
          club: t,
          gap: (q.overall - p.overall).abs() * 3 + (q.age - p.age).abs()
        ));
      }
    }
    out.sort((a, b) => a.gap.compareTo(b.gap));
    return [for (final x in out.take(count)) (player: x.player, club: x.club)];
  }
}
