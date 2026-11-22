part of 'game_state.dart';

/// 季の締めで他国の1部が日程を作り直す前に、上位のクラブを控えておく
/// (大陸大会の相手にする)。保存はしない(季の切り替えの1回の処理の中だけ)。
List<Team> _lastForeignTop = [];

/// 他国の1部の今季の順位の順(国の name → クラブ)。季の締めで日程を
/// 作り直す前に控える(大陸大会の出場クラブを決めるのに使う)。
Map<String, List<Team>> _lastForeignOrder = {};

/// 大陸大会を実在の形に(他国の1部の上位と戦う)と、国の係数。
extension GameStateCoefficient on GameState {
  /// 自国から大陸大会に出られるクラブの数(係数の順位で決まる)。
  int get continentalSpots {
    final rank = countryCoefficientRanking
            .indexWhere((r) => r.$1 == currentLeagueTheme) +
        1;
    return CountryCoefficientEngine.spotsForRank(rank <= 0 ? 5 : rank);
  }

  /// 国の係数の順位(国と、5季の合計)。記録の無い国は実在の順位に寄せた
  /// 元の値([CountryCoefficientEngine.seedHistory])で数える。並んだら
  /// LeagueTheme の並び順(イングランド・スペイン・ドイツ・イタリア・
  /// フランス)。
  List<(LeagueTheme, double)> get countryCoefficientRanking {
    final s = _save;
    final rows = [
      for (final t in LeagueTheme.values)
        (
          t,
          CountryCoefficientEngine.total(s?.countryCoefficients[t.name] ??
              CountryCoefficientEngine.seedHistory(t.name)),
        ),
    ]..sort((a, b) {
        final c = b.$2.compareTo(a.$2);
        return c != 0 ? c : a.$1.index.compareTo(b.$1.index);
      });
    return rows;
  }

  /// 他国の1部から大陸大会の相手の候補にするクラブの数(各国の上位)。
  /// 日程画面の他国の順位表の印も、この数に揃える。
  static const int foreignTopPerLeague = 2;

  /// 他国の1部の、今季の上位[foreignTopPerLeague]クラブを控える
  /// (日程を作り直す前に呼ぶ)。
  void _rememberForeignTop() {
    final s = _save!;
    _lastForeignTop = [];
    _lastForeignOrder = {};
    for (final e in s.foreignLeagues.entries) {
      final l = e.value;
      final played = l.sortedStandings.any((r) => r.played > 0);
      final order = played
          ? [
              for (final r in l.sortedStandings)
                l.teams.firstWhere((t) => t.id == r.teamId)
            ]
          : ([...l.teams]
            ..sort((a, b) => b.overallRating.compareTo(a.overallRating)));
      _lastForeignTop.addAll(order.take(foreignTopPerLeague));
      _lastForeignOrder[e.key] = order;
    }
  }

  /// 大陸大会の1クラブぶんの今季の点(勝ち2・引き分け1・勝ち抜くごとに1)。
  static Map<String, double> _continentalPointsByClub(ContinentalCup cup) {
    final w = <String, int>{};
    final d = <String, int>{};
    final won = <String, int>{};
    void tally(String home, String away, int hg, int ag) {
      if (hg > ag) {
        w[home] = (w[home] ?? 0) + 1;
      } else if (hg < ag) {
        w[away] = (w[away] ?? 0) + 1;
      } else {
        d[home] = (d[home] ?? 0) + 1;
        d[away] = (d[away] ?? 0) + 1;
      }
    }

    for (final m in cup.groupMatches) {
      final r = m.result;
      if (r != null) {
        tally(m.homeTeamId, m.awayTeamId, r.homeGoals, r.awayGoals);
      }
    }
    for (final round in cup.knockoutRounds) {
      for (final tie in round) {
        for (final r in tie.legs) {
          tally(r.homeTeamId, r.awayTeamId, r.homeGoals, r.awayGoals);
        }
        final win = tie.winnerId;
        if (win != null) won[win] = (won[win] ?? 0) + 1;
      }
    }
    final ids = {for (final g in cup.groups) ...g};
    return {
      for (final id in ids)
        id: CountryCoefficientEngine.seasonPoints(
            wins: w[id] ?? 0, draws: d[id] ?? 0, roundsWon: won[id] ?? 0),
    };
  }

  /// 季の締め: 今季の大陸大会の成績を各国の係数に足す。
  ///
  /// 大会に出たクラブの国が分かるとき(2026-11-22 からの形)は、その国の
  /// クラブの点の平均(実在の係数と同じ考え方)。分からない古い大会では、
  /// 自国は自クラブの成績から、他国はその国の1部の上位の強さから見積もる。
  void _updateCountryCoefficients() {
    final s = _save!;
    final home = currentLeagueTheme;
    final sums = <String, double>{};
    final clubs = <String, int>{};
    for (final c in [s.continentalCup, s.secondContinentalCup]) {
      if (c == null || c.countries.isEmpty) continue;
      final pts = _continentalPointsByClub(c);
      c.countries.forEach((id, theme) {
        sums[theme] = (sums[theme] ?? 0) + (pts[id] ?? 0);
        clubs[theme] = (clubs[theme] ?? 0) + 1;
      });
    }
    final cup = s.continentalCup;
    var homePoints = 0.0;
    if (cup != null && cup.countries.isEmpty) {
      final me = s.userTeamId;
      var w = 0, d = 0, won = 0;
      for (final m in cup.groupMatches) {
        final r = m.result;
        if (r == null || (m.homeTeamId != me && m.awayTeamId != me)) continue;
        final mine = m.homeTeamId == me ? r.homeGoals : r.awayGoals;
        final theirs = m.homeTeamId == me ? r.awayGoals : r.homeGoals;
        if (mine > theirs) {
          w++;
        } else if (mine == theirs) {
          d++;
        }
      }
      for (final round in cup.knockoutRounds) {
        for (final tie in round) {
          if (tie.winnerId == me) won++;
        }
      }
      homePoints = CountryCoefficientEngine.seasonPoints(
          wins: w, draws: d, roundsWon: won);
    }
    final rng = Random(s.league.season * 7919);
    for (final t in LeagueTheme.values) {
      double pts;
      final n = clubs[t.name] ?? 0;
      if (n > 0) {
        pts = sums[t.name]! / n;
      } else if (t == home) {
        pts = homePoints;
      } else {
        final l = s.foreignLeagues[t.name];
        final top = l == null
            ? 75
            : ([...l.teams.map((x) => x.overallRating)]
                      ..sort((a, b) => b.compareTo(a)))
                    .take(4)
                    .fold<int>(0, (a, b) => a + b) /
                4;
        // 1部の上位が強い国ほど点を取る(4〜14点のあたり)。
        pts = ((top - 78) * 0.6 + 6 + rng.nextDouble() * 4).clamp(0, 20);
      }
      s.countryCoefficients[t.name] = CountryCoefficientEngine.push(
          s.countryCoefficients[t.name] ??
              CountryCoefficientEngine.seedHistory(t.name),
          pts);
    }
  }

  /// 大陸大会の相手: 他国の1部の今季の上位(各国2クラブ)から7クラブ。
  /// 控えが無ければ(旧セーブ・最初の季)、他国の1部の強い順から。
  List<Team> _realContinentalOpponents() {
    final s = _save!;
    var pool = [..._lastForeignTop];
    if (pool.length < 7) {
      pool = [
        for (final l in s.foreignLeagues.values)
          ...([...l.teams]
                ..sort((a, b) => b.overallRating.compareTo(a.overallRating)))
              .take(2),
      ];
    }
    // 保存は別に持つ(他国のリーグの選手そのものは動かさない)。
    return [
      for (final t in pool.take(7)) Team.fromJson(t.toJson()),
    ];
  }

  /// テスト用。
  @visibleForTesting
  void debugUpdateCountryCoefficients() => _updateCountryCoefficients();
  @visibleForTesting
  List<Team> debugContinentalOpponents() {
    _rememberForeignTop();
    return _realContinentalOpponents();
  }
}
