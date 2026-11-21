// 名前（`_label` ほか）は private だが、**`this._label` には書けない**
// ——Dart は名前付き引数を `_` で始められない。外に見せるのは `String` の
// getter なので、持ち物は private のまま置く。
// ignore_for_file: prefer_initializing_formals

import '../l10n/lang.dart';
import 'attributes.dart';
import 'cup.dart';

/// 試合を自動で進めるときの選び方。
enum SimStyle {
  safe(Say('安全', 'Safe'), Say('成功率が最も高い手を選ぶ', 'Takes the move with the best chance')),
  balanced(Say('バランス', 'Balanced'), Say('評価点の期待値が最も高い手を選ぶ', 'Takes the move with the best expected rating')),
  aggressive(Say('勝負', 'Attacking'), Say('得点に繋がる手の中で最も良い手を選ぶ', 'Takes the best of the moves that lead to goals'));

  const SimStyle(Say label, Say description)
    : _label = label,
      _description = description;

  /// **名前と説明は日本語と英語の2つを持つ**（[Say]）。
  final Say _label;
  final Say _description;

  String get label => _label.t;
  String get description => _description.t;
}

/// 出場の仕方。評価点が低いと先発から外れ、さらに落ちると招集外になる。
enum Appearance {
  start(Say('先発', 'Started')),
  sub(Say('途中出場', 'Off the bench')),
  benched(Say('ベンチ外', 'Not in the squad')),
  injured(Say('負傷離脱', 'Out injured')),
  suspended(Say('出場停止', 'Suspended'));

  const Appearance(Say label) : _label = label;

  final Say _label;

  String get label => _label.t;

  /// 実際にピッチに立ったか。
  bool get played => this == Appearance.start || this == Appearance.sub;
}

/// 1試合の結果。
class MatchResult {
  const MatchResult({
    required this.matchday,
    required this.opponentName,
    this.opponentId = '',
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
    this.cup,
    this.followedTactic = 0,
    this.againstTactic = 0,
    this.assistAttempts = 0,
  });

  /// 代表戦なら true。リーグ戦とは別に数える。
  final bool international;

  /// カップ戦なら、その大会。リーグ戦なら null。
  ///
  /// 順位表にも平均評価にも入れない。目標も約束もリーグ戦で数える
  /// （カップの試合数はクラブの勝ち上がりで変わるので、
  /// そこに目標を乗せると年ごとに難しさが変わってしまう）。
  final CupKind? cup;

  /// リーグ戦か。順位表と成績に入るのはこれだけ。
  bool get isLeague => !international && cup == null;

  final int matchday;
  final String opponentName;

  /// 相手クラブのID。**エンブレムの色と形はIDから決まる**
  /// （`ClubIdentity.of`）ので、名前だけでは絵が出せない。
  /// 古い保存データには無いので空文字。そのときは絵を出さない
  /// （知らないIDで別の色を描くと、同じクラブが2つの顔を持つ）。
  final String opponentId;
  final bool home;
  final int scored;
  final int conceded;
  final Appearance appearance;

  /// 出場しなかった試合は null。平均評価点の計算から外すため。
  final double? rating;
  final int goals;
  final int assists;

  /// **その試合を動かした数**（第2の通貨）。
  ///
  /// 平均評価だけがすべての入口だったので、平均は変動を嫌う＝
  /// **安全な手が常に正しい**形になっていた。実測で、中身の違う3つの
  /// 遊び方（最善・安全・勝負）がほぼ同じ結果になり、中盤の選手は
  /// 20年で9ゴールしか取らなかった。
  ///
  /// 守る選手にとっての無失点は、点を取る選手にとってのゴールと同じ仕事
  /// （評価点のほうでは既にそう扱っている）。ポジションで数え方を変える。
  int decisiveFor(Position position) {
    if (!appearance.played) return 0;
    final defends =
        position.family == ScenarioFamily.goalkeeper ||
        position.family == ScenarioFamily.defence;
    return goals + assists + (defends && conceded == 0 ? 1 : 0);
  }

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
    'opponentId': opponentId,
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
    'cup': cup?.name,
  };

  factory MatchResult.fromJson(Map<String, dynamic> json) => MatchResult(
    matchday: json['matchday'] as int,
    opponentName: json['opponentName'] as String,
    opponentId: json['opponentId'] as String? ?? '',
    home: json['home'] as bool,
    scored: json['scored'] as int,
    conceded: json['conceded'] as int,
    appearance: Appearance.values.byName(json['appearance'] as String),
    rating: (json['rating'] as num?)?.toDouble(),
    goals: json['goals'] as int,
    assists: json['assists'] as int,
    yellowCards: json['yellowCards'] as int? ?? 0,
    sentOff: json['sentOff'] as bool? ?? false,
    goalMinutes: (json['goalMinutes'] as List? ?? const [])
        .cast<int>()
        .toList(),
    assistMinutes: (json['assistMinutes'] as List? ?? const [])
        .cast<int>()
        .toList(),
    international: json['international'] as bool? ?? false,
    cup: CupKind.values.any((k) => k.name == json['cup'])
        ? CupKind.values.byName(json['cup'] as String)
        : null,
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
        appearances: 0,
        goals: 0,
        assists: 0,
        averageRating: 0,
      );
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
