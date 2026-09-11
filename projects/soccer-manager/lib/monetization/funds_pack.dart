import '../l10n/tr.dart';
import 'reward_offer.dart';

/// 買い切りで資金を受け取る商品(消費型)。
///
/// リワード広告の特典を「資金」に絞ってあるのと同じ理由で、この商品も
/// 資金だけを渡す([RewardOffer] の説明を参照)。成長率や勝率に直接触る
/// 商品を作ると、実測で積み上げたバランス調整が意味を失う。資金なら
/// 「誰を買うか・施設に回すか」の判断はプレイヤーに残る。
///
/// リワード広告と違い、**1日の回数制限は無い**。広告の代わりに買うだけの
/// 商品にすると、サポーターとの違いが無くなって商品として成立しないため。
/// そのぶん「課金しても有利にならない」とは言えなくなるので、設定画面と
/// ストア掲載文はそのとおりに書き直してある。
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
