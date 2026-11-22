/// 移籍の現実的な条件: 代理人手数料と、売却条項。純粋な計算だけ。
///
/// 現実のクラブは、選手を買うときに移籍金のほかに代理人への手数料を払い、
/// 値切って安く買った相手には「将来その選手を売るときの利益の一部」を
/// 渡す約束(売却条項)をすることがある。
class TransferTermsEngine {
  const TransferTermsEngine._();

  /// 代理人手数料の率(移籍金に対する%)。実際の手数料は1割前後
  /// (2026-11-22 に5%から上げた)。
  static const int agentFeePercent = 10;

  /// 買うときに別に払う代理人手数料(万円)。移籍金が0以下なら0。
  static int agentFee(int price) =>
      price <= 0 ? 0 : (price * agentFeePercent / 100).round();

  /// 所属なしの選手と契約するときの契約金(サイン料)の最低額(年俸に対する%)。
  ///
  /// 移籍金が要らない選手は、その分を契約金として求める。以前は所属なしの
  /// 選手を取る費用がゼロで、移籍で取るより極端に安かった(2026-11-22)。
  static const int freeAgentSigningPercent = 20;

  /// 所属なしの選手が求める契約金の最低額(万円)。[annualWage]は年俸。
  static int freeAgentSigningFee(int annualWage) => annualWage <= 0
      ? 0
      : (annualWage * freeAgentSigningPercent / 100).round();

  /// 所属なしの選手の代理人手数料(万円)。移籍金が無いので年俸に対する
  /// 割合で払う(1割前後。[percent]は代理人の個性で変わる)。
  static int freeAgentAgentFee(int annualWage,
          {int percent = agentFeePercent}) =>
      annualWage <= 0 ? 0 : (annualWage * percent / 100).round();

  /// 満額に近い額で買えば条項は付かない。大きく値切るほど、売り手は
  /// 将来の取り分を求める。[offer] が市場価値 [marketValue] のどのくらいか
  /// で決まる(%)。
  static int sellOnPercent({required int offer, required int marketValue}) {
    if (marketValue <= 0) return 0;
    final ratio = offer / marketValue;
    if (ratio >= 0.95) return 0;
    if (ratio >= 0.8) return 5;
    return 10;
  }

  /// 売却額 [salePrice] のうち、元のクラブへ払う額(万円)。
  static int sellOnPayment({required int salePrice, required int percent}) =>
      salePrice <= 0 || percent <= 0
          ? 0
          : (salePrice * percent / 100).round();
}
