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

  /// 利益率(損益/営業収入)がこれ以上なら、株主は満足する(加点)。
  static const double goodMargin = 0.15;

  /// 利益率がこれ未満なら、黒字でも物足りない(減点)。
  static const double thinMargin = 0.05;

  /// 利益率が良いときの加点・薄いときの減点・赤字のときの減点。
  static const int goodMarginBonus = 4;
  static const int thinMarginPenalty = 3;
  static const int lossMarginPenalty = 5;

  /// 人件費率が目安を超えたときの減点(注意・危険)。
  static const double wageWarn = 0.70;
  static const double wageDanger = 0.85;
  static const int wageWarnPenalty = 2;
  static const int wageDangerPenalty = 4;

  /// シーズン終了時の収支評価による、株主の期待の増減量。
  ///
  /// 資金が0以上かどうかの基本の評価に、そのシーズンの利益率と人件費率を
  /// 足す。放置で資金が増え続けても、稼ぎが薄い・人件費が重いと上がらない。
  /// [profit] と [operatingIncome] を渡さないときは基本の評価だけ(旧来の挙動)。
  static int deltaForSeasonEnd({
    required int budget,
    int? profit,
    int? operatingIncome,
    double wageRatio = 0,
  }) {
    var delta = budget >= 0 ? blackSeasonBonus : -redSeasonPenalty;
    if (profit != null && operatingIncome != null && operatingIncome > 0) {
      final margin = profit / operatingIncome;
      if (margin >= goodMargin) {
        delta += goodMarginBonus;
      } else if (margin < 0) {
        delta -= lossMarginPenalty;
      } else if (margin < thinMargin) {
        delta -= thinMarginPenalty;
      }
    }
    if (wageRatio > wageDanger) {
      delta -= wageDangerPenalty;
    } else if (wageRatio > wageWarn) {
      delta -= wageWarnPenalty;
    }
    return delta;
  }

  /// 季末の収支の評価[financial]に、順位と目標の差による増減[results]
  /// (サポーター側の季末の増減。-10〜+15)を[resultsShare]だけ混ぜる。
  static int mixedWithResults({required int financial, required int results}) =>
      (financial * (1 - resultsShare) + results * resultsShare).round();

  /// 季末の株主の期待の増減のうち、順位と目標の差が占める割合。
  static const double resultsShare = 0.3;

  /// 増減を適用した値(0〜100に収める)。
  static int applied(int current, int delta) =>
      (current + delta).clamp(0, 100);
}
