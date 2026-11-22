part of 'game_state.dart';

/// 2つ目の国内カップ(リーグカップ)。実在ではイングランドだけにあるので、
/// イングランドだけに置く(1〜3部のクラブが出る。2026-11-22。それまでは
/// どの国にもあり、同じ部のクラブだけで戦っていた)。
///
/// 国内カップ(ライブで観られる)と違い、リーグカップは回戦ごとに決まった
/// 節でまとめて消化する(オーナーは結果を受け取るだけ)。決勝は2〜3月。
/// 賞金は国内カップの半分。
extension GameStateLeagueCup on GameState {
  /// 古い形のリーグカップ(回戦の節を持たない)を何節ごとに1回戦消化するか。
  static const int leagueCupInterval = 4;

  /// リーグカップ(無ければ null。イングランド以外は無い)。
  Cup? get leagueCup => _save == null ? null : _cupOfType(CupType.leagueCup);

  /// リーグカップの名前。
  String get leagueCupName =>
      leagueCup?.name ?? currentLeagueTheme.leagueCupName;

  /// 回戦の日が来ていれば(古い形は4節ごとに)、リーグカップの1回戦を
  /// まとめて消化する。自クラブの試合は普通の試合の計算、他のクラブ同士は
  /// 裏の試合と同じ軽い計算。延長・PK戦まで決着する。
  void _playLeagueCupIfDue() {
    final s = _save;
    final cup = leagueCup;
    if (s == null || cup == null || cup.isComplete) return;
    if (cup.plannedRounds != null) {
      _playPlannedLeagueCup(cup);
      return;
    }
    final marker = _currentLeagueMatchdayMarker;
    final last = cup.lastPlayedAtMatchday;
    final offSeason = s.league.nextUnplayedFixture == null;
    if (!offSeason && last != null && marker - last < leagueCupInterval) return;
    final round = cup.nextUnplayedMatch?.round;
    if (round == null) return;
    final teams = allTeamsForCups;
    while (true) {
      final m = cup.nextUnplayedMatch;
      if (m == null || m.round != round) break;
      if (m.isBye) break;
      // 出られるクラブがいない(作り直しの途中など)なら、その日はやめる。
      if (!teams.any((t) => t.id == m.homeTeamId) ||
          !teams.any((t) => t.id == m.awayTeamId)) {
        break;
      }
      CupEngine.playNextMatch(cup, teams, month: today.month);
      _afterLeagueCupMatch(m);
    }
    cup.lastPlayedAtMatchday = marker;
  }

  /// 新しい形のリーグカップ: 日が来た回戦をまとめて消化する。
  void _playPlannedLeagueCup(Cup cup) {
    final u = _save!.userTeamId;
    for (var guard = 0; guard < 12; guard++) {
      final next = cup.nextUnplayedMatch;
      if (next == null || !_cupDue(cup.dueMatchdayFor(next.round))) break;
      final round = cup.rounds.last;
      for (final m in [...round]) {
        if (m.result != null) continue;
        final teams = allTeamsForCups;
        if (m.homeTeamId == u || m.awayTeamId == u) {
          final home = teamById(m.homeTeamId);
          final away = teamById(m.awayTeamId);
          if (home == null || away == null) continue;
          _ensureSquadsForActiveTier([home, away]);
          final r = MatchEngine.simulate(
            home: home,
            away: away,
            matchday: 0,
            weather: WeatherEngine.roll(month: today.month),
          );
          CupEngine.applyMatchResult(cup, teams, m, r);
          _applyUserCupPostMatchEffects(m.result!);
        } else {
          CupEngine.playInBackground(cup, teams, m);
        }
        if (m.homeTeamId == u || m.awayTeamId == u) _afterLeagueCupMatch(m);
      }
      CupEngine.putTeamFirst(cup, u);
      cup.lastPlayedAtMatchday = _currentLeagueMatchdayMarker;
      if (identical(cup.rounds.last, round)) break;
    }
  }

  /// リーグカップの1試合のあと: 自クラブの勝ち・優勝に賞金(国内カップの半分)。
  void _afterLeagueCupMatch(CupMatch m) {
    final s = _save!;
    final cup = leagueCup!;
    final userId = s.userTeamId;
    final mine = m.homeTeamId == userId || m.awayTeamId == userId;
    if (!mine) return;
    final opp = m.homeTeamId == userId ? m.awayTeamId : m.homeTeamId;
    final oppName =
        allTeamsForCups.where((t) => t.id == opp).firstOrNull?.name ?? '-';
    final r = m.result;
    final score = r == null
        ? ''
        : (m.homeTeamId == userId
            ? '${r.homeGoals}-${r.awayGoals}'
            : '${r.awayGoals}-${r.homeGoals}');
    if (m.winnerId == userId) {
      final prize = scaledMoney(GameState.domesticCupWinPrizeFor(m.round) ~/ 2);
      _book(LedgerCategory.prize, prize);
      _logNews(
          Tr.pick('$leagueCupName: $oppNameに$scoreで勝ち、賞金${formatMoney(prize)}。',
              '$leagueCupName: beat $oppName $score, ${formatMoney(prize)} prize money.'),
          context: leagueCupName);
    } else {
      _logNews(
          Tr.pick('$leagueCupName: $oppNameに$scoreで敗れ、敗退した。',
              '$leagueCupName: out after losing $score to $oppName.'),
          context: leagueCupName);
    }
    if (cup.isComplete && cup.championId == userId && !cup.rewardClaimed) {
      cup.rewardClaimed = true;
      final reward = scaledMoney(GameState.domesticCupChampionPrize ~/ 2);
      _book(LedgerCategory.prize, reward);
      s.trophyHistory.add(Tr.pick('シーズン${s.league.season} $leagueCupName優勝',
          'Season ${s.league.season} $leagueCupName winners'));
      _addTimeline(Tr.pick('$leagueCupNameで優勝', 'Won the $leagueCupName'));
      _logNews(
          Tr.pick('$leagueCupNameで優勝! 優勝賞金${formatMoney(reward)}。',
              '$leagueCupName winners! ${formatMoney(reward)} in prize money.'),
          context: leagueCupName);
    }
  }

  /// テスト用: リーグカップの消化を1回走らせる。
  @visibleForTesting
  void debugPlayLeagueCup() => _playLeagueCupIfDue();
}
