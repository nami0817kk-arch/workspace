/// ユースリーグの1チーム分の成績。
///
/// 自クラブのユースは[isUser]が true の1行だけ。相手は近隣クラブの
/// ユースで、シーズンごとに強さがばらつく。
class YouthLeagueStanding {
  final String name;
  final bool isUser;

  /// 相手の強さ(総合力の目安)。自クラブの行では使わない。
  final int strength;

  int played;
  int won;
  int draw;
  int lost;
  int goalsFor;
  int goalsAgainst;

  YouthLeagueStanding({
    required this.name,
    required this.strength,
    this.isUser = false,
    this.played = 0,
    this.won = 0,
    this.draw = 0,
    this.lost = 0,
    this.goalsFor = 0,
    this.goalsAgainst = 0,
  });

  int get points => won * 3 + draw;
  int get goalDiff => goalsFor - goalsAgainst;

  void record(int scored, int conceded) {
    played++;
    goalsFor += scored;
    goalsAgainst += conceded;
    if (scored > conceded) {
      won++;
    } else if (scored == conceded) {
      draw++;
    } else {
      lost++;
    }
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'isUser': isUser,
        'strength': strength,
        'played': played,
        'won': won,
        'draw': draw,
        'lost': lost,
        'goalsFor': goalsFor,
        'goalsAgainst': goalsAgainst,
      };

  factory YouthLeagueStanding.fromJson(Map<String, dynamic> json) =>
      YouthLeagueStanding(
        name: json['name'] as String? ?? '?',
        isUser: json['isUser'] as bool? ?? false,
        strength: json['strength'] as int? ?? 50,
        played: json['played'] as int? ?? 0,
        won: json['won'] as int? ?? 0,
        draw: json['draw'] as int? ?? 0,
        lost: json['lost'] as int? ?? 0,
        goalsFor: json['goalsFor'] as int? ?? 0,
        goalsAgainst: json['goalsAgainst'] as int? ?? 0,
      );
}

/// ユースの年間リーグ。
///
/// 練習試合は毎週あったが、勝っても負けても何も残らなかった。順位が付いて
/// 初めて「今年のユースはどうだったか」が言える。全[matchdayCount]節まで
/// 進むとその年は終了し、以降の週は従来どおりの練習試合になる。
class YouthLeague {
  /// 参加数(自クラブ + 相手7)。2回戦総当たりで14節になる。
  static const int teamCount = 8;
  static const int matchdayCount = (teamCount - 1) * 2;

  final List<YouthLeagueStanding> standings;

  /// 次に戦う相手の並び(節ごと)。自クラブの対戦相手だけを持ち、
  /// 他チーム同士の結果はその節ごとに簡易に決める。
  final List<int> opponentOrder;

  int matchday;

  YouthLeague({
    required this.standings,
    required this.opponentOrder,
    this.matchday = 0,
  });

  bool get isComplete => matchday >= matchdayCount;

  YouthLeagueStanding get userStanding =>
      standings.firstWhere((s) => s.isUser);

  /// 順位順(勝点 → 得失点差 → 得点)。
  List<YouthLeagueStanding> get sorted {
    final list = [...standings];
    list.sort((a, b) {
      final p = b.points.compareTo(a.points);
      if (p != 0) return p;
      final d = b.goalDiff.compareTo(a.goalDiff);
      if (d != 0) return d;
      return b.goalsFor.compareTo(a.goalsFor);
    });
    return list;
  }

  int get userRank => sorted.indexWhere((s) => s.isUser) + 1;

  /// 今節の相手。全節終了後はnull。
  YouthLeagueStanding? get nextOpponent => isComplete
      ? null
      : standings[opponentOrder[matchday % opponentOrder.length]];

  Map<String, dynamic> toJson() => {
        'standings': standings.map((s) => s.toJson()).toList(),
        'opponentOrder': opponentOrder,
        'matchday': matchday,
      };

  factory YouthLeague.fromJson(Map<String, dynamic> json) => YouthLeague(
        standings: [
          for (final s in (json['standings'] as List? ?? []))
            YouthLeagueStanding.fromJson(s as Map<String, dynamic>),
        ],
        opponentOrder: [
          for (final v in (json['opponentOrder'] as List? ?? [])) v as int,
        ],
        matchday: json['matchday'] as int? ?? 0,
      );
}
