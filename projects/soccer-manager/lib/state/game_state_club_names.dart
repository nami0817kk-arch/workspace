part of 'game_state.dart';

/// クラブ名の書き換え(2026-11-22)。ユースのアプリと同じく、実在に寄せた
/// 名前を自分の好きな名前に直せる。自クラブの名前も変えられる。
extension GameStateClubNames on GameState {
  /// 書き換えられるクラブ(自国の全部の部・ほかの国の1部・大陸の大会)。
  /// (見出し, クラブの一覧) の組で、自国の部から順に。
  List<(String, List<Team>)> get renamableClubGroups {
    final s = _save;
    if (s == null) return const [];
    final theme = currentLeagueTheme;
    final out = <(String, List<Team>)>[];
    for (var tier = 1; tier <= totalDivisionTiers; tier++) {
      final teams = tier == s.currentDivisionTier
          ? s.league.teams
          : s.otherDivisionLeagues[tier - 1]?.teams ?? const <Team>[];
      if (teams.isNotEmpty) out.add((theme.divisionName(tier), teams));
    }
    for (final t in LeagueTheme.values) {
      final l = s.foreignLeagues[t.name];
      if (l != null && l.teams.isNotEmpty) {
        out.add((t.divisionName(1), l.teams));
      }
    }
    if (s.continentalTeams.isNotEmpty) {
      out.add((Tr.pick('大陸の大会のクラブ', 'Continental clubs'), s.continentalTeams));
    }
    return out;
  }

  /// [teamId] のクラブの名前を [name] にする。空・40文字を超える名前は
  /// 受け付けない。自クラブなら、上の帯などに出るクラブ名も変わる。
  Future<bool> renameClub(String teamId, String name) async {
    final s = _save;
    if (s == null) return false;
    final n = name.trim();
    if (n.isEmpty || n.length > 40) return false;
    final teams = [
      ...s.allTeams,
      for (final l in s.foreignLeagues.values) ...l.teams,
      ...s.continentalTeams,
    ];
    var found = false;
    for (final t in teams) {
      if (t.id != teamId) continue;
      t.name = n;
      found = true;
    }
    if (!found) return false;
    if (teamId == s.userTeamId) s.clubName = n;
    if (teamId == s.rivalTeamId) s.rivalTeamName = n;
    _notify();
    await _persistNow();
    return true;
  }
}
