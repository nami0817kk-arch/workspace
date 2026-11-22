import '../models/match_result.dart';
import '../models/player.dart';
import '../models/team.dart';

/// 1試合の出場手当の計算。
///
/// 出場手当([Player.appearanceFee])は、先発なら満額、途中出場なら半額。
/// リーグ戦・国内カップ・リーグカップ・スーパーカップ・大陸大会のどれでも
/// 払う(親善試合は払わない)。以前はリーグ戦の先発だけに払っていて、
/// 途中出場やカップ戦は無料だった(2026-11-23)。
class AppearanceFeeEngine {
  /// 途中出場の出場手当は、先発の何割か。
  static const double substituteShare = 0.5;

  /// 途中出場の出場手当(万円)。
  static int substituteFee(Player p) =>
      (p.appearanceFee * substituteShare).round();

  /// [r]で[teamId]のクラブに途中から入った選手のID。
  static Set<String> substitutesOn(MatchResult r, String teamId) => {
        for (final e in r.events)
          if (e.type == MatchEventType.substitution &&
              e.teamId == teamId &&
              e.scorerId != null)
            e.scorerId!,
      };

  /// [r]で[teamId]のクラブから下がった選手のID(先発、または途中から
  /// 入って下がった選手)。
  static Set<String> substitutesOff(MatchResult r, String teamId) => {
        for (final e in r.events)
          if (e.type == MatchEventType.substitution &&
              e.teamId == teamId &&
              e.assistId != null)
            e.assistId!,
      };

  /// [team]の選手に、試合[r]の出場手当として払う合計(万円)。
  ///
  /// 途中から入った選手は半額。先発(試合のあとの先発の指定に残る選手と、
  /// 途中で下がった選手のうち途中から入っていない選手)は満額。試合中の
  /// 交代で先発の指定が入れ替わっていても、交代の出来事から数え直すので
  /// 二重には払わない。[includeStarters]が false なら途中出場の分だけ
  /// (リーグ戦は先発の分を試合の前に払っている)。
  static int feesFor(Team team, MatchResult r, {bool includeStarters = true}) {
    final on = substitutesOn(r, team.id);
    final played = <String>{
      ...team.startingXI,
      ...substitutesOff(r, team.id),
      ...on,
    };
    var total = 0;
    for (final p in team.players) {
      if (!played.contains(p.id)) continue;
      if (on.contains(p.id)) {
        total += substituteFee(p);
      } else if (includeStarters) {
        total += p.appearanceFee;
      }
    }
    return total;
  }
}
