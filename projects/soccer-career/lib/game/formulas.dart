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

  /// GK 以外の選手の GK 能力。保存データに無いときの既定値でもある。
  static const int defaultGoalkeeping = 25;

  /// ポテンシャル（総合力の上限）の範囲。
  static const int potentialMin = 62;
  static const int potentialMax = 94;

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

  /// コンディション（0〜100）。
  static const int conditionMax = 100;

  /// 1試合で消耗するコンディション。
  static const int matchConditionCost = 12;

  /// 練習で消耗するコンディション。
  static const int trainingConditionCost = 10;

  /// 休養で回復するコンディション。
  static const int restRecovery = 30;

  /// コンディションが成功率に効く傾き。基準値からの差 × 傾き。
  /// 100 なら +6%、20 なら −6%。疲れたまま練習し続けると試合で払う。
  static const int conditionBaseline = 60;
  static const double conditionChanceSlope = 0.0015;

  /// 練習で能力が1伸びる確率（ポテンシャルに達していなければ）。
  static const double trainingGrowthChance = 0.3;

  /// 居残り練習で余分に減るコンディション。
  static const int drillConditionCost = 6;

  /// 居残り練習でセットプレーの精度が1上がる確率（上に行くほど鈍る）。
  static const double drillGrowthChance = 0.55;

  /// キッカーを任されている選手に、1試合でセットプレーの好機が回る確率。
  static const double deadBallChanceStart = 0.22;
  static const double deadBallChanceSub = 0.09;

  /// 上乗せ要求が通る確率 = 基本 + 交渉力 × 係数 + 成績の補正。
  static const double negotiationBase = 0.25;
  static const double negotiationPerSkill = 0.09;

  /// 上乗せの倍率。
  static const double negotiationRaise = 1.2;

  /// 上乗せに失敗したとき、オファーが撤回される確率。
  static const double withdrawChanceOnFail = 0.5;

  /// 1試合あたりの負傷確率の基準。コンディションと年齢で増減する。
  static const double injuryBaseChance = 0.045;

  /// 練習1回あたりの負傷確率。試合より低いが、疲れていると効いてくる。
  static const double injuryTrainingChance = 0.02;

  /// コンディションが基準を下回るほど怪我しやすくなる傾き。
  static const double injuryConditionSlope = 0.0009;

  /// この年齢を超えると、1歳ごとに怪我しやすくなる。
  static const int injuryAgeFrom = 29;
  static const double injuryPerAgeYear = 0.004;

  /// 重傷で落ちる能力値とポテンシャル。
  static const int severeInjuryAttributeLoss = 3;
  static const int severeInjuryPotentialLoss = 2;

  /// 復帰直後のコンディション。
  static const int conditionAfterInjury = 45;

  /// 代表に招集される最低総合力。
  static const int callUpOverall = 72;

  /// 代表に招集される最低の直近平均評価点。
  static const double callUpRating = 6.6;

  /// 代表戦の前に必要な出場試合数（実績が無いと選ばれない）。
  static const int callUpMinAppearances = 5;

  /// 契約年数の範囲。
  static const int contractYearsMin = 2;
  static const int contractYearsMax = 4;

  /// 登録メンバーに入るのに必要な、クラブの強さとの差。
  /// これより大きく劣ると25人枠に入れない。
  static const int squadRegistrationGap = -18;

  /// 大陸カップに出た年の年俸倍率。
  static const double continentalSalaryBonus = 1.1;

  /// 目標を達成したときの年俸倍率。達成できなかったときの倍率。
  static const double objectiveMetSalaryFactor = 1.15;
  static const double objectiveMissedSalaryFactor = 0.9;
}
