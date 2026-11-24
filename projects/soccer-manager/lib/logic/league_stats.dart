import '../models/league.dart';
import '../models/match_result.dart';
import '../models/player.dart';

/// リーグ戦の選手ごとの今季の成績(1人分)。
class PlayerSeasonLine {
  PlayerSeasonLine({
    required this.playerId,
    required this.name,
    required this.teamId,
  });

  final String playerId;
  String name;

  /// いちばん最近に出た試合のクラブ(季の途中で移った選手は移った先)。
  String teamId;

  /// 採点が付いた試合の数(出場数)。
  int apps = 0;
  int goals = 0;
  int assists = 0;
  int yellows = 0;
  int reds = 0;

  /// マン・オブ・ザ・マッチ(その試合でいちばん高い採点)の数。
  int motm = 0;

  /// GK として出て、相手を0点に抑えた試合の数。
  int cleanSheets = 0;
  double _ratingSum = 0;

  /// 平均採点(出場が無ければ0)。
  double get avgRating => apps == 0 ? 0 : _ratingSum / apps;
}

/// リーグの個人成績を、保存済みの試合結果から数え直す。
///
/// 新しい数値は持たせない。得点・アシスト・カードは出来事から、出場・採点・
/// マン・オブ・ザ・マッチ・無失点は採点の記録から数える(自クラブ以外の
/// 試合も、得点・カード・採点は残っている: [MatchResult.keptInArchive])。
class LeagueStats {
  LeagueStats._(this.lines);

  /// 選手ID → 成績。
  final Map<String, PlayerSeasonLine> lines;

  /// 平均採点の順位に入る最低の出場数(全節の3分の1。少なくとも1)。
  static int minAppsForRating(League league) {
    final matchdays =
        league.fixtures.where((f) => f.result != null).map((f) => f.matchday);
    final played = matchdays.isEmpty ? 0 : matchdays.reduce((a, b) => a > b ? a : b);
    return (played / 3).ceil().clamp(1, 99);
  }

  static LeagueStats compute(League league) {
    final out = <String, PlayerSeasonLine>{};
    // 名前と位置は、いまの所属から引く(居なくなった選手は出来事の名前)。
    final current = <String, (Player, String)>{
      for (final t in league.teams)
        for (final p in t.players) p.id: (p, t.id),
    };
    PlayerSeasonLine lineOf(String id, String teamId, String? name) {
      final line = out[id];
      if (line != null) {
        if (name != null && line.name.isEmpty) line.name = name;
        return line;
      }
      final cur = current[id];
      return out[id] = PlayerSeasonLine(
        playerId: id,
        name: cur?.$1.name ?? name ?? '',
        teamId: teamId,
      );
    }

    final fixtures = [...league.fixtures.where((f) => f.result != null)]
      ..sort((a, b) => a.matchday.compareTo(b.matchday));
    for (final f in fixtures) {
      final r = f.result!;
      final motm = r.manOfTheMatchId;
      for (final e in r.ratingsTeams(current)) {
        final line = lineOf(e.$1, e.$2, null);
        line.teamId = e.$2;
        line.apps++;
        line._ratingSum += e.$3;
        if (e.$1 == motm) line.motm++;
        final isGk = current[e.$1]?.$1.position == Position.gk;
        final conceded = e.$2 == r.homeTeamId ? r.awayGoals : r.homeGoals;
        if (isGk && conceded == 0) line.cleanSheets++;
      }
      for (final e in r.events) {
        switch (e.type) {
          case MatchEventType.goal:
            if (e.scorerId != null) {
              lineOf(e.scorerId!, e.teamId, e.scorerName).goals++;
            }
            if (e.assistId != null) {
              lineOf(e.assistId!, e.teamId, e.assistName).assists++;
            }
          case MatchEventType.yellowCard:
            if (e.scorerId != null) {
              lineOf(e.scorerId!, e.teamId, e.scorerName).yellows++;
            }
          case MatchEventType.redCard:
            if (e.scorerId != null) {
              lineOf(e.scorerId!, e.teamId, e.scorerName).reds++;
            }
          case MatchEventType.chance:
          case MatchEventType.substitution:
            break;
        }
      }
    }
    out.removeWhere((_, l) => l.name.isEmpty);
    return LeagueStats._(out);
  }

  /// [value] の大きい順に上位[limit]人(0は除く)。同じなら出場の少ない順、
  /// それでも同じなら名前順(並びが揺れないように)。
  List<PlayerSeasonLine> top(num Function(PlayerSeasonLine) value,
      {int limit = 20, int minApps = 0}) {
    final list = lines.values
        .where((l) => value(l) > 0 && l.apps >= minApps)
        .toList()
      ..sort((a, b) {
        final c = value(b).compareTo(value(a));
        if (c != 0) return c;
        final d = a.apps.compareTo(b.apps);
        if (d != 0) return d;
        return a.name.compareTo(b.name);
      });
    return list.length > limit ? list.sublist(0, limit) : list;
  }

  /// [teamId] の選手(出場のある選手)。出場の多い順。
  List<PlayerSeasonLine> ofTeam(String teamId) => lines.values
      .where((l) => l.teamId == teamId && l.apps > 0)
      .toList()
    ..sort((a, b) {
      final c = b.apps.compareTo(a.apps);
      return c != 0 ? c : b.avgRating.compareTo(a.avgRating);
    });
}

extension on MatchResult {
  /// 採点の付いた選手の(選手ID, クラブID, 採点)。クラブはいまの所属から
  /// 引き、引けなければこの試合の得点・カードの出来事から引く。どちらでも
  /// 分からない選手(季の途中で他のリーグへ移った控えなど)は数えない。
  Iterable<(String, String, double)> ratingsTeams(
      Map<String, (Player, String)> current) sync* {
    for (final e in playerRatings.entries) {
      var team = current[e.key]?.$2;
      if (team != homeTeamId && team != awayTeamId) {
        team = events
            .where((ev) => ev.scorerId == e.key || ev.assistId == e.key)
            .map((ev) => ev.teamId)
            .firstOrNull;
      }
      if (team == null) continue;
      yield (e.key, team, e.value);
    }
  }
}
