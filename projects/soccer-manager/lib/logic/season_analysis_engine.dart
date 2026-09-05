import '../models/league.dart';
import '../models/match_result.dart';

/// シーズンの傾向を1件。
class AnalysisRow {
  final String label;
  final String value;
  final String? detail;

  const AnalysisRow({required this.label, required this.value, this.detail});
}

/// 消化済みの試合から、自クラブの傾向を集計する。
///
/// これまで成績は「順位表」と「選手ごとの出場・得点」しか見られなかった。
/// 勝っているのか負けているのかは分かっても、**どう勝ってどう負けたのか**が
/// 分からない。前半に失点が多いのか、ホームで取りこぼしているのか、
/// 特定の時間帯に崩れるのか——次に何を変えるかは、そこを見ないと決まらない。
///
/// 新しい数値は持たせない。既に保存されている試合結果から導けるものだけを
/// 出す。保存にも試合計算にも手を入れないので、表示と実態がずれない。
class SeasonAnalysisEngine {
  /// 前半・後半の境目(分)。
  static const int halfTimeMinute = 45;

  /// 終盤とみなす時間(分)。
  static const int lateGameMinute = 75;

  /// 自クラブの消化済みリーグ戦。
  static List<Fixture> playedFixturesFor(League league, String teamId) =>
      league.fixtures
          .where((f) =>
              f.result != null &&
              (f.homeTeamId == teamId || f.awayTeamId == teamId))
          .toList();

  /// ホーム／アウェイの成績。
  static ({int played, int won, int drawn, int lost, int gf, int ga}) record(
    League league,
    String teamId, {
    bool? home,
  }) {
    var played = 0, won = 0, drawn = 0, lost = 0, gf = 0, ga = 0;
    for (final f in playedFixturesFor(league, teamId)) {
      final isHome = f.homeTeamId == teamId;
      if (home != null && isHome != home) continue;
      final r = f.result!;
      final own = isHome ? r.homeGoals : r.awayGoals;
      final opp = isHome ? r.awayGoals : r.homeGoals;
      played++;
      gf += own;
      ga += opp;
      if (own > opp) {
        won++;
      } else if (own == opp) {
        drawn++;
      } else {
        lost++;
      }
    }
    return (played: played, won: won, drawn: drawn, lost: lost, gf: gf, ga: ga);
  }

  /// 時間帯ごとの得点・失点。前半／後半／終盤(75分以降)。
  ///
  /// 終盤は後半に含まれる(後半のうち終盤がどれだけかを見るため)。
  static ({int firstFor, int firstAgainst, int secondFor, int secondAgainst,
          int lateFor, int lateAgainst})
      goalsByPeriod(League league, String teamId) {
    var firstFor = 0, firstAgainst = 0;
    var secondFor = 0, secondAgainst = 0;
    var lateFor = 0, lateAgainst = 0;
    for (final f in playedFixturesFor(league, teamId)) {
      final isHome = f.homeTeamId == teamId;
      for (final e in f.result!.events) {
        if (e.type != MatchEventType.goal) continue;
        final ours = e.teamId == teamId;
        final first = e.minute <= halfTimeMinute;
        if (ours) {
          if (first) {
            firstFor++;
          } else {
            secondFor++;
            if (e.minute >= lateGameMinute) lateFor++;
          }
        } else {
          if (first) {
            firstAgainst++;
          } else {
            secondAgainst++;
            if (e.minute >= lateGameMinute) lateAgainst++;
          }
        }
      }
      // 得点者が特定できないイベントに備え、スコアとの差は無視する。
      // ここで補正すると「どちらの時間帯か分からない得点」を勝手に
      // 割り振ることになり、傾向を歪める。
      if (isHome) continue;
    }
    return (
      firstFor: firstFor,
      firstAgainst: firstAgainst,
      secondFor: secondFor,
      secondAgainst: secondAgainst,
      lateFor: lateFor,
      lateAgainst: lateAgainst,
    );
  }

  /// 逆転された試合数(先制しながら勝てなかった試合)。
  static int gamesLostFromAhead(League league, String teamId) {
    var count = 0;
    for (final f in playedFixturesFor(league, teamId)) {
      final r = f.result!;
      final isHome = f.homeTeamId == teamId;
      final own = isHome ? r.homeGoals : r.awayGoals;
      final opp = isHome ? r.awayGoals : r.homeGoals;
      if (own >= opp) continue; // 負けた試合だけを見る

      // 最初の得点が自クラブなら、先制しながら負けたことになる。
      final goals = r.events
          .where((e) => e.type == MatchEventType.goal)
          .toList()
        ..sort((a, b) => a.minute.compareTo(b.minute));
      if (goals.isEmpty) continue;
      if (goals.first.teamId == teamId) count++;
    }
    return count;
  }
}
