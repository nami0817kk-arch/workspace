// 名前（`_label` ほか）は private だが、**`this._label` には書けない**
// ——Dart は名前付き引数を `_` で始められない。外に見せるのは `String` の
// getter なので、持ち物は private のまま置く。
// ignore_for_file: prefer_initializing_formals

/// カップ戦。実際に戦うためのもの。
///
/// これまでカップ戦は**シーズンの終わりに結果だけが決まる**ものだった。
/// 到達ラウンドは年俸にも評判にも記録にも効くのに、プレイヤーは1分も
/// プレーしない。「優勝した」と書かれるだけで、そこに試合が無い。
///
/// リーグ戦と違うのは一発勝負であること。負けたらそこで終わる。
/// 前に入れた「取り返しのつかなさ」と、同じ手触りのものにする。
library;

import '../l10n/lang.dart';
import 'competition.dart';

/// どの大会か。
enum CupKind {
  domestic(Say('国内カップ', 'Domestic cup')),
  continental(Say('大陸カップ', 'Continental cup'));

  const CupKind(Say label) : _label = label;

  final Say _label;

  String get label => _label.t;
}

/// カップ戦のラウンド。
///
/// 国内カップは1回戦から。大陸カップはグループステージから。
enum CupRound {
  group(Say('グループステージ', 'Group stage')),
  round32(Say('1回戦', 'First round')),
  round16(Say('16強', 'Round of 16')),
  quarter(Say('準々決勝', 'Quarter-final')),
  semi(Say('準決勝', 'Semi-final')),
  finalRound(Say('決勝', 'Final'));

  const CupRound(Say label) : _label = label;

  final Say _label;

  String get label => _label.t;

  /// 2戦合計で決めるラウンドか。**大陸カップの決勝トーナメントだけ。**
  ///
  /// 決勝だけは中立地の一発勝負。現実のとおり。
  ///
  /// **大会の種類を見ないと、国内カップが終わらなくなる。** 以前は
  /// ラウンドだけで決めていたので、国内カップも 16強・準々・準決勝が
  /// 2戦合計になり、決勝まで 8試合が要った。日程は
  /// `Cups.domesticMatches`（5試合）しか取ってないので、**勝ち続けた
  /// シーズンは準決勝で日程が尽き**、季末に `runDomesticCup` が
  /// 結果を振り直していた——5連勝した選手に「1回戦敗退」と告げていた
  /// （実測113シーズンで、準決勝まで勝ち上がった35回のうち18回）。
  bool twoLeggedIn(CupKind kind) =>
      kind == CupKind.continental &&
      (this == CupRound.round16 ||
          this == CupRound.quarter ||
          this == CupRound.semi);

  /// 中立地で行うか。
  bool get neutral => this == CupRound.finalRound;

  /// 国内カップの進み方。
  static const List<CupRound> domesticPath = [
    CupRound.round32,
    CupRound.round16,
    CupRound.quarter,
    CupRound.semi,
    CupRound.finalRound,
  ];

  /// 大陸カップの進み方。
  static const List<CupRound> continentalPath = [
    CupRound.group,
    CupRound.round16,
    CupRound.quarter,
    CupRound.semi,
    CupRound.finalRound,
  ];
}

/// これから戦う1試合。
///
/// 週に1試合という刻みは変えない。カップ戦は**リーグ戦の合間の週**に入る。
class CupTie {
  const CupTie({
    required this.kind,
    required this.round,
    required this.opponentName,
    required this.opponentStrength,
    required this.home,
    this.leg = 1,
    this.aggregateFor = 0,
    this.aggregateAgainst = 0,
    this.groupMatch = 0,
  });

  final CupKind kind;
  final CupRound round;
  final String opponentName;
  final int opponentStrength;
  final bool home;

  /// 2戦合計のうち何戦目か。一発勝負なら 1。
  final int leg;

  /// 第1戦までの合計得点。
  final int aggregateFor;
  final int aggregateAgainst;

  /// グループステージの何試合目か（1〜6）。それ以外は 0。
  final int groupMatch;

  /// この一戦が2戦合計の一部か。**国内カップは常に一発勝負。**
  bool get twoLegged => round.twoLeggedIn(kind);

  /// 画面に出す一言。「大陸カップ 準々決勝 第2戦」。
  String get label {
    if (round == CupRound.group) {
      return tr('${kind.label} ${round.label} 第$groupMatch節', '${kind.label} ${round.label} matchday $groupMatch');
    }
    if (twoLegged) return tr('${kind.label} ${round.label} 第$leg戦', '${kind.label} ${round.label} leg $leg');
    return '${kind.label} ${round.label}';
  }

  /// 2戦目で、第1戦の結果を背負っているか。
  bool get carriesAggregate => leg == 2;

  /// 第1戦を終えての差。
  int get aggregateMargin => aggregateFor - aggregateAgainst;

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'round': round.name,
        'opponentName': opponentName,
        'opponentStrength': opponentStrength,
        'home': home,
        'leg': leg,
        'aggregateFor': aggregateFor,
        'aggregateAgainst': aggregateAgainst,
        'groupMatch': groupMatch,
      };

  static CupTie? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    return CupTie(
      kind: CupKind.values.any((k) => k.name == json['kind'])
          ? CupKind.values.byName(json['kind'] as String)
          : CupKind.domestic,
      round: CupRound.values.any((r) => r.name == json['round'])
          ? CupRound.values.byName(json['round'] as String)
          : CupRound.round32,
      opponentName: json['opponentName'] as String? ?? tr('相手', 'Opponent'),
      opponentStrength: json['opponentStrength'] as int? ?? 60,
      home: json['home'] as bool? ?? true,
      leg: json['leg'] as int? ?? 1,
      aggregateFor: json['aggregateFor'] as int? ?? 0,
      aggregateAgainst: json['aggregateAgainst'] as int? ?? 0,
      groupMatch: json['groupMatch'] as int? ?? 0,
    );
  }
}

/// そのシーズンの、ある大会での戦い。
///
/// 到達ラウンドは**戦った結果として決まる**。シーズン末に振り直さない。
class CupRun {
  CupRun({
    required this.kind,
    required this.round,
    this.groupPlayed = 0,
    this.groupPoints = 0,
    this.groupGoalDifference = 0,
    this.eliminated = false,
    this.won = false,
    this.next,
  });

  final CupKind kind;

  /// 今いるラウンド。
  CupRound round;

  /// グループステージの消化数と勝ち点。
  int groupPlayed;
  int groupPoints;
  int groupGoalDifference;

  /// 敗退したか。優勝したか。
  bool eliminated;
  bool won;

  /// 次に戦う予定。2戦目は第1戦の合計を背負うので、ここで持ち越す。
  /// null なら、次の日程が来たときに新しく抽選する。
  CupTie? next;

  bool get running => !eliminated && !won;

  /// グループを突破する勝ち点。6試合で2位以内に入る目安。
  ///
  /// 順位表を丸ごと持たずに、勝ち点で線を引く。3チームぶんの
  /// 架空の順位表を回しても、画面に出せる情報は増えない。
  static const int groupQualifyPoints = 8;

  bool get groupFinished => groupPlayed >= 6;
  bool get groupQualified => groupPoints >= groupQualifyPoints;

  /// 国内カップの到達ラウンドを、記録の形にする。
  CupStage get domesticStage {
    if (won) return CupStage.winner;
    if (!eliminated) return CupStage.none;
    return switch (round) {
      CupRound.round32 => CupStage.early,
      CupRound.round16 => CupStage.round16,
      CupRound.quarter => CupStage.quarter,
      CupRound.semi => CupStage.semi,
      CupRound.finalRound => CupStage.runnerUp,
      CupRound.group => CupStage.early,
    };
  }

  /// 大陸カップの到達ラウンドを、記録の形にする。
  ContinentalStage get continentalStage {
    if (won) return ContinentalStage.winner;
    if (!eliminated) return ContinentalStage.none;
    return switch (round) {
      CupRound.group => ContinentalStage.group,
      CupRound.round32 => ContinentalStage.group,
      CupRound.round16 => ContinentalStage.round16,
      CupRound.quarter => ContinentalStage.quarter,
      CupRound.semi => ContinentalStage.semi,
      CupRound.finalRound => ContinentalStage.runnerUp,
    };
  }

  /// 画面に出す一言。
  String get label {
    if (won) return tr('${kind.label} 優勝', '${kind.label} winners');
    if (eliminated) {
      return round == CupRound.finalRound
          ? tr('${kind.label} 準優勝', '${kind.label} runners-up')
          : tr('${kind.label} ${round.label}敗退', '${kind.label}, out in the ${round.label}');
    }
    if (round == CupRound.group) {
      return tr('${kind.label} グループ $groupPlayed/6試合・勝点$groupPoints', '${kind.label} group $groupPlayed/6 played, $groupPoints points');
    }
    return '${kind.label} ${round.label}';
  }

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'round': round.name,
        'groupPlayed': groupPlayed,
        'groupPoints': groupPoints,
        'groupGoalDifference': groupGoalDifference,
        'eliminated': eliminated,
        'won': won,
        'next': next?.toJson(),
      };

  static CupRun? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    return CupRun(
      kind: CupKind.values.any((k) => k.name == json['kind'])
          ? CupKind.values.byName(json['kind'] as String)
          : CupKind.domestic,
      round: CupRound.values.any((r) => r.name == json['round'])
          ? CupRound.values.byName(json['round'] as String)
          : CupRound.round32,
      groupPlayed: json['groupPlayed'] as int? ?? 0,
      groupPoints: json['groupPoints'] as int? ?? 0,
      groupGoalDifference: json['groupGoalDifference'] as int? ?? 0,
      eliminated: json['eliminated'] as bool? ?? false,
      won: json['won'] as bool? ?? false,
      next: CupTie.fromJson(json['next'] as Map<String, dynamic>?),
    );
  }
}
