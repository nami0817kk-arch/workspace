/// 移籍の現実的な条件: 代理人手数料と、売却条項。純粋な計算だけ。
///
/// 現実のクラブは、選手を買うときに移籍金のほかに代理人への手数料を払い、
/// 値切って安く買った相手には「将来その選手を売るときの利益の一部」を
/// 渡す約束(売却条項)をすることがある。
class TransferTermsEngine {
  const TransferTermsEngine._();

  /// 代理人手数料の率(移籍金に対する%)。
  static const int agentFeePercent = 5;

  /// 買うときに別に払う代理人手数料(万円)。移籍金が0以下なら0。
  static int agentFee(int price) =>
      price <= 0 ? 0 : (price * agentFeePercent / 100).round();

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
