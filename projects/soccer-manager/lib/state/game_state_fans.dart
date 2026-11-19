part of 'game_state.dart';

/// ファンの層と、自治体のスタジアムの補助。
extension GameStateFans on GameState {
  /// 自治体に補助を頼める間隔(季)。
  static const int subsidyCooldown = 3;

  /// 補助が下りたときの、次のスタジアムの増築の割引(%)。
  static const int subsidyPct = 40;

  /// 層ごとの満足(0〜100)。
  Map<FanSegment, int> get fanMoods {
    final s = _save;
    if (s == null) return const {};
    final team = userTeam;
    final homegrown = team.players
        .where((p) => team.startingXI.contains(p.id) && p.isHomegrown)
        .length;
    final played = s.league.fixtures
        .where((f) =>
            f.result != null &&
            (f.homeTeamId == team.id || f.awayTeamId == team.id))
        .toList()
      ..sort((a, b) => b.matchday.compareTo(a.matchday));
    var pts = 0;
    for (final f in played.take(5)) {
      final r = f.result!;
      final mine = f.homeTeamId == team.id ? r.homeGoals : r.awayGoals;
      final theirs = f.homeTeamId == team.id ? r.awayGoals : r.homeGoals;
      pts += mine > theirs ? 3 : (mine == theirs ? 1 : 0);
    }
    // 試合がまだ無ければ、勝ち点は真ん中の扱い。
    if (played.isEmpty) pts = 7;
    final pops = [
      for (final p in team.players) PlayerPopularityEngine.popularity(p)
    ]..sort((a, b) => b.compareTo(a));
    return {
      FanSegment.core: s.confidence,
      FanSegment.local: FanSegmentEngine.localMood(
          homegrownStarters: homegrown,
          ticketAttendance: s.ticketPricing.attendanceMultiplier),
      FanSegment.casual: FanSegmentEngine.casualMood(
          recentPoints: pts, topPopularity: pops.isEmpty ? 0 : pops.first),
    };
  }

  /// 層の満足から出す、観客の入りの倍率(0.95〜1.05)。
  double get fanAttendanceModifier => _save == null
      ? 1.0
      : FanSegmentEngine.attendanceModifier(
          FanSegmentEngine.weighted(fanMoods));

  /// 自治体に補助を頼めるか(3季に1回)。
  bool get canAskMunicipality {
    final s = _save;
    if (s == null || s.stadiumSubsidyPct > 0) return false;
    return s.municipalityAskSeason == 0 ||
        s.league.season - s.municipalityAskSeason >= subsidyCooldown;
  }

  /// 自治体にスタジアムの補助を頼む。地元・家族の満足が55以上なら、次の
  /// スタジアムの増築が4割引きになる。返すのは下りたかどうか。
  Future<bool> askMunicipality() async {
    final s = _save;
    if (s == null || !canAskMunicipality) return false;
    s.municipalityAskSeason = s.league.season;
    final ok = (fanMoods[FanSegment.local] ?? 0) >= 55;
    if (ok) s.stadiumSubsidyPct = subsidyPct;
    _logNews(
        ok
            ? Tr.pick('自治体がスタジアムの補助を決めた。次の増築は$subsidyPct%を自治体が持つ。',
                'The council will fund $subsidyPct% of your next stadium expansion.')
            : Tr.pick('自治体は補助を見送った。地元とのつながりが足りないという。',
                'The council turned you down: not enough local support.'),
        context: Tr.pick('自治体', 'Council'));
    _notify();
    await _persist();
    return ok;
  }
}
