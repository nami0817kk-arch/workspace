/// 株主の期待(オーナー型の2つ目のメーター)の増減。
///
/// サポーター側の期待は、既存の信頼度([SaveGame.confidence])が成績・順位に
/// 由来する形のまま受け持つ。こちらは収支に由来するものだけを扱う。
/// 週ごとの「資金マイナスが続く」減点は [BoardEngine.negativeBudgetConfidenceDelta]
/// の値をそのまま使い、シーズン終了時の収支評価をここで足す。
///
/// 数値は初期値。オーナー型の予算配分が入ったあと、自動で何年も回す
/// シミュレーションで測り直す。
class ShareholderEngine {
  const ShareholderEngine._();

  /// 黒字(資金が0以上)でシーズンを終えたときの加点。
  static const int blackSeasonBonus = 8;

  /// 赤字(資金がマイナス)でシーズンを終えたときの減点。
  static const int redSeasonPenalty = 12;

  /// シーズン終了時の収支評価による、株主の期待の増減量。
  static int deltaForSeasonEnd({required int budget}) =>
      budget >= 0 ? blackSeasonBonus : -redSeasonPenalty;

  /// 増減を適用した値(0〜100に収める)。
  static int applied(int current, int delta) =>
      (current + delta).clamp(0, 100);
}
