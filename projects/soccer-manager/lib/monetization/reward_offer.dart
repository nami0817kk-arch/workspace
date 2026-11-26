import '../logic/economy_scale.dart';

/// 資金パックの額の基準(特典1回分)。
///
/// もとは動画広告を1本見たときの特典の額だった。動画広告と資金パックは
/// 2026-11-26 にやめたが、前に買って受け取り損ねた資金パックを渡す額は
/// この基準から出す([FundsPack.fundsFor])ので残してある。
class RewardOffer {
  const RewardOffer._();

  /// 1回分の資金(万円)。所属ディビジョンに比例させる。
  /// tier は1(最上位)〜5(最下位)。
  ///
  /// 5部の額(250万円)を部の規模(moneyScale)で大きくする。
  static int fundsFor(int divisionTier) => scaleMoneyForTier(divisionTier, 250);
}
