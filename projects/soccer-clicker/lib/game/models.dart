/// ゲームの状態と、その構成要素。
///
/// このファイルと [engine.dart] は Flutter に依存しない純 Dart。
/// UI を差し替えてもロジックが壊れないようにするためで、テストも
/// ここだけを対象にすれば足りる。
library;

/// 選手のポジション大分類。soccer-manager の14分類はここでは使わない
/// （育成クリッカーでは戦術を扱わないため、色分けと相性補正だけに使う）。
enum Position { gk, def, mid, att }

extension PositionLabel on Position {
  String get label => switch (this) {
        Position.gk => 'GK',
        Position.def => 'DEF',
        Position.mid => 'MID',
        Position.att => 'ATT',
      };
}

class Player {
  const Player({
    required this.id,
    required this.name,
    required this.position,
    required this.baseRating,
    this.level = 1,
  });

  final String id;
  final String name;
  final Position position;

  /// 獲得時に決まる素質。1〜60。
  final int baseRating;

  /// 育成でのみ上がる。1 から。
  final int level;

  /// 表示上の総合力。上限 99。
  int get rating {
    final value = baseRating + (level - 1) * 2;
    return value > 99 ? 99 : value;
  }

  Player copyWith({int? level}) => Player(
        id: id,
        name: name,
        position: position,
        baseRating: baseRating,
        level: level ?? this.level,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'position': position.name,
        'baseRating': baseRating,
        'level': level,
      };

  static Player fromJson(Map<String, dynamic> json) => Player(
        id: json['id'] as String,
        name: json['name'] as String,
        position: Position.values.byName(json['position'] as String),
        baseRating: (json['baseRating'] as num).toInt(),
        level: (json['level'] as num?)?.toInt() ?? 1,
      );
}

/// 買い切りではなく、買うたびに値上がりする強化。
enum UpgradeKind {
  /// タップ1回あたりの獲得EPを増やす。
  training,

  /// 放置中も EP が入るようにする（コーチ雇用）。
  coach,
}

class GameState {
  const GameState({
    required this.ep,
    required this.totalTaps,
    required this.players,
    required this.trainingLevel,
    required this.coachLevel,
    required this.clubRank,
    required this.wins,
    required this.losses,
    required this.updatedAtMs,
  });

  /// 育成ポイント。唯一の通貨。
  final double ep;
  final int totalTaps;
  final List<Player> players;

  /// 強化の購入回数。0 のとき未購入。
  final int trainingLevel;
  final int coachLevel;

  /// クラブランク。1 から上がり、対戦相手の強さに直結する。
  final int clubRank;
  final int wins;
  final int losses;

  /// 最後に状態を更新した時刻（epoch ミリ秒）。放置分の計算に使う。
  final int updatedAtMs;

  /// スカッド全体の総合力。選手がいなければ 0。
  int get squadRating {
    if (players.isEmpty) return 0;
    final total = players.fold<int>(0, (sum, p) => sum + p.rating);
    return (total / players.length).round();
  }

  GameState copyWith({
    double? ep,
    int? totalTaps,
    List<Player>? players,
    int? trainingLevel,
    int? coachLevel,
    int? clubRank,
    int? wins,
    int? losses,
    int? updatedAtMs,
  }) =>
      GameState(
        ep: ep ?? this.ep,
        totalTaps: totalTaps ?? this.totalTaps,
        players: players ?? this.players,
        trainingLevel: trainingLevel ?? this.trainingLevel,
        coachLevel: coachLevel ?? this.coachLevel,
        clubRank: clubRank ?? this.clubRank,
        wins: wins ?? this.wins,
        losses: losses ?? this.losses,
        updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      );

  Map<String, dynamic> toJson() => {
        'ep': ep,
        'totalTaps': totalTaps,
        'players': players.map((p) => p.toJson()).toList(),
        'trainingLevel': trainingLevel,
        'coachLevel': coachLevel,
        'clubRank': clubRank,
        'wins': wins,
        'losses': losses,
        'updatedAtMs': updatedAtMs,
      };

  static GameState fromJson(Map<String, dynamic> json) => GameState(
        ep: (json['ep'] as num).toDouble(),
        totalTaps: (json['totalTaps'] as num).toInt(),
        players: (json['players'] as List<dynamic>)
            .map((e) => Player.fromJson(e as Map<String, dynamic>))
            .toList(),
        trainingLevel: (json['trainingLevel'] as num).toInt(),
        coachLevel: (json['coachLevel'] as num).toInt(),
        clubRank: (json['clubRank'] as num).toInt(),
        wins: (json['wins'] as num).toInt(),
        losses: (json['losses'] as num).toInt(),
        updatedAtMs: (json['updatedAtMs'] as num).toInt(),
      );
}

/// 試合の結果。引き分けは扱わない（クリッカーの手応えを単純にするため）。
class MatchResult {
  const MatchResult({
    required this.won,
    required this.opponentRating,
    required this.reward,
    required this.rankedUp,
  });

  final bool won;
  final int opponentRating;
  final double reward;
  final bool rankedUp;
}
