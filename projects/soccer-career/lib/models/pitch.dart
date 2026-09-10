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

enum PitchSpot {
  ownGoalLine('自ゴール前', 0.05, 0.50),
  ownBox('自陣PA内', 0.13, 0.50),
  ownEdge('自陣PAの外', 0.23, 0.50),
  ownThird('自陣', 0.28, 0.50),
  ownFlank('自陣サイド', 0.27, 0.16),
  middle('中盤', 0.50, 0.50),
  middleFlank('中盤サイド', 0.49, 0.17),
  betweenLines('ライン間', 0.63, 0.50),
  finalThird('敵陣', 0.72, 0.50),
  finalFlank('敵陣サイド', 0.74, 0.15),
  edgeOfBox('PA手前', 0.80, 0.50),
  penaltySpot('PKスポット', 0.88, 0.50),
  box('PA内', 0.89, 0.42),
  farPost('ファーサイド', 0.92, 0.72),
  opponentGoal('相手ゴール前', 0.95, 0.50),
  cornerFlag('コーナー付近', 0.97, 0.06);

  const PitchSpot(this.label, this.along, this.across);

  final String label;

  /// 自陣ゴール 0.0 〜 相手ゴール 1.0。
  final double along;

  /// 左タッチライン 0.0 〜 右タッチライン 1.0。
  final double across;

  /// 自陣側か。守る局面と攻める局面を、同じ物差しで分ける。
  bool get isOwnHalf => along < 0.5;
}
