import 'team.dart';
import 'enum_json.dart';
import 'match_result.dart';
import 'weather.dart';

/// 昇格ピラミッド全体のディビジョン数(1部が最上位、3部が最下位)。
/// 2026-11-22 に5部制から3部制にした(実在の上から3つのリーグ)。
const int totalDivisionTiers = 3;

class Fixture {
  final int matchday;
  final String homeTeamId;
  final String awayTeamId;
  MatchResult? result;

  /// この試合の天候。試合開始時に決定される(未開催の場合はnull)。
  Weather? weather;

  Fixture({
    required this.matchday,
    required this.homeTeamId,
    required this.awayTeamId,
    this.result,
    this.weather,
  });

  /// まだの試合の結果・天候(null)は書かない(2026-11-23)。
  Map<String, dynamic> toJson() => {
        'matchday': matchday,
        'homeTeamId': homeTeamId,
        'awayTeamId': awayTeamId,
        if (result != null) 'result': result!.toJson(),
        if (weather != null) 'weather': weather!.name,
      };

  factory Fixture.fromJson(Map<String, dynamic> json) => Fixture(
        matchday: json['matchday'] as int,
        homeTeamId: json['homeTeamId'] as String,
        awayTeamId: json['awayTeamId'] as String,
        result: json['result'] == null
            ? null
            : MatchResult.fromJson(json['result'] as Map<String, dynamic>),
        weather: json['weather'] == null
            ? null
            : enumFromName(
                Weather.values,
                json['weather'] as String?,
                Weather.clear,
              ),
      );
}

class StandingRow {
  final String teamId;
  int played = 0;
  int won = 0;
  int draw = 0;
  int lost = 0;
  int goalsFor = 0;
  int goalsAgainst = 0;

  /// 規則違反による勝ち点の増減(剥奪は負)。
  int adjustment = 0;

  StandingRow({required this.teamId});

  int get points => won * 3 + draw + adjustment;
  int get goalDiff => goalsFor - goalsAgainst;
}

class League {
  List<Team> teams;
  List<Fixture> fixtures;
  int season;

  /// チームごとの勝ち点の増減(規則違反の剥奪)。順位表にだけ効く。
  final Map<String, int> pointsAdjustments;

  /// 勝ち点で並んだときに、得失点差を直接対決より先に見るか。
  /// イングランド・ドイツ・フランスは得失点差が先、スペイン・イタリアは
  /// 直接対決が先(実在のリーグの決まり。2026-11-22)。false が直接対決先
  /// (それまでの形。大陸大会のグループもこちら)。
  bool goalDiffFirst;

  League({
    required this.teams,
    required this.fixtures,
    this.season = 1,
    Map<String, int>? pointsAdjustments,
    this.goalDiffFirst = false,
  }) : pointsAdjustments = pointsAdjustments ?? {};

  Fixture? get nextUnplayedFixture {
    final unplayed = fixtures.where((f) => f.result == null).toList();
    if (unplayed.isEmpty) return null;
    unplayed.sort((a, b) => a.matchday.compareTo(b.matchday));
    return unplayed.first;
  }

  bool get isSeasonComplete => fixtures.every((f) => f.result != null);

  /// [userTeamId]のクラブが出ていない試合の結果を、残す形
  /// ([MatchResult.archived])にする。自クラブの試合はそのまま。
  void archiveResultsExcept(String userTeamId) {
    for (final f in fixtures) {
      final r = f.result;
      if (r == null) continue;
      if (f.homeTeamId == userTeamId || f.awayTeamId == userTeamId) continue;
      f.result = r.archived();
    }
  }

  /// 指定チームが直近にプレーした(結果が確定している)試合を返す。まだ1試合も
  /// 消化していない場合はnull。
  Fixture? lastPlayedFixtureFor(String teamId) {
    final played = fixtures
        .where(
          (f) =>
              f.result != null &&
              (f.homeTeamId == teamId || f.awayTeamId == teamId),
        )
        .toList();
    if (played.isEmpty) return null;
    played.sort((a, b) => b.matchday.compareTo(a.matchday));
    return played.first;
  }

  /// 指定チームの直近[count]試合の結果('W'/'D'/'L')を、古い順→新しい順で返す
  /// (順位表のフォームガイド表示用)。
  List<String> recentFormFor(String teamId, {int count = 5}) {
    final played = fixtures
        .where(
          (f) =>
              f.result != null &&
              (f.homeTeamId == teamId || f.awayTeamId == teamId),
        )
        .toList()
      ..sort((a, b) => a.matchday.compareTo(b.matchday));
    final recent =
        played.length > count ? played.sublist(played.length - count) : played;
    return recent.map((f) {
      final r = f.result!;
      final isHome = f.homeTeamId == teamId;
      final goalsFor = isHome ? r.homeGoals : r.awayGoals;
      final goalsAgainst = isHome ? r.awayGoals : r.homeGoals;
      if (goalsFor > goalsAgainst) return 'W';
      if (goalsFor < goalsAgainst) return 'L';
      return 'D';
    }).toList();
  }

  List<Fixture> fixturesForMatchday(int md) =>
      fixtures.where((f) => f.matchday == md).toList();

  Map<String, StandingRow> _accumulate(
    List<String> teamIds,
    Iterable<Fixture> matches,
  ) {
    final map = {for (final id in teamIds) id: StandingRow(teamId: id)};
    for (final f in matches) {
      final r = f.result;
      if (r == null) continue;
      if (!map.containsKey(f.homeTeamId) || !map.containsKey(f.awayTeamId)) {
        continue;
      }
      final home = map[f.homeTeamId]!;
      final away = map[f.awayTeamId]!;
      home.played++;
      away.played++;
      home.goalsFor += r.homeGoals;
      home.goalsAgainst += r.awayGoals;
      away.goalsFor += r.awayGoals;
      away.goalsAgainst += r.homeGoals;
      if (r.homeGoals > r.awayGoals) {
        home.won++;
        away.lost++;
      } else if (r.homeGoals < r.awayGoals) {
        away.won++;
        home.lost++;
      } else {
        home.draw++;
        away.draw++;
      }
    }
    return map;
  }

  Map<String, StandingRow> computeStandings() {
    final map = _accumulate(teams.map((t) => t.id).toList(), fixtures);
    pointsAdjustments.forEach((id, delta) {
      map[id]?.adjustment = delta;
    });
    return map;
  }

  /// 勝点で並んだチーム群の順位を、まず当該チーム間の直接対決成績
  /// (勝点→得失点差→得点数)で決め、それでも並ぶ場合のみ全体の
  /// 得失点差→総得点にフォールバックする。
  List<StandingRow> _breakTies(List<StandingRow> group) {
    final ids = group.map((r) => r.teamId).toList();
    final h2h = _accumulate(ids, fixtures);
    final sorted = List<StandingRow>.from(group);
    sorted.sort((a, b) {
      final ah = h2h[a.teamId]!;
      final bh = h2h[b.teamId]!;
      if (goalDiffFirst) {
        // 得失点差 → 総得点 → 直接対決(勝点→得失点差→得点数)。
        final gd = b.goalDiff.compareTo(a.goalDiff);
        if (gd != 0) return gd;
        final gf = b.goalsFor.compareTo(a.goalsFor);
        if (gf != 0) return gf;
        final hp = bh.points.compareTo(ah.points);
        if (hp != 0) return hp;
        final hgd = bh.goalDiff.compareTo(ah.goalDiff);
        if (hgd != 0) return hgd;
        return bh.goalsFor.compareTo(ah.goalsFor);
      }
      final hp = bh.points.compareTo(ah.points);
      if (hp != 0) return hp;
      final hgd = bh.goalDiff.compareTo(ah.goalDiff);
      if (hgd != 0) return hgd;
      final hgf = bh.goalsFor.compareTo(ah.goalsFor);
      if (hgf != 0) return hgf;
      final gd = b.goalDiff.compareTo(a.goalDiff);
      if (gd != 0) return gd;
      return b.goalsFor.compareTo(a.goalsFor);
    });
    return sorted;
  }

  List<StandingRow> get sortedStandings {
    final rows = computeStandings().values.toList()
      ..sort((a, b) => b.points.compareTo(a.points));

    final result = <StandingRow>[];
    var i = 0;
    while (i < rows.length) {
      var j = i + 1;
      while (j < rows.length && rows[j].points == rows[i].points) {
        j++;
      }
      final group = rows.sublist(i, j);
      result.addAll(group.length == 1 ? group : _breakTies(group));
      i = j;
    }
    return result;
  }

  /// [includePlayers]をfalseにすると、所属チームの選手データを書き出さない。
  /// 他ディビジョンのリーグに使う(`SaveGame.otherDivisionLeagues`を参照)。
  Map<String, dynamic> toJson({bool includePlayers = true}) => {
        'teams': teams
            .map((t) => t.toJson(includePlayers: includePlayers))
            .toList(),
        'fixtures': fixtures.map((f) => f.toJson()).toList(),
        'season': season,
        if (pointsAdjustments.isNotEmpty) 'pointsAdjustments': pointsAdjustments,
        if (goalDiffFirst) 'goalDiffFirst': true,
      };

  factory League.fromJson(Map<String, dynamic> json) => League(
        teams: (json['teams'] as List)
            .map((e) => Team.fromJson(e as Map<String, dynamic>))
            .toList(),
        fixtures: (json['fixtures'] as List)
            .map((e) => Fixture.fromJson(e as Map<String, dynamic>))
            .toList(),
        season: json['season'] as int? ?? 1,
        pointsAdjustments: (json['pointsAdjustments'] as Map?)
            ?.map((k, v) => MapEntry(k as String, v as int)),
        goalDiffFirst: json['goalDiffFirst'] as bool? ?? false,
      );
}
