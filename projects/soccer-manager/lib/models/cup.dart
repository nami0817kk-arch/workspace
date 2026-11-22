import '../models/match_result.dart';
import 'enum_json.dart';
import '../l10n/tr.dart';

/// カップ戦の不在(不戦勝)を表す仮想チームID。
const String byeTeamId = '__BYE__';

enum CupType {
  domestic,
  continental,

  /// 2つ目の国内カップ(リーグカップ)。イングランドだけにある(実在の
  /// リーグカップに寄せる。1〜3部のクラブが出る。2026-11-22)。
  leagueCup,

  /// 4クラブのスーパーカップ(スペイン・イタリア。1月に準決勝と決勝)。
  superCup,
}

extension CupTypeInfo on CupType {
  String get label => switch (this) {
        CupType.domestic => Tr.pick('国内カップ', 'Domestic Cup'),
        CupType.continental => Tr.pick('大陸カップ', 'Continental Cup'),
        CupType.leagueCup => Tr.pick('リーグカップ', 'League Cup'),
        CupType.superCup => Tr.pick('スーパーカップ', 'Super Cup'),
      };
}

class CupMatch {
  final int round;
  final String homeTeamId;
  final String awayTeamId;
  MatchResult? result;

  /// PK戦で決着した場合の勝者チームID(引き分け時のみ使用)。
  String? penaltyWinnerId;

  /// 延長戦(30分)まで戦ったか。[result]の得点は延長の分を含む。
  bool extraTime;

  /// 2試合合計で決める組か(スペイン・イタリアの国内カップと、イングランドの
  /// リーグカップの準決勝。2026-11-23)。第1戦は[awayTeamId]のホームで
  /// [firstLeg]に、第2戦は[homeTeamId]のホームで[result]に入る。延長・PK戦は
  /// 第2戦の後に合計で並んだときだけ(アウェイゴールは数えない)。
  final bool twoLegged;

  /// 2試合制の第1戦の結果([awayTeamId]のホーム)。まだなら null。
  MatchResult? firstLeg;

  CupMatch({
    required this.round,
    required this.homeTeamId,
    required this.awayTeamId,
    this.result,
    this.penaltyWinnerId,
    this.extraTime = false,
    this.twoLegged = false,
    this.firstLeg,
  });

  bool get isBye => homeTeamId == byeTeamId || awayTeamId == byeTeamId;

  /// 2試合制で、まだ第1戦をしていないか。
  bool get awaitingFirstLeg => twoLegged && firstLeg == null && result == null;

  /// 次に行う試合のホームのクラブ(2試合制の第1戦は[awayTeamId])。
  String get nextHomeId => awaitingFirstLeg ? awayTeamId : homeTeamId;

  /// 次に行う試合のアウェイのクラブ。
  String get nextAwayId => awaitingFirstLeg ? homeTeamId : awayTeamId;

  /// [teamId]の得点の合計(2試合制は2試合の合計。1試合制はその試合)。
  int goalsFor(String teamId) {
    var g = 0;
    for (final r in [if (twoLegged) firstLeg, result]) {
      if (r == null) continue;
      if (r.homeTeamId == teamId) g += r.homeGoals;
      if (r.awayTeamId == teamId) g += r.awayGoals;
    }
    return g;
  }

  /// 最後の試合を[last]で終えたとき、合計(1試合制はその試合)で並ぶか。
  bool levelAfter(MatchResult last) {
    int of(String id, MatchResult? r) => r == null
        ? 0
        : (r.homeTeamId == id
            ? r.homeGoals
            : (r.awayTeamId == id ? r.awayGoals : 0));
    final prior = twoLegged ? firstLeg : null;
    return of(homeTeamId, prior) + of(homeTeamId, last) ==
        of(awayTeamId, prior) + of(awayTeamId, last);
  }

  String? get winnerId {
    if (result == null) return null;
    if (twoLegged) {
      final h = goalsFor(homeTeamId);
      final a = goalsFor(awayTeamId);
      if (h > a) return homeTeamId;
      if (h < a) return awayTeamId;
      return penaltyWinnerId;
    }
    if (result!.homeGoals > result!.awayGoals) return homeTeamId;
    if (result!.homeGoals < result!.awayGoals) return awayTeamId;
    return penaltyWinnerId;
  }

  Map<String, dynamic> toJson() => {
        'round': round,
        'homeTeamId': homeTeamId,
        'awayTeamId': awayTeamId,
        'result': result?.toJson(),
        'penaltyWinnerId': penaltyWinnerId,
        if (extraTime) 'extraTime': true,
        if (twoLegged) 'twoLegged': true,
        if (firstLeg != null) 'firstLeg': firstLeg!.toJson(),
      };

  factory CupMatch.fromJson(Map<String, dynamic> json) => CupMatch(
        round: json['round'] as int,
        homeTeamId: json['homeTeamId'] as String,
        awayTeamId: json['awayTeamId'] as String,
        result: json['result'] == null
            ? null
            : MatchResult.fromJson(json['result'] as Map<String, dynamic>),
        penaltyWinnerId: json['penaltyWinnerId'] as String?,
        extraTime: json['extraTime'] as bool? ?? false,
        twoLegged: json['twoLegged'] as bool? ?? false,
        firstLeg: json['firstLeg'] == null
            ? null
            : MatchResult.fromJson(json['firstLeg'] as Map<String, dynamic>),
      );
}

class Cup {
  final CupType type;
  final String name;
  final List<List<CupMatch>> rounds;

  /// 優勝報酬(賞金・信頼度)を既に付与済みかどうか。二重付与を防ぐためのフラグ。
  bool rewardClaimed;

  /// 直近の試合を消化した時点でのリーグの節数(未消化ならnull)。
  /// 現実の試合間隔を再現するため、次の試合はリーグがこの節から
  /// 1節以上進むまで消化できないようにする。
  int? lastPlayedAtMatchday;

  /// 後の回戦から入るクラブ(回戦 → クラブID)。上の部ほど後から入る
  /// (実在の国内カップの形。2026-11-22)。不戦勝で次へ進むクラブもここに
  /// 足す。古い形(全クラブが1回戦から)のカップでは空。
  final Map<int, List<String>> entrants;

  /// 出場クラブの部(クラブID → 1〜3)。部の違うクラブが当たると下の部の
  /// クラブがホームになる。古い形のカップでは空。
  final Map<String, int> tiers;

  /// 決勝までの回戦の数(作るときに決まる)。古い形のカップでは null
  /// (1回戦の試合数から求める)。
  final int? plannedRounds;

  /// 各回戦を消化できるようになるリーグの節(回戦 r は [r - 1] 番目)。
  /// 回戦はまとめて同じ週に行い、決勝は5月。古い形のカップでは null
  /// (1節に1試合ずつ)。
  final List<int>? roundDue;

  /// この回戦から後は中立の会場(ホームの利が無く、入場収入は折半)。
  /// 決勝は中立(古いセーブで null のときも決勝は中立)。FA カップは準決勝から
  /// (ウェンブリー)。スーパーカップは全試合が中立。
  final int? neutralFromRound;

  /// 2試合合計で決める回戦(スペイン・イタリアの国内カップと、イングランドの
  /// リーグカップの準決勝)。古いセーブでは空(1試合で決める)。
  final List<int> twoLeggedRounds;

  /// 2試合制の第2戦を、第1戦の何節あとに行うか。
  static const int secondLegGap = 2;

  Cup({
    required this.type,
    required this.name,
    required this.rounds,
    this.rewardClaimed = false,
    this.lastPlayedAtMatchday,
    Map<int, List<String>>? entrants,
    Map<String, int>? tiers,
    this.plannedRounds,
    this.roundDue,
    this.neutralFromRound,
    List<int>? twoLeggedRounds,
  })  : entrants = entrants ?? {},
        tiers = tiers ?? {},
        twoLeggedRounds = twoLeggedRounds ?? const [];

  /// [m]が中立の会場の試合か(ホームの利を消し、入場収入は折半)。
  bool isNeutral(CupMatch m) =>
      type == CupType.superCup || m.round >= (neutralFromRound ?? totalRounds);

  /// [m]の次の試合を消化できるようになる節(2試合制の第2戦は第1戦の
  /// [secondLegGap]節あと)。決まっていなければ null。
  int? dueMatchdayForMatch(CupMatch m) {
    final base = dueMatchdayFor(m.round);
    if (base == null) return null;
    return m.twoLegged && m.firstLeg != null ? base + secondLegGap : base;
  }

  /// 決勝までの回戦の数。
  int get totalRounds {
    if (plannedRounds != null) return plannedRounds!;
    final first = rounds.isEmpty ? 0 : rounds.first.length;
    var n = 0;
    for (var size = first * 2; size > 1; size ~/= 2) {
      n++;
    }
    return n;
  }

  /// 回戦 [round] を消化できるようになる節(決まっていなければ null)。
  int? dueMatchdayFor(int round) {
    final due = roundDue;
    if (due == null || due.isEmpty) return null;
    return due[(round - 1).clamp(0, due.length - 1)];
  }

  bool get isComplete =>
      rounds.isNotEmpty &&
      rounds.last.length == 1 &&
      rounds.last.first.winnerId != null &&
      (plannedRounds == null || rounds.length >= plannedRounds!);

  String? get championId => isComplete ? rounds.last.first.winnerId : null;

  int get currentRoundNumber => rounds.isEmpty ? 1 : rounds.last.first.round;

  CupMatch? get nextUnplayedMatch {
    for (final round in rounds) {
      for (final m in round) {
        if (m.result == null) return m;
      }
    }
    return null;
  }

  bool involvesTeam(String teamId) =>
      rounds.any(
        (round) =>
            round.any((m) => m.homeTeamId == teamId || m.awayTeamId == teamId),
      ) ||
      entrants.values.any((ids) => ids.contains(teamId));

  /// このカップにおけるチームの最終成績(敗退ラウンド、または優勝)。まだ参加/敗退していなければnull。
  bool isEliminated(String teamId) {
    for (final round in rounds) {
      for (final m in round) {
        if ((m.homeTeamId == teamId || m.awayTeamId == teamId) &&
            m.winnerId != null &&
            m.winnerId != teamId) {
          return true;
        }
      }
    }
    return false;
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'name': name,
        'rounds': rounds.map((r) => r.map((m) => m.toJson()).toList()).toList(),
        'rewardClaimed': rewardClaimed,
        'lastPlayedAtMatchday': lastPlayedAtMatchday,
        if (entrants.isNotEmpty)
          'entrants': {
            for (final e in entrants.entries) '${e.key}': e.value,
          },
        if (tiers.isNotEmpty) 'tiers': tiers,
        if (plannedRounds != null) 'plannedRounds': plannedRounds,
        if (roundDue != null) 'roundDue': roundDue,
        if (neutralFromRound != null) 'neutralFromRound': neutralFromRound,
        if (twoLeggedRounds.isNotEmpty) 'twoLeggedRounds': twoLeggedRounds,
      };

  factory Cup.fromJson(Map<String, dynamic> json) => Cup(
        type: enumFromName(
          CupType.values,
          json['type'] as String?,
          CupType.domestic,
        ),
        name: json['name'] as String,
        rounds: (json['rounds'] as List)
            .map(
              (r) => (r as List)
                  .map((m) => CupMatch.fromJson(m as Map<String, dynamic>))
                  .toList(),
            )
            .toList(),
        rewardClaimed: json['rewardClaimed'] as bool? ?? false,
        lastPlayedAtMatchday: json['lastPlayedAtMatchday'] as int?,
        entrants: (json['entrants'] as Map?)?.map(
          (k, v) => MapEntry(
            int.parse(k as String),
            (v as List).map((e) => e as String).toList(),
          ),
        ),
        tiers: (json['tiers'] as Map?)
            ?.map((k, v) => MapEntry(k as String, v as int)),
        plannedRounds: json['plannedRounds'] as int?,
        roundDue: (json['roundDue'] as List?)?.map((e) => e as int).toList(),
        neutralFromRound: json['neutralFromRound'] as int?,
        twoLeggedRounds:
            (json['twoLeggedRounds'] as List?)?.map((e) => e as int).toList(),
      );
}
