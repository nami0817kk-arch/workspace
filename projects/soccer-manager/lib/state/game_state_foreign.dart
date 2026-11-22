part of 'game_state.dart';

/// 他国の1部も、自国と同じ節で裏で試合を進める。季の終わりに優勝を伝え、
/// 次の季の日程を作る。
extension GameStateForeign on GameState {
  /// 日程の無い他国のリーグ(旧セーブ・作った直後)に、総当たりの日程を作る。
  void _ensureForeignFixtures(SaveGame save) {
    for (final e in save.foreignLeagues.entries.toList()) {
      final l = e.value;
      if (l.fixtures.isNotEmpty || l.teams.length < 2) continue;
      save.foreignLeagues[e.key] = League(
        teams: l.teams,
        fixtures: FixtureGenerator.generateDoubleRoundRobin(l.teams),
        season: save.league.season,
      );
    }
  }

  /// [md]節の他国の試合を進める。
  /// 警告はその国のリーグ戦の決まりで数える。
  void _playForeignMatchday(int md) {
    final s = _save!;
    for (final e in s.foreignLeagues.entries) {
      final l = e.value;
      final rules = CardRules.league(
        theme: LeagueTheme.values.where((t) => t.name == e.key).firstOrNull,
        matchday: md,
        totalMatchdays:
            l.fixtures.fold<int>(0, (m, f) => f.matchday > m ? f.matchday : m),
      );
      CardRules.run(rules, () {
        for (final f in l.fixturesForMatchday(md)) {
          if (f.result != null) continue;
          final home = _findTeam(l.teams, f.homeTeamId);
          final away = _findTeam(l.teams, f.awayTeamId);
          if (home == null || away == null) continue;
          f.result = BackgroundMatchEngine.simulate(
              home: home, away: away, matchday: md);
          BackgroundMatchEngine.applyPlayerEffects(home: home, away: away);
        }
      });
    }
  }

  /// 季の終わり: 残りの試合を済ませ、優勝を伝え、次の季の日程を作る。
  void _finishForeignSeasons() {
    final s = _save!;
    for (final e in s.foreignLeagues.entries.toList()) {
      final l = e.value;
      if (l.fixtures.isEmpty) continue;
      final remaining = l.fixtures.where((f) => f.result == null).toList();
      for (final f in remaining) {
        final home = _findTeam(l.teams, f.homeTeamId);
        final away = _findTeam(l.teams, f.awayTeamId);
        if (home == null || away == null) continue;
        f.result = BackgroundMatchEngine.simulate(
            home: home, away: away, matchday: f.matchday);
        BackgroundMatchEngine.applyPlayerEffects(home: home, away: away);
      }
      final table = l.sortedStandings;
      if (table.isNotEmpty) {
        final champ = l.teams
            .where((t) => t.id == table.first.teamId)
            .firstOrNull
            ?.name;
        final theme = LeagueTheme.values
            .where((t) => t.name == e.key)
            .firstOrNull;
        if (champ != null && theme != null) {
          _logNews(
              Tr.pick('${theme.label}は$champが優勝した。',
                  '$champ won the ${theme.label}.'),
              context: Tr.pick('他国のリーグ', 'Leagues abroad'));
        }
      }
      s.foreignLeagues[e.key] = League(
        teams: l.teams,
        fixtures: FixtureGenerator.generateDoubleRoundRobin(l.teams),
        season: l.season + 1,
      );
    }
  }

  /// 他国の1部(リーグの名前と、そのリーグ)。日程・順位表の画面に出す。
  List<(String, League)> get foreignLeagueTables {
    final s = _save;
    if (s == null) return const [];
    return [
      for (final theme in LeagueTheme.values)
        if (s.foreignLeagues[theme.name] != null &&
            s.foreignLeagues[theme.name]!.fixtures.isNotEmpty)
          (theme.label, s.foreignLeagues[theme.name]!),
    ];
  }

  /// テスト用: 他国の節を進める・季を締める。
  @visibleForTesting
  void debugPlayForeignMatchday(int md) => _playForeignMatchday(md);
  @visibleForTesting
  void debugFinishForeignSeasons() => _finishForeignSeasons();
}
