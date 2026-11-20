import 'match_result.dart';

/// 試合の片方のハーフで、ある時点までに確定した中身(得点・シュート・
/// イベントなど)。[LiveMatchProgress]の中で使う。
class HalfTally {
  final int homeGoals;
  final int awayGoals;
  final List<MatchEvent> events;
  final int homeShots;
  final int awayShots;
  final int homeShotsOnTarget;
  final int awayShotsOnTarget;
  final double possessionShareSum;
  final int chanceCount;

  const HalfTally({
    this.homeGoals = 0,
    this.awayGoals = 0,
    this.events = const [],
    this.homeShots = 0,
    this.awayShots = 0,
    this.homeShotsOnTarget = 0,
    this.awayShotsOnTarget = 0,
    this.possessionShareSum = 0,
    this.chanceCount = 0,
  });

  Map<String, dynamic> toJson() => {
        'homeGoals': homeGoals,
        'awayGoals': awayGoals,
        'events': events.map((e) => e.toJson()).toList(),
        'homeShots': homeShots,
        'awayShots': awayShots,
        'homeShotsOnTarget': homeShotsOnTarget,
        'awayShotsOnTarget': awayShotsOnTarget,
        'possessionShareSum': possessionShareSum,
        'chanceCount': chanceCount,
      };

  factory HalfTally.fromJson(Map<String, dynamic> json) => HalfTally(
        homeGoals: json['homeGoals'] as int? ?? 0,
        awayGoals: json['awayGoals'] as int? ?? 0,
        events: (json['events'] as List?)
                ?.map((e) => MatchEvent.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        homeShots: json['homeShots'] as int? ?? 0,
        awayShots: json['awayShots'] as int? ?? 0,
        homeShotsOnTarget: json['homeShotsOnTarget'] as int? ?? 0,
        awayShotsOnTarget: json['awayShotsOnTarget'] as int? ?? 0,
        possessionShareSum:
            (json['possessionShareSum'] as num?)?.toDouble() ?? 0,
        chanceCount: json['chanceCount'] as int? ?? 0,
      );
}

/// 進行中のリーグ戦(自クラブの試合)の途中経過。
///
/// 節の週の処理(収入・週給・負傷回復・ローン・分割払い・ユース)は試合の
/// 前半を始める時点で済ませて保存している。試合の途中でアプリが終わったとき、
/// これが無いと再起動後に同じ節を最初からやり直し、週の処理が二重にかかって
/// いた。前半で負けている試合を落として引き直すこともできた。
///
/// 再開するときは週の処理を飛ばし、ここに残した時点の続きから試合を進める。
class LiveMatchProgress {
  final int season;
  final int matchday;

  /// 次に進める分(この分から先はまだ決まっていない)。46なら前半は
  /// 終わっている。
  final int resumeMinute;

  /// 使った交代枠。再開で枠が戻らないようにする。
  final int substitutionsUsed;

  /// 前半。[secondHalf]が null の間は、[resumeMinute]までの途中経過。
  final HalfTally firstHalf;

  /// 後半の途中経過。前半が終わっていなければ null。
  final HalfTally? secondHalf;

  const LiveMatchProgress({
    required this.season,
    required this.matchday,
    required this.resumeMinute,
    required this.substitutionsUsed,
    required this.firstHalf,
    this.secondHalf,
  });

  Map<String, dynamic> toJson() => {
        'season': season,
        'matchday': matchday,
        'resumeMinute': resumeMinute,
        'substitutionsUsed': substitutionsUsed,
        'firstHalf': firstHalf.toJson(),
        'secondHalf': secondHalf?.toJson(),
      };

  factory LiveMatchProgress.fromJson(Map<String, dynamic> json) =>
      LiveMatchProgress(
        season: json['season'] as int,
        matchday: json['matchday'] as int,
        resumeMinute: json['resumeMinute'] as int? ?? 1,
        substitutionsUsed: json['substitutionsUsed'] as int? ?? 0,
        firstHalf: HalfTally.fromJson(
            (json['firstHalf'] as Map?)?.cast<String, dynamic>() ?? const {}),
        secondHalf: json['secondHalf'] == null
            ? null
            : HalfTally.fromJson(
                (json['secondHalf'] as Map).cast<String, dynamic>()),
      );
}
