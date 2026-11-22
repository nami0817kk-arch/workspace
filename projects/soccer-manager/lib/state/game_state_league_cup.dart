part of 'game_state.dart';

/// 2つ目の国内カップ(リーグカップ)。同じ部のクラブだけで戦う短い大会。
///
/// 国内カップ(ライブで観られる)と違い、リーグカップは4節ごとに1回戦ずつ
/// まとめて消化する(オーナーは結果を受け取るだけ)。賞金は国内カップの半分。
extension GameStateLeagueCup on GameState {
  /// 何節ごとに1回戦を消化するか。
  static const int leagueCupInterval = 4;

  /// リーグカップ(無ければ null)。
  Cup? get leagueCup => _save == null ? null : _cupOfType(CupType.leagueCup);

  /// リーグカップの名前。
  String get leagueCupName => Tr.pick('リーグカップ', 'League Cup');

  /// 新しい季(と新しく始めたとき・クラブを替えたとき)のリーグカップを作る。
  Cup _newLeagueCup(List<String> teamIds) => CupEngine.createKnockout(
        type: CupType.leagueCup,
        name: leagueCupName,
        teamIds: teamIds,
      );

  /// 4節ごとに、リーグカップの1回戦をまとめて消化する。
  void _playLeagueCupIfDue() {
    final s = _save;
    final cup = leagueCup;
    if (s == null || cup == null || cup.isComplete) return;
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
      final prize =
          scaledMoney(GameState.domesticCupWinPrizeFor(m.round) ~/ 2);
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
