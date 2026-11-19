import 'economy_engine.dart';

/// 移籍市場の相場(100 が基準)。景気に連れて季ごとに動き、全体としては
/// 少しずつ上がる(実在の移籍金の上がり方)。買うときの言い値と、他の
/// クラブから来るオファーの額の両方に掛かる。リリース条項の額は契約で
/// 決まっているので動かない。
class MarketTrendEngine {
  static const int min = 70;
  static const int max = 180;

  /// 次の季の相場。[roll]は 0〜1 の乱数。
  static int next(int index, EconomyPhase phase, double roll) {
    final (lo, hi) = switch (phase) {
      EconomyPhase.boom => (6, 15),
      EconomyPhase.normal => (0, 8),
      EconomyPhase.slump => (-12, 0),
    };
    final change = lo + ((hi - lo) * roll).round();
    return (index * (100 + change) / 100).round().clamp(min, max);
  }

  /// 額に相場を掛ける。
  static int apply(int amount, int index) => (amount * index / 100).round();
}
