/// 提携クラブ。他クラブと提携すると、毎季の提携費を払う代わりに、
/// 知名度が上がってサポーターと株主の期待が少し上がる。
///
/// 現実のクラブが、育成や海外展開のために結ぶ提携を、数字だけで表したもの。
/// 資金が提携費に届かない季は、提携は自然に解消される。
class PartnerClubEngine {
  const PartnerClubEngine._();

  /// 毎季の提携費(万円)。
  static const int seasonCost = 200;

  /// 提携の季末の効き(サポーター・株主)。
  static const int supportersBonus = 2;
  static const int shareholdersBonus = 2;

  /// 提携費を払えるか。
  static bool canAfford(int budget) => budget >= seasonCost;
}
