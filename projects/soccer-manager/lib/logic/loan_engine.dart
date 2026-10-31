import '../l10n/tr.dart';

/// 融資の返済プラン。期間が長いほど利率(総支払額に占める利息の割合)は高くなるが、
/// 週あたりの返済額は抑えられる。
class LoanTerm {
  final int weeks;
  final double interestRatePercent;

  const LoanTerm({required this.weeks, required this.interestRatePercent});

  String get label =>
      weeks <= 12 ? Tr.pick('短期', 'Short term') : Tr.pick('長期', 'Long term');
}

class LoanEngine {
  static const List<LoanTerm> terms = [
    LoanTerm(weeks: 12, interestRatePercent: 8),
    LoanTerm(weeks: 26, interestRatePercent: 18),
  ];

  /// スタジアムのレベルと監督への世間の評価が高いほど、銀行からの信用が高く借入上限が上がる。
  /// 既存の融資残高はその分だけ借入余力から差し引かれる。
  static int maxBorrowable({
    required int stadiumLevel,
    required int reputation,
    required int outstandingDebt,
  }) {
    final capacity = 1500 + stadiumLevel * 500 + reputation * 15;
    return (capacity - outstandingDebt).clamp(0, capacity);
  }

  /// 週の返済額。切り上げで、最低1。
  ///
  /// 四捨五入していたため、小さな融資(例えば26週で10万円)では週の返済が
  /// 0に丸まり、借りたぶんをまるごと返さずに済んでいた。小数の誤差で
  /// 切り上げが1つ余計に乗らないよう、整数で割る。
  static int weeklyRepaymentFor(int principal, LoanTerm term) {
    if (principal <= 0) return 0;
    final totalHundredths =
        (principal * (100 + term.interestRatePercent)).round();
    final perWeekDivisor = 100 * term.weeks;
    final weekly = (totalHundredths + perWeekDivisor - 1) ~/ perWeekDivisor;
    return weekly < 1 ? 1 : weekly;
  }

  static int totalRepaymentFor(int principal, LoanTerm term) =>
      weeklyRepaymentFor(principal, term) * term.weeks;
}
