/// 試合を自動で進めるときの選び方。
enum SimStyle {
  safe('安全', '成功率が最も高い手を選ぶ'),
  balanced('バランス', '評価点の期待値が最も高い手を選ぶ'),
  aggressive('勝負', '得点に繋がる手の中で最も良い手を選ぶ');

  const SimStyle(this.label, this.description);

  final String label;
  final String description;
}

/// 出場の仕方。評価点が低いと先発から外れ、さらに落ちると招集外になる。
enum Appearance {
  start('先発'),
  sub('途中出場'),
  benched('ベンチ外'),
  injured('負傷離脱'),
  suspended('出場停止');

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
    this.yellowCards = 0,
    this.sentOff = false,
    this.goalMinutes = const [],
    this.assistMinutes = const [],
    this.international = false,
    this.followedTactic = 0,
    this.againstTactic = 0,
    this.assistAttempts = 0,
  });

  /// 代表戦なら true。リーグ戦とは別に数える。
  final bool international;

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

  /// その試合で受けた警告の数（0〜2）。
  final int yellowCards;

  /// 退場したか。2枚目の警告でも、一発でも同じ。
  final bool sentOff;

  /// 自分が決めた時間とアシストした時間。
  ///
  /// 「78分に決めて追いついた」が残ると、38試合が数字の羅列でなくなる。
  /// セットプレーぶんは時間が分からないので入っていない（数だけ goals に乗る）。
  final List<int> goalMinutes;
  final List<int> assistMinutes;

  /// 監督の求める形に沿った手・逆らった手の数。
  ///
  /// 試合で選んだことが監督に届くのは、ここを通ってだけ。
  final int followedTactic;
  final int againstTactic;

  /// 味方を活かす手を選んだ回数。相方との呼吸がここから伸びる。
  final int assistAttempts;

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
        if (yellowCards > 0) 'yellowCards': yellowCards,
        if (sentOff) 'sentOff': true,
        if (goalMinutes.isNotEmpty) 'goalMinutes': goalMinutes,
        if (assistMinutes.isNotEmpty) 'assistMinutes': assistMinutes,
        'international': international,
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
        yellowCards: json['yellowCards'] as int? ?? 0,
        sentOff: json['sentOff'] as bool? ?? false,
        goalMinutes:
            (json['goalMinutes'] as List? ?? const []).cast<int>().toList(),
        assistMinutes:
            (json['assistMinutes'] as List? ?? const []).cast<int>().toList(),
        international: json['international'] as bool? ?? false,
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
