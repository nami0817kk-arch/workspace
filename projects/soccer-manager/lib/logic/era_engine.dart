import '../l10n/tr.dart';

/// 時代の変化。5季ごとに、サッカーの世界のお金の流れが変わる。
enum Era {
  /// 今の時代。
  present,

  /// 放映権の高騰: 放映権 +25%、移籍金 +10%。
  tvBoom,

  /// 移籍金の高騰: 放映権 +10%、移籍金 +25%。
  transferInflation,

  /// 引き締め: 放映権 -10%、移籍金 -5%。
  austerity,
}

extension EraInfo on Era {
  String get label => switch (this) {
        Era.present => Tr.pick('今の時代', 'The present day'),
        Era.tvBoom => Tr.pick('放映権の高騰', 'TV money boom'),
        Era.transferInflation => Tr.pick('移籍金の高騰', 'Transfer inflation'),
        Era.austerity => Tr.pick('引き締めの時代', 'Austerity'),
      };

  String get summary => switch (this) {
        Era.present =>
          Tr.pick('放映権も移籍金も今の水準。', 'TV money and fees as they are now.'),
        Era.tvBoom => Tr.pick('放映権が25%増え、移籍金が10%上がる。',
            'TV money up 25%, transfer fees up 10%.'),
        Era.transferInflation => Tr.pick('移籍金が25%上がり、放映権は10%増える。',
            'Transfer fees up 25%, TV money up 10%.'),
        Era.austerity => Tr.pick('放映権が10%減り、移籍金が5%下がる。',
            'TV money down 10%, transfer fees down 5%.'),
      };

  double get tvFactor => switch (this) {
        Era.present => 1.0,
        Era.tvBoom => 1.25,
        Era.transferInflation => 1.10,
        Era.austerity => 0.90,
      };

  double get transferFactor => switch (this) {
        Era.present => 1.0,
        Era.tvBoom => 1.10,
        Era.transferInflation => 1.25,
        Era.austerity => 0.95,
      };
}

class EraEngine {
  /// 1つの時代の長さ(季)。
  static const int length = 5;

  /// [season]季の時代。最初の5季は今の時代、その後は3つを順に回る。
  static Era eraOf(int season) {
    final i = (season - 1) ~/ length;
    if (i <= 0) return Era.present;
    return const [Era.tvBoom, Era.transferInflation, Era.austerity][(i - 1) % 3];
  }
}

/// 複数のクラブを持つ(オーナーの私財で、他国の1部のクラブを買う)。
class GroupClubEngine {
  /// 買う値段: 選手の価値の合計の6割。
  static int price(int squadValue) => (squadValue * 0.6).round();

  /// 売る値段: 選手の価値の合計の5割。
  static int salePrice(int squadValue) => (squadValue * 0.5).round();

  /// 1季の損益: 順位が上ほど儲かる(1位で値段の+8%、最下位で-6%)。
  static int seasonProfit(int price, double rankFactor) =>
      (price * (-0.06 + 0.14 * rankFactor)).round();
}
