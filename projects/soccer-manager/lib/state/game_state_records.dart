part of 'game_state.dart';

/// 1行ぶんのクラブの記録(選手の名前と数)。
typedef ClubRecordRow = ({String id, String name, int value});

/// クラブの歴代記録(自クラブでの出場・得点の上位と、最大の勝ち試合)。
extension GameStateRecords on GameState {
  /// 自クラブの公式戦1試合ぶんを記録に足す。
  void _recordClubMatch(MatchResult r, Fixture f) {
    final s = _save!;
    final team = userTeam;
    final mine = {for (final p in team.players) p.id: p};
    final played = r.playerRatings.keys.where(mine.containsKey).toSet();
    for (final id in played) {
      s.clubApps[id] = (s.clubApps[id] ?? 0) + 1;
      s.clubRecordNames[id] = mine[id]!.name;
    }
    for (final e in r.events) {
      if (e.type != MatchEventType.goal) continue;
      final id = e.scorerId;
      if (id == null || !mine.containsKey(id)) continue;
      s.clubGoals[id] = (s.clubGoals[id] ?? 0) + 1;
      s.clubRecordNames[id] = mine[id]!.name;
    }
    final home = r.homeTeamId == team.id;
    final ours = home ? r.homeGoals : r.awayGoals;
    final theirs = home ? r.awayGoals : r.homeGoals;
    final margin = ours - theirs;
    if (margin > s.biggestWinMargin) {
      final oppId = home ? r.awayTeamId : r.homeTeamId;
      final opp =
          s.league.teams.where((t) => t.id == oppId).firstOrNull?.name ?? '-';
      s.biggestWinMargin = margin;
      s.biggestWin = Tr.pick('${s.league.season}季 $ours-$theirs $opp',
          'Season ${s.league.season}: $ours-$theirs v $opp');
    }
  }

  List<ClubRecordRow> _top(Map<String, int> m, int n) {
    final names = _save?.clubRecordNames ?? const {};
    final rows = [
      for (final e in m.entries)
        (id: e.key, name: names[e.key] ?? '-', value: e.value),
    ]..sort((a, b) => b.value.compareTo(a.value));
    return rows.take(n).toList();
  }

  /// 自クラブでの出場の歴代上位。
  List<ClubRecordRow> clubAppsLeaders({int n = 5}) =>
      _save == null ? const [] : _top(_save!.clubApps, n);

  /// 自クラブでの得点の歴代上位。
  List<ClubRecordRow> clubGoalsLeaders({int n = 5}) =>
      _save == null ? const [] : _top(_save!.clubGoals, n);

  /// テスト用: 試合1つぶんを記録に足す。
  @visibleForTesting
  void debugRecordClubMatch(MatchResult r, Fixture f) => _recordClubMatch(r, f);
}
