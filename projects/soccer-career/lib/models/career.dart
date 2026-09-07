import 'club.dart';
import 'player.dart';
import 'season.dart';

/// 過去シーズンの記録。引退後に振り返るためのもの。
class SeasonRecord {
  const SeasonRecord({
    required this.year,
    required this.clubName,
    required this.tier,
    required this.leaguePosition,
    required this.stats,
  });

  final int year;
  final String clubName;
  final int tier;
  final int leaguePosition;
  final SeasonStats stats;

  Map<String, dynamic> toJson() => {
        'year': year,
        'clubName': clubName,
        'tier': tier,
        'leaguePosition': leaguePosition,
        'appearances': stats.appearances,
        'goals': stats.goals,
        'assists': stats.assists,
        'averageRating': stats.averageRating,
      };

  factory SeasonRecord.fromJson(Map<String, dynamic> json) => SeasonRecord(
        year: json['year'] as int,
        clubName: json['clubName'] as String,
        tier: json['tier'] as int,
        leaguePosition: json['leaguePosition'] as int,
        stats: SeasonStats(
          appearances: json['appearances'] as int,
          goals: json['goals'] as int,
          assists: json['assists'] as int,
          averageRating: (json['averageRating'] as num).toDouble(),
        ),
      );
}

/// キャリア全体の状態。これ1つを保存すれば続きから再開できる。
class CareerState {
  CareerState({
    required this.player,
    required this.club,
    required this.league,
    required this.year,
    required this.fixtures,
    required this.results,
    required this.table,
    required this.history,
  });

  Player player;
  Club club;

  /// 所属リーグのクラブ一覧（自分のクラブを含む20チーム）。
  List<Club> league;

  int year;

  /// 対戦相手のクラブIDを節順に並べたもの。ホームかどうかは節の偶奇で決める。
  List<String> fixtures;

  /// 今シーズンの試合結果。
  List<MatchResult> results;

  /// 今シーズンの順位表。
  List<TableRow> table;

  /// 過去シーズンの記録。
  List<SeasonRecord> history;

  int get matchday => results.length + 1;
  bool get seasonFinished => results.length >= fixtures.length;

  SeasonStats get seasonStats => SeasonStats.from(results);

  Club opponentFor(int matchday) {
    final id = fixtures[matchday - 1];
    return league.firstWhere((c) => c.id == id);
  }

  /// ホームとアウェイを交互にする。厳密な日程表は作らない。
  bool isHome(int matchday) => matchday.isOdd;

  List<TableRow> get sortedTable {
    final rows = [...table];
    rows.sort((a, b) {
      final byPoints = b.points.compareTo(a.points);
      if (byPoints != 0) return byPoints;
      final byDiff = b.goalDifference.compareTo(a.goalDifference);
      if (byDiff != 0) return byDiff;
      return b.goalsFor.compareTo(a.goalsFor);
    });
    return rows;
  }

  int get leaguePosition =>
      sortedTable.indexWhere((r) => r.clubId == club.id) + 1;

  Map<String, dynamic> toJson() => {
        'player': player.toJson(),
        'club': club.toJson(),
        'league': league.map((c) => c.toJson()).toList(),
        'year': year,
        'fixtures': fixtures,
        'results': results.map((r) => r.toJson()).toList(),
        'table': table.map((r) => r.toJson()).toList(),
        'history': history.map((h) => h.toJson()).toList(),
      };

  factory CareerState.fromJson(Map<String, dynamic> json) => CareerState(
        player: Player.fromJson(json['player'] as Map<String, dynamic>),
        club: Club.fromJson(json['club'] as Map<String, dynamic>),
        league: (json['league'] as List)
            .map((c) => Club.fromJson(c as Map<String, dynamic>))
            .toList(),
        year: json['year'] as int,
        fixtures: (json['fixtures'] as List).cast<String>(),
        results: (json['results'] as List)
            .map((r) => MatchResult.fromJson(r as Map<String, dynamic>))
            .toList(),
        table: (json['table'] as List)
            .map((r) => TableRow.fromJson(r as Map<String, dynamic>))
            .toList(),
        history: (json['history'] as List)
            .map((h) => SeasonRecord.fromJson(h as Map<String, dynamic>))
            .toList(),
      );
}
