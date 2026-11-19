part of 'game_state.dart';

/// 1行ぶんの隠れた逸材(選手・クラブの名前・見込みの潜在)。
typedef HiddenGem = ({Player player, String club, int potential});

/// U18/U21 と、分析部門。
extension GameStateYouthAnalytics on GameState {
  /// U21 の選手(先発に入っていない21歳以下・貸し出していない)。
  List<Player> get u21Squad => _save == null
      ? const []
      : [
          for (final p in userTeam.players)
            if (p.age <= U21Engine.maxAge &&
                !userTeam.startingXI.contains(p.id) &&
                !p.isLoanedOut &&
                !p.isLoan)
              p,
        ];

  /// U18 の候補(アカデミーの有望株)の数。
  int get u18Count => _save?.youthProspects.length ?? 0;

  /// 毎節: U21 の試合。先発に入っていない若手が試合に出て、少し伸びる。
  void _playU21Matchday({Random? rng}) {
    final r = rng ?? Random();
    for (final p in u21Squad) {
      p.matchSharpness = (p.matchSharpness + 8).clamp(0, 100);
      if (p.potential > p.overall && r.nextDouble() < U21Engine.growChance) {
        PlayerStub.matchOverall(p, p.overall + 1);
      }
    }
  }

  /// 分析部門を置く・やめる。置くときは今季の年会費を払う。
  Future<bool> setAnalytics(bool on) async {
    final s = _save;
    if (s == null || s.hasAnalytics == on) return false;
    if (on) {
      final fee = scaledMoney(AnalyticsEngine.annualFee);
      if (s.budget < fee) return false;
      _book(LedgerCategory.facilities, -fee);
    }
    s.hasAnalytics = on;
    _notify();
    await _persist();
    return true;
  }

  /// 季の切り替え: 分析部門の年会費。払えなければ閉じる。
  void _rollAnalytics() {
    final s = _save!;
    if (!s.hasAnalytics) return;
    final fee = scaledMoney(AnalyticsEngine.annualFee);
    if (s.budget < fee) {
      s.hasAnalytics = false;
      return;
    }
    _book(LedgerCategory.facilities, -fee);
  }

  /// 隠れた逸材: 他のクラブの21歳以下で、伸びしろが大きく、まだ安い選手。
  /// 分析部門があるときだけ、データから潜在を見抜いて出す。
  List<HiddenGem> get hiddenGems {
    final s = _save;
    if (s == null || !s.hasAnalytics) return const [];
    final out = <HiddenGem>[];
    for (final t in _worldTeams) {
      if (t.id == s.userTeamId) continue;
      for (final p in t.players) {
        if (p.age > 21 || p.potential - p.overall < 12) continue;
        out.add((player: p, club: t.name, potential: p.potential));
      }
    }
    out.sort((a, b) => (b.potential - b.player.overall)
        .compareTo(a.potential - a.player.overall));
    return out.take(5).toList();
  }

  /// [r]の自クラブと相手の xG(分析部門があるときだけ。無ければ null)。
  (double, double)? xgOf(MatchResult r) {
    final s = _save;
    if (s == null || !s.hasAnalytics) return null;
    if (r.homeShots == null || r.awayShots == null) return null;
    final home = AnalyticsEngine.xg(
        shots: r.homeShots!, onTarget: r.homeShotsOnTarget ?? 0);
    final away = AnalyticsEngine.xg(
        shots: r.awayShots!, onTarget: r.awayShotsOnTarget ?? 0);
    return r.homeTeamId == s.userTeamId ? (home, away) : (away, home);
  }

  @visibleForTesting
  void debugPlayU21Matchday(Random rng) => _playU21Matchday(rng: rng);
}
