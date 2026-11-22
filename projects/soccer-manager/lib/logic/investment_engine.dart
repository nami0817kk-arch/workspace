import '../l10n/tr.dart';

/// 定期預金の預入プラン。期間が長いほど利回り(満期時に得られる利息の割合)は
/// 高くなるが、その間は資金を引き出せず身動きが取れなくなるリスクを伴う。
class DepositTerm {
  final int weeks;

  /// 満期までの利息の、元本に対する割合(%)。年利ではない。
  final double interestRatePercent;

  const DepositTerm({required this.weeks, required this.interestRatePercent});

  /// 年利(%)。期間の利息を1年(52週)あたりに直した値。画面にはこちらを出す。
  double get annualRatePercent => interestRatePercent * 52 / weeks;

  String get label =>
      weeks <= 12 ? Tr.pick('短期', 'Short term') : Tr.pick('長期', 'Long term');
}

class InvestmentEngine {
  /// 2026-11-22 に実際の利率へ寄せた。以前は12週で5%・26週で14%
  /// (年利に直すと20〜28%)で、預けるだけで融資より得になることもあった。
  /// いまは年利 約2.6%(12週)・約3.2%(26週)。
  static const List<DepositTerm> terms = [
    DepositTerm(weeks: 12, interestRatePercent: 0.6),
    DepositTerm(weeks: 26, interestRatePercent: 1.6),
  ];

  /// 満期時に受け取れる総額(元本+利息)。
  static int maturityValueFor(int principal, DepositTerm term) =>
      (principal * (1 + term.interestRatePercent / 100)).round();

  /// 満期時に得られる利息のみの額。
  static int interestFor(int principal, DepositTerm term) =>
      maturityValueFor(principal, term) - principal;
}
