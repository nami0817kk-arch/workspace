part of 'game_state.dart';

/// 手放したクラブのその後(同じ国の中だけ)。
extension GameStateFormerClubs on GameState {
  /// 季の終わり: 手放したクラブが何部の何位だったかを記録し、知らせる。
  /// [playedTier]は自クラブが今季戦った部(今の [SaveGame.league] の部)。
  void _recordFormerClubs(int playedTier) {
    final s = _save!;
    if (s.formerClubs.isEmpty) return;
    final leagues = <(int, League)>[
      (playedTier, s.league),
      for (var i = 0; i < s.otherDivisionLeagues.length; i++)
        if (s.otherDivisionLeagues[i] != null)
          (i + 1, s.otherDivisionLeagues[i]!),
    ];
    // 順位表は部ごとに1回だけ作る(手放したクラブごとに作り直さない)。
    final tables = <League, List<StandingRow>>{};
    for (final e in s.formerClubs.entries) {
      for (final (tier, l) in leagues) {
        final rank = tables
            .putIfAbsent(l, () => l.sortedStandings)
            .indexWhere((r) => r.teamId == e.key);
        if (rank < 0) continue;
        s.formerClubStatus[e.key] = [l.season, tier, rank + 1];
        _logNews(
            Tr.pick('手放した${e.value}は、今季$tier部の${rank + 1}位だった。',
                'Your former club ${e.value} finished ${rank + 1}th in Tier $tier this season.'),
            context: Tr.pick('手放したクラブ', 'Former clubs'));
        break;
      }
    }
  }

  /// 手放したクラブと、最後に分かったその後([季, 部, 順位]。まだなら null)。
  List<(String name, List<int>? status)> get formerClubsAfter {
    final s = _save;
    if (s == null) return const [];
    return [
      for (final e in s.formerClubs.entries)
        (e.value, s.formerClubStatus[e.key]),
    ];
  }

  /// テスト用。
  @visibleForTesting
  void debugRecordFormerClubs(int playedTier) => _recordFormerClubs(playedTier);
}
