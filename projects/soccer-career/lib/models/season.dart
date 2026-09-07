/// 出場の仕方。評価点が低いと先発から外れ、さらに落ちると招集外になる。
enum Appearance {
  start('先発'),
  sub('途中出場'),
  benched('ベンチ外');

  const Appearance(this.label);

  final String label;
}

/// 1試合の結果。
class MatchResult {
  const MatchResult({
    required this.matchday,
    required this.opponentName,
    required this.home,
    required this.scored,
    required this.conceded,
    required this.appearance,
    required this.rating,
    required this.goals,
    required this.assists,
  });

  final int matchday;
  final String opponentName;
  final bool home;
  final int scored;
  final int conceded;
  final Appearance appearance;

  /// 出場しなかった試合は null。平均評価点の計算から外すため。
  final double? rating;
  final int goals;
  final int assists;

  bool get won => scored > conceded;
  bool get drawn => scored == conceded;
  String get scoreLine => '$scored - $conceded';

  Map<String, dynamic> toJson() => {
        'matchday': matchday,
        'opponentName': opponentName,
        'home': home,
        'scored': scored,
        'conceded': conceded,
        'appearance': appearance.name,
        'rating': rating,
        'goals': goals,
        'assists': assists,
      };

  factory MatchResult.fromJson(Map<String, dynamic> json) => MatchResult(
        matchday: json['matchday'] as int,
        opponentName: json['opponentName'] as String,
        home: json['home'] as bool,
        scored: json['scored'] as int,
        conceded: json['conceded'] as int,
        appearance: Appearance.values.byName(json['appearance'] as String),
        rating: (json['rating'] as num?)?.toDouble(),
        goals: json['goals'] as int,
        assists: json['assists'] as int,
      );
}

/// 1シーズンぶんの個人成績。
class SeasonStats {
  const SeasonStats({
    required this.appearances,
    required this.goals,
    required this.assists,
    required this.averageRating,
  });

  final int appearances;
  final int goals;
  final int assists;
  final double averageRating;

  static SeasonStats from(List<MatchResult> results) {
    final played = results.where((r) => r.rating != null).toList();
    if (played.isEmpty) {
      return const SeasonStats(
          appearances: 0, goals: 0, assists: 0, averageRating: 0);
    }
    final total = played.fold<double>(0, (sum, r) => sum + r.rating!);
    return SeasonStats(
      appearances: played.length,
      goals: played.fold(0, (sum, r) => sum + r.goals),
      assists: played.fold(0, (sum, r) => sum + r.assists),
      averageRating: total / played.length,
    );
  }
}
