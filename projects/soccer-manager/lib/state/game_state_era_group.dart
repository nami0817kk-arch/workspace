part of 'game_state.dart';

/// 時代の変化と、複数のクラブを持つこと。
extension GameStateEraGroup on GameState {
  /// 今の時代。
  Era get currentEra => EraEngine.eraOf(_save?.league.season ?? 1);

  /// 季の切り替え: 時代が変わったら知らせる。
  void _announceEra(int newSeason) {
    final before = EraEngine.eraOf(newSeason - 1);
    final after = EraEngine.eraOf(newSeason);
    if (before == after) return;
    _logNews(
        Tr.pick('時代が変わった: 「${after.label}」。${after.summary}',
            'A new era: "${after.label}". ${after.summary}'),
        context: Tr.pick('時代', 'Era'));
  }

  /// 選手の価値の合計。
  int _squadValue(Team t) => t.players.fold<int>(0, (s, p) => s + p.marketValue);

  /// 買えるほかのクラブ(他国の1部。まだ持っていないもの)。
  List<(Team, int)> get groupClubCandidates {
    final s = _save;
    if (s == null) return const [];
    final list = [
      for (final l in s.foreignLeagues.values)
        for (final t in l.teams)
          if (!s.groupClubs.containsKey(t.id))
            (t, GroupClubEngine.price(_squadValue(t))),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    return list.take(6).toList();
  }

  /// 持っているほかのクラブ(クラブ・買った値段・今売れる値段)。
  List<(Team, int, int)> get groupClubsOwned {
    final s = _save;
    if (s == null) return const [];
    return [
      for (final e in s.groupClubs.entries)
        if (_worldTeamById(e.key) case final t?)
          (t, e.value, GroupClubEngine.salePrice(_squadValue(t))),
    ];
  }

  bool isGroupClub(String teamId) =>
      _save?.groupClubs.containsKey(teamId) ?? false;

  /// オーナーの私財で、ほかのクラブを買う。
  Future<bool> buyGroupClub(String teamId) async {
    final s = _save;
    if (s == null || s.groupClubs.containsKey(teamId)) return false;
    final c = groupClubCandidates.where((x) => x.$1.id == teamId).firstOrNull;
    if (c == null || ownerWealth < c.$2) return false;
    s.ownerWealth -= c.$2;
    s.groupClubs[teamId] = c.$2;
    _logNews(
        Tr.pick('オーナーが私財で${c.$1.name}を買った(${formatMoney(c.$2)})。',
            'You bought ${c.$1.name} with your own money (${formatMoney(c.$2)}).'),
        context: Tr.pick('グループ', 'Group'));
    _notify();
    await _persist();
    return true;
  }

  /// 持っているクラブを売る(私財に戻る)。
  Future<bool> sellGroupClub(String teamId) async {
    final s = _save;
    if (s == null || !s.groupClubs.containsKey(teamId)) return false;
    final t = _worldTeamById(teamId);
    final price = t == null ? 0 : GroupClubEngine.salePrice(_squadValue(t));
    s.groupClubs.remove(teamId);
    s.ownerWealth = ownerWealth + price;
    _notify();
    await _persist();
    return true;
  }

  /// 季の締め: 持っているクラブの順位で、私財に損益が入る。
  void _settleGroupClubs() {
    final s = _save!;
    for (final e in s.groupClubs.entries) {
      League? league;
      for (final l in s.foreignLeagues.values) {
        if (l.teams.any((t) => t.id == e.key)) league = l;
      }
      if (league == null) continue;
      final order = league.sortedStandings;
      final idx = order.indexWhere((r) => r.teamId == e.key);
      final n = max(1, order.length - 1);
      final rankFactor = idx < 0 ? 0.5 : 1 - idx / n;
      final profit = GroupClubEngine.seasonProfit(e.value, rankFactor);
      s.ownerWealth = max(0, ownerWealth + profit);
      final name = _worldTeamById(e.key)?.name ?? '-';
      _logNews(
          Tr.pick(
              '持っている$nameは${idx + 1}位。私財に${profit >= 0 ? '+' : ''}${formatMoney(profit)}。',
              'Your club $name finished ${idx + 1}th: ${profit >= 0 ? '+' : ''}${formatMoney(profit)} to your wealth.'),
          context: Tr.pick('グループ', 'Group'));
    }
  }

  @visibleForTesting
  void debugSettleGroupClubs() => _settleGroupClubs();
}
