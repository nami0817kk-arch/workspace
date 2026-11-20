import '../l10n/tr.dart';

/// 持分(株式)の売り買いと配当。オーナーの持分は常に過半(51%)以上を保つ。
/// 外部の株主は、増資で入ってくる代わりに、利益から配当を持っていく。
class EquityEngine {
  const EquityEngine._();

  /// 1回に動かす持分(%)。
  static const int step = 10;

  /// オーナーが最低限保つ持分(%)。これを下回る売却はできない。
  static const int minOwnerShare = 51;

  /// 株式を売るときの価格。クラブ価値の割引(オーナーの買い手との交渉)。
  static int salePrice(int clubValue, int pct) =>
      (clubValue * pct / 100 * 0.9).round();

  /// 売った持分を買い戻す費用。プレミアが乗る。
  static int buybackCost(int clubValue, int pct) =>
      (clubValue * pct / 100 * 1.1).round();

  /// 売れる持分(%)。0なら売れない。
  static int sellable(int ownerShare) =>
      ownerShare - step >= minOwnerShare ? step : 0;

  /// 外部の株主への配当。黒字の半分を、外部の持分の割合で分ける。
  static int dividend({required int ownerShare, required int seasonProfit}) =>
      seasonProfit <= 0
          ? 0
          : (seasonProfit * (100 - ownerShare) / 100 * 0.5).round();

  /// 株主総会の空気(株主の期待から)。
  static String mood(int shareholderExpectation) {
    if (shareholderExpectation >= 70) {
      return Tr.pick('株主は経営を高く評価しています', 'Shareholders praise your management');
    }
    if (shareholderExpectation >= 40) {
      return Tr.pick('株主は様子を見ています', 'Shareholders are watching');
    }
    return Tr.pick('株主から厳しい声が出ています', 'Shareholders are voicing strong concern');
  }
}
