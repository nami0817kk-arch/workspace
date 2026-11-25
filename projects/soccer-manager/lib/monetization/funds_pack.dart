import '../l10n/tr.dart';
import 'reward_offer.dart';

/// 資金を受け取る商品(消費型)。**もう売っていない。**
///
/// 1.2.0 で売るのをやめた(買うボタンを外し、2026-11-26 に方針として確定)。
/// お金で赤字を消せると、サポーターと株主の2つの期待の引っ張り合いが
/// 壊れるため。ストアの商品は 1.2.0 の公開と同時に販売をやめる。
///
/// 前に買って、まだクラブ資金に移していないぶんがストアから届くことが
/// あるので、受け取って渡す仕組み(funds_delivery.dart)のために残してある。
enum FundsPack {
  /// 特典およそ5回分。
  small(
    productId: 'soccer_manager_funds_small',
    rewardEquivalent: 5,
  ),

  /// 特典およそ20回分。
  medium(
    productId: 'soccer_manager_funds_medium',
    rewardEquivalent: 20,
  ),

  /// 特典およそ60回分。
  large(
    productId: 'soccer_manager_funds_large',
    rewardEquivalent: 60,
  );

  const FundsPack({
    required this.productId,
    required this.rewardEquivalent,
  });

  /// ストア側の商品IDと一致させること。1文字違うと購入が動かない。
  final String productId;

  /// リワード広告の特典が何回分に当たるか。額はここから導く。
  final int rewardEquivalent;

  /// 受け取れる資金(万円)。所属ディビジョンに比例させる。
  ///
  /// 固定額にすると、5部では経営判断が消し飛び、1部では誤差になる。
  /// 特典1回分と同じ比例のさせ方に揃えてある。
  int fundsFor(int divisionTier) =>
      RewardOffer.fundsFor(divisionTier) * rewardEquivalent;

  String get label => switch (this) {
        FundsPack.small => Tr.pick('資金パック(小)', 'Funds pack (small)'),
        FundsPack.medium => Tr.pick('資金パック(中)', 'Funds pack (medium)'),
        FundsPack.large => Tr.pick('資金パック(大)', 'Funds pack (large)'),
      };

  /// 商品IDから引く。ストアからの通知はIDでしか届かない。
  static FundsPack? byProductId(String productId) {
    for (final pack in FundsPack.values) {
      if (pack.productId == productId) return pack;
    }
    return null;
  }

  static Set<String> get productIds =>
      {for (final pack in FundsPack.values) pack.productId};
}
