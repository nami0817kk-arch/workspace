/// 収支の見通しと健全度の判定。画面に出す数字を作るだけの純粋な関数。
class LedgerEngine {
  const LedgerEngine._();

  /// 人件費率の目安。これを超えると「注意」、[wageRatioDanger] を超えると「危険」。
  static const double wageRatioWarn = 0.70;
  static const double wageRatioDanger = 0.85;

  /// 今の収支のまま続けたとき、資金が尽きるまでの節数。
  /// 毎節の収支が黒字か均衡なら null(尽きない)。すでに資金が負なら 0。
  static int? runwayWeeks({required int budget, required int weeklyNet}) {
    if (weeklyNet >= 0) return null;
    if (budget <= 0) return 0;
    return (budget / -weeklyNet).floor();
  }

  /// 人件費率の段階。0=健全、1=注意、2=危険。
  static int wageRatioLevel(double ratio) {
    if (ratio > wageRatioDanger) return 2;
    if (ratio > wageRatioWarn) return 1;
    return 0;
  }

  /// 1節あたりの収支(収入 − 人件費 − 分割払い − 融資返済)。
  static int weeklyNet({
    required int income,
    required int wageBill,
    required int installments,
    required int loanRepayment,
  }) =>
      income - wageBill - installments - loanRepayment;
}
