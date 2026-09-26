import 'package:soccer_manager/monetization/funds_pack.dart';
import 'package:soccer_manager/monetization/purchase_service.dart';

/// ストアに触らない差し替え。画面の描画にストアの応答は要らないうえ、
/// 本物を使うと課金プラグインへ接続しにいき、テスト完了後に遅れて届く
/// 例外が無関係のテストを落とす。
class StubPurchaseService implements PurchaseService {
  /// 受け取り口。本物は待っているかどうかに関係なく呼ぶ。
  @override
  set onDelivered(Future<void> Function(String productId)? callback) =>
      onDeliveredCallback = callback;

  Future<void> Function(String productId)? onDeliveredCallback;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<String?> priceLabel() async => null;

  @override
  Future<PurchaseOutcome> buySupporter() async => PurchaseOutcome.unavailable;

  @override
  Future<String?> priceLabelFor(FundsPack pack) async => null;

  @override
  Future<PurchaseOutcome> buyFundsPack(FundsPack pack) async =>
      PurchaseOutcome.unavailable;

  @override
  Future<PurchaseOutcome> restorePurchases() async =>
      PurchaseOutcome.unavailable;

  @override
  void dispose() {}
}
