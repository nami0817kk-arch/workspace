/// 局面が起きている場所。
///
/// 「ライン間で前を向いて受けた。中央は密集、外は空いている」——
/// 文章にはピッチのどこかが書いてあるのに、画面には文字しか無かった。
/// 同じことを絵にすると、読まなくても分かる。
///
/// 座標は正規化して持つ。[along] は**自陣ゴール 0.0 〜 相手ゴール 1.0**、
/// [across] は**左タッチライン 0.0 〜 右タッチライン 1.0**。
/// ピッチを横向きに描き、いつも右へ攻める。GKの局面でも向きは変えない
/// （向きが局面ごとに変わると、どちらへ攻めているのか分からなくなる）。
library;

// 名前（`_label` ほか）は private だが、**`this._label` には書けない**
// ——Dart は名前付き引数を `_` で始められない。外に見せるのは `String` の
// getter なので、持ち物は private のまま置く。
// ignore_for_file: prefer_initializing_formals

import '../l10n/lang.dart';

enum PitchSpot {
  ownGoalLine(Say('自ゴール前', 'Own goalmouth'), 0.05, 0.50),
  ownBox(Say('自陣PA内', 'Own box'), 0.13, 0.50),
  ownEdge(Say('自陣PAの外', 'Edge of own box'), 0.23, 0.50),
  ownThird(Say('自陣', 'Own half'), 0.28, 0.50),
  ownFlank(Say('自陣サイド', 'Own flank'), 0.27, 0.16),
  middle(Say('中盤', 'Midfield'), 0.50, 0.50),
  middleFlank(Say('中盤サイド', 'Midfield flank'), 0.49, 0.17),
  betweenLines(Say('ライン間', 'Between the lines'), 0.63, 0.50),
  finalThird(Say('敵陣', 'Final third'), 0.72, 0.50),
  finalFlank(Say('敵陣サイド', 'Final third flank'), 0.74, 0.15),
  edgeOfBox(Say('PA手前', 'Edge of the box'), 0.80, 0.50),
  penaltySpot(Say('PKスポット', 'Penalty spot'), 0.88, 0.50),
  box(Say('PA内', 'In the box'), 0.89, 0.42),
  farPost(Say('ファーサイド', 'Far post'), 0.92, 0.72),
  opponentGoal(Say('相手ゴール前', 'Their goalmouth'), 0.95, 0.50),
  cornerFlag(Say('コーナー付近', 'By the corner flag'), 0.97, 0.06);

  const PitchSpot(Say label, this.along, this.across) : _label = label;

  /// **名前は日本語と英語の2つを持つ**（[Say]）。enum の引数は定数なので
  /// `tr()` を直に書けない。外には `String` のまま見せる。
  final Say _label;

  String get label => _label.t;

  /// 自陣ゴール 0.0 〜 相手ゴール 1.0。
  final double along;

  /// 左タッチライン 0.0 〜 右タッチライン 1.0。
  final double across;

  /// 自陣側か。守る局面と攻める局面を、同じ物差しで分ける。
  bool get isOwnHalf => along < 0.5;
}
