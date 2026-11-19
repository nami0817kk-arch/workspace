/// 年間シート。開幕前に、入場券の一部を割り引いて季の分まとめて売る。
/// 売った分は成績が落ちても減らないが、勝って客が増えても増えない。
class SeasonTicketEngine {
  /// 選べる割合(%)。0 は売らない。
  static const List<int> shares = [0, 30, 50, 70];

  /// 年間シートの割引(1試合あたりの値段の何割で売るか)。
  static const double priceRate = 0.85;

  /// 季の分の売上: 今の1節あたりの入場収入 × 節の数 × 割合 × 割引。
  static int upfront({
    required int weeklyGate,
    required int matchdays,
    required int sharePercent,
  }) =>
      (weeklyGate * matchdays * sharePercent / 100 * priceRate).round();

  /// 年間シートを売った季の、節ごとの入場収入(売った割合を除いた残り)。
  static int remainingGate(int gate, int sharePercent) =>
      (gate * (100 - sharePercent) / 100).round();
}
