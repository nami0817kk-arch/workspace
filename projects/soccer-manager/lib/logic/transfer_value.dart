import '../models/player.dart';

/// 移籍金の値付けの決まり(画面・状態から切り離した計算)。
///
/// 2026-11-23 に足した。それまで契約の残り年数は、買うときの言い値に
/// 「残り1年以内なら ×0.8」と軽く効くだけで、売るときは年数に関係なく
/// 市場価値の7割だった。実際の欧州の市場では、契約が残り半年の選手は
/// 移籍金がほとんど付かず(夏には自由契約で取れるので)、長い契約の選手は
/// 売る側が強気になる。売り買いの両方と、CPU の判断(売る・買う・断る)に
/// 同じ係数を掛ける。
class TransferValue {
  const TransferValue._();

  /// 残り年数と係数の目安(この間は直線でつなぐ)。
  /// 残り半年 0.2・1年 0.5・2年 0.8・3年 1.0・4年以上 1.1。
  static const List<(double, double)> _points = [
    (0.5, 0.2),
    (1.0, 0.5),
    (2.0, 0.8),
    (3.0, 1.0),
    (4.0, 1.1),
  ];

  /// 契約の残り[yearsLeft](年。半端も可)から、移籍金に掛ける係数。
  static double contractFactor(double yearsLeft) {
    if (yearsLeft <= _points.first.$1) return _points.first.$2;
    for (var i = 1; i < _points.length; i++) {
      final (x1, y1) = _points[i];
      if (yearsLeft <= x1) {
        final (x0, y0) = _points[i - 1];
        return y0 + (y1 - y0) * (yearsLeft - x0) / (x1 - x0);
      }
    }
    return _points.last.$2;
  }

  /// 契約の残り(年)。[contractYearsRemaining]は今のシーズンを含めた年数で、
  /// [seasonProgress]は今のシーズンがどこまで進んだか(0=開幕前、
  /// 1=全節を終えた)。冬の窓のころに残り1なら、残りは半年になる。
  static double yearsLeft(int contractYearsRemaining, double seasonProgress) {
    final y = contractYearsRemaining - seasonProgress.clamp(0.0, 1.0);
    return y < 0 ? 0 : y;
  }

  /// [p]の契約の係数。
  static double factorFor(Player p, double seasonProgress) =>
      contractFactor(yearsLeft(p.contractYearsRemaining, seasonProgress));

  /// 契約の残りを込みにした、移籍金の相場(万円)。売り出したときに
  /// 来るオファーの真ん中、買うときの言い値の土台。
  static int worth(Player p, double seasonProgress) =>
      (p.marketValue * factorFor(p, seasonProgress)).round();

  /// 移籍リストに載せた選手に、1週のうちに他のクラブから声がかかる確率。
  ///
  /// 人気のない選手(チームの中で力が下の方・年を取っている・怪我)には、
  /// 窓のあいだ一度も来ないこともある。[squadMedianOverall]は自クラブの
  /// 総合力の真ん中。
  static double listedInterestChance(Player p, int squadMedianOverall) {
    final rel = p.overall - squadMedianOverall;
    var chance = 0.30 + 0.025 * rel;
    final age = p.age;
    final ageFactor = age <= 23
        ? 1.2
        : age <= 29
            ? 1.0
            : age <= 31
                ? 0.75
                : age <= 33
                    ? 0.45
                    : 0.2;
    chance *= ageFactor;
    if (p.isInjured) chance *= 0.3;
    return chance.clamp(0.0, 0.7);
  }

  /// 売り出した選手へのオファーの額のばらつき(相場に掛ける)。
  /// 売りたいのが分かっているので、相場より下から始まる(相場を超えない。
  /// 市場価値と代理人手数料で買った選手を、すぐ売って儲けることはできない)。
  static double listedOfferSpread(double roll) => 0.75 + roll * 0.23;

  /// 売りに出していない選手へのオファーのばらつき。
  /// 引き抜きなので、相場より上を出してくることが多い。
  static double unsolicitedOfferSpread(double roll) => 0.9 + roll * 0.4;
}
