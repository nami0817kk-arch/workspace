import '../l10n/tr.dart';

/// 融資の返済プラン。期間が長いほど利率(総支払額に占める利息の割合)は高くなるが、
/// 週あたりの返済額は抑えられる。
class LoanTerm {
  final int weeks;

  /// 期間全体でかかる利息の、元本に対する割合(%)。年利ではない。
  final double interestRatePercent;

  const LoanTerm({required this.weeks, required this.interestRatePercent});

  /// 年利(%)。期間の利息を1年(52週)あたりに直した値。画面にはこちらを出す。
  double get annualRatePercent => interestRatePercent * 52 / weeks;

  String get label =>
      weeks <= 12 ? Tr.pick('短期', 'Short term') : Tr.pick('長期', 'Long term');
}

class LoanEngine {
  /// 2026-11-22 に実際の利率へ寄せた。以前は12週で8%・26週で18%
  /// (年利に直すと35%前後)で、実際のクラブの借入(年5〜8%)の5倍だった。
  /// いまは年利 約6.5%(12週)・約7%(26週)。
  static const List<LoanTerm> terms = [
    LoanTerm(weeks: 12, interestRatePercent: 1.5),
    LoanTerm(weeks: 26, interestRatePercent: 3.5),
  ];

  /// 返済の[weekIndex]週目(0から)に返す元本の額。週の返済額から
  /// これを引いた残りが利息。全週を足すと、元本ちょうどになる。
  static int principalPartOfWeek(int principal, int termWeeks, int weekIndex) {
    if (termWeeks <= 0) return principal;
    final i = weekIndex.clamp(0, termWeeks - 1);
    return principal * (i + 1) ~/ termWeeks - principal * i ~/ termWeeks;
  }

  /// スタジアムのレベルと監督への世間の評価が高いほど、銀行からの信用が高く借入上限が上がる。
  /// 既存の融資残高はその分だけ借入余力から差し引かれる。
  ///
  /// [scale] はクラブの規模(部ごとの moneyScale)。上の部ほど大きく借りられる。
  static int maxBorrowable({
    required int stadiumLevel,
    required int reputation,
    required int outstandingDebt,
    double scale = 1,
  }) {
    final capacity =
        ((1500 + stadiumLevel * 500 + reputation * 15) * scale).round();
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
