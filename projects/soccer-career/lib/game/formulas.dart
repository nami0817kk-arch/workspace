/// ゲームの数値定義を1か所に集めたもの。
///
/// バランス調整はここだけを触る。各所に散らすと、1つ変えたときに
/// 何が連動して壊れるのかが追えなくなる。
class Formulas {
  const Formulas._();

  /// 1シーズンの試合数（20クラブの2回戦総当たり）。
  static const int matchesPerSeason = 38;

  /// リーグのクラブ数。
  static const int clubsPerLeague = 20;

  /// 1試合で提示する局面の数。全38試合に介入する設計なので、
  /// 1試合を短く保たないとシーズンが終わらない。
  static const int scenariosPerStart = 3;

  /// 途中出場のときの局面数。出場時間が短い分だけ見せ場も減る。
  static const int scenariosPerSub = 2;

  /// 評価点の基準値と上下限。サッカー専門誌の採点に合わせて 4.0〜10.0。
  static const double baseRating = 6.0;
  static const double minRating = 4.0;
  static const double maxRating = 10.0;

  /// 局面の成否が評価点に与える増減。
  static const double ratingPerSuccess = 0.4;
  static const double ratingPerFailure = -0.35;
  static const double ratingPerGoal = 1.1;
  static const double ratingPerAssist = 0.7;

  /// 能力値の下限・上限。
  static const int minAttribute = 1;
  static const int maxAttribute = 99;

  /// 成長判定のしきい値。この評価点を超えた試合だけ伸びる可能性がある。
  static const double growthRatingThreshold = 6.5;

  /// 成長のピーク年齢。これを過ぎると伸びにくくなり、衰え始める。
  static const int peakAge = 27;
  static const int declineAge = 31;

  /// 出場評価。直近の平均評価点がこれ未満だと先発から外れる。
  static const double benchThreshold = 6.2;

  /// これ未満だと招集外（ベンチにも入れない）。
  static const double squadThreshold = 5.6;

  /// 直近何試合の評価点で出場可否を判断するか。
  static const int formWindow = 5;

  /// 勝点。
  static const int pointsWin = 3;
  static const int pointsDraw = 1;

  /// 移籍オファーが届く最低シーズン平均評価点。
  static const double transferOfferRating = 6.8;

  /// 選手の総合力と評価点から、移籍先クラブの強さの上限を決める係数。
  static const double transferReachFactor = 1.08;

  /// 2部でこの順位以内なら昇格。
  static const int promotionPlaces = 2;

  /// 1部でこの順位以下なら降格（20クラブ中）。
  static const int relegationFrom = 18;

  /// 昇格・降格したクラブの強さの補正。同じクラブでも上のリーグでは相対的に弱い。
  static const int promotionStrengthBonus = 6;

  /// この年齢からシーズン終了時に引退を選べる。
  static const int retirementOptionalAge = 33;

  /// この年齢でシーズンを終えたら引退する。
  static const int retirementForcedAge = 37;

  /// 成長判定で、その試合に成功した手の能力が選ばれる確率。
  /// 残りは無作為。プレースタイルが選手を形作るが、偏りすぎない。
  static const double growthFocusChance = 0.7;
}
