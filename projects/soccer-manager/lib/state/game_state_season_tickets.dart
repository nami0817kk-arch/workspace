part of 'game_state.dart';

/// 年間シート。開幕前に1回だけ、入場券の一部を割り引いてまとめて売る。
extension GameStateSeasonTickets on GameState {
  /// 今季に売った割合(%)。売っていなければ 0。
  int get seasonTicketShareNow {
    final s = _save;
    if (s == null || s.seasonTicketSeason != s.league.season) return 0;
    return s.seasonTicketShare;
  }

  /// 今季のリーグ戦の節の数。
  int get _leagueMatchdays {
    final f = _save!.league.fixtures;
    return f.isEmpty ? 0 : f.map((x) => x.matchday).reduce(max);
  }

  /// [sharePercent]%を年間シートにしたら、いくら入るかの見込み。
  int seasonTicketUpfront(int sharePercent) => _save == null
      ? 0
      : SeasonTicketEngine.upfront(
          weeklyGate: weeklyIncomeParts(_save!.userTeamId).gate,
          matchdays: _leagueMatchdays,
          sharePercent: sharePercent,
        );

  /// 年間シートを売れるか(開幕前で、今季まだ売っていない)。
  bool get canSellSeasonTickets =>
      _save != null &&
      canChangeClubPolicy &&
      _save!.seasonTicketSeason != _save!.league.season;

  /// 年間シートを売る。売上はすぐ入り、今季の節ごとの入場収入はその割合だけ減る。
  Future<bool> sellSeasonTickets(int sharePercent) async {
    final s = _save;
    if (s == null ||
        !canSellSeasonTickets ||
        sharePercent <= 0 ||
        !SeasonTicketEngine.shares.contains(sharePercent)) {
      return false;
    }
    final money = seasonTicketUpfront(sharePercent);
    s.seasonTicketShare = sharePercent;
    s.seasonTicketSeason = s.league.season;
    _book(LedgerCategory.gate, money);
    _logNews(
        Tr.pick(
            '入場券の$sharePercent%を年間シートとして売り、${formatMoney(money)}が入った。今季の試合の入場収入は、その分だけ減る。',
            'Sold $sharePercent% of tickets as season tickets for ${formatMoney(money)}. Matchday gate money this season drops by that share.'),
        context: Tr.pick('年間シート', 'Season tickets'));
    _notify();
    await _persist();
    return true;
  }
}
