import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/monetization/ad_service.dart';
import 'package:soccer_manager/monetization/funds_delivery.dart';
import 'package:soccer_manager/monetization/funds_pack.dart';
import 'package:soccer_manager/monetization/monetization_controller.dart';
import 'package:soccer_manager/monetization/purchase_service.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 「払ったのに届かない」道が残っていないかの検査。
///
/// ストアの通知は、購入を始めた瞬間に返ってくるとは限らない。アプリを
/// 落としている間に決済が通る／家族の承認が後から下りる／こちらが待つのを
/// やめた後に届く／別の端末で買ったぶんが起動時に流れてくる。結果を
/// await している側だけに渡していた頃、これらは全部「払ったのに何も
/// 起きない」だった。しかも完了通知だけは返していたので、ストアは二度と
/// 送ってこない。資金パックは消費型で「復元」でも戻らないため、払った額が
/// そのまま消える。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<(MonetizationController, _SilentPurchaseService)> build() async {
    final purchases = _SilentPurchaseService();
    final controller = MonetizationController(
      adService: _NoAdService(),
      purchases: purchases,
    );
    await controller.initialize();
    return (controller, purchases);
  }

  test('待っている人が居なくても、届いたサポーターは受け取る', () async {
    final (money, store) = await build();
    expect(money.isSupporter, isFalse);

    // 誰も buySupporter() を待っていない状態で通知だけが届く。
    await store.deliver(PurchaseService.supporterProductId);

    expect(money.isSupporter, isTrue, reason: '払ったのに特典が付いていない');
  });

  test('受け取ったサポーターは再起動後も残る', () async {
    final (_, store) = await build();
    await store.deliver(PurchaseService.supporterProductId);

    final restarted = MonetizationController(
      adService: _NoAdService(),
      purchases: _SilentPurchaseService(),
    );
    await restarted.initialize();

    expect(restarted.isSupporter, isTrue);
  });

  test('届いた資金パックは預かりに入り、再起動後も残る', () async {
    // 資金はセーブの中に入るので、その場では渡せないことがある。
    // 預かりが消えると、消費型なので払った額がそのまま消える。
    final (money, store) = await build();
    await store.deliver(FundsPack.medium.productId);

    expect(money.undeliveredFundsPacks, [FundsPack.medium]);

    final restarted = MonetizationController(
      adService: _NoAdService(),
      purchases: _SilentPurchaseService(),
    );
    await restarted.initialize();
    expect(restarted.undeliveredFundsPacks, [FundsPack.medium],
        reason: '預かっていたぶんが起動で消えている');
  });

  test('預かったぶんは、セーブが開いたときにクラブ資金へ移る', () async {
    final (money, store) = await build();
    final game = GameState();
    await game.startNewGame('受け取りFC');
    final before = game.save!.budget;

    await store.deliver(FundsPack.small.productId);
    final granted = await deliverPendingFunds(money, game);

    expect(granted, game.purchasedFundsAmount(FundsPack.small));
    expect(game.save!.budget, before + granted);
    expect(money.undeliveredFundsPacks, isEmpty);
  });

  test('二度渡らない', () async {
    final (money, store) = await build();
    final game = GameState();
    await game.startNewGame('二重FC');
    final before = game.save!.budget;

    await store.deliver(FundsPack.small.productId);
    final first = await deliverPendingFunds(money, game);
    final second = await deliverPendingFunds(money, game);

    expect(second, 0, reason: '同じ購入を二度渡している');
    expect(game.save!.budget, before + first);
  });

  test('同じパックを2つ買えば、2つとも渡る', () async {
    // 消費型なので何度でも買える。1つにまとめてしまうと片方が消える。
    final (money, store) = await build();
    final game = GameState();
    await game.startNewGame('連続FC');
    final before = game.save!.budget;

    await store.deliver(FundsPack.small.productId);
    await store.deliver(FundsPack.small.productId);
    expect(money.undeliveredFundsPacks.length, 2);

    final granted = await deliverPendingFunds(money, game);
    expect(granted, game.purchasedFundsAmount(FundsPack.small) * 2);
    expect(game.save!.budget, before + granted);
  });

  test('セーブが無いあいだは預かったままで、消えない', () async {
    final (money, store) = await build();
    final empty = GameState();
    await empty.init(); // セーブを作らずに起動しただけ

    await store.deliver(FundsPack.large.productId);
    final granted = await deliverPendingFunds(money, empty);

    expect(granted, 0);
    expect(money.undeliveredFundsPacks, [FundsPack.large],
        reason: 'セーブが無いあいだに預かりを捨てている');
  });

  test('知らない商品IDは預からない', () async {
    final (money, store) = await build();
    await store.deliver('not_a_real_product');

    expect(money.undeliveredFundsPacks, isEmpty);
    expect(money.isSupporter, isFalse);
  });
}

/// 買う操作では何も返さず、ストアからの通知だけを起こせる差し替え。
///
/// 「待っている人が居ないときに届く」状況を作るためのもの。買う側の
/// 戻り値に頼っていると、この形は再現できない。
class _SilentPurchaseService implements PurchaseService {
  @override
  set onDelivered(Future<void> Function(String productId)? callback) =>
      _onDelivered = callback;

  Future<void> Function(String productId)? _onDelivered;

  /// ストアから通知が届いた状態にする。
  Future<void> deliver(String productId) async =>
      _onDelivered?.call(productId);

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<String?> priceLabel() async => null;

  @override
  Future<String?> priceLabelFor(FundsPack pack) async => null;

  @override
  Future<PurchaseOutcome> buySupporter() async => PurchaseOutcome.failed;

  @override
  Future<PurchaseOutcome> buyFundsPack(FundsPack pack) async =>
      PurchaseOutcome.failed;

  @override
  Future<PurchaseOutcome> restorePurchases() async => PurchaseOutcome.failed;

  @override
  void dispose() {}
}

class _NoAdService implements AdService {
  @override
  Future<void> initialize() async {}

  @override
  bool get isRewardedAdReady => false;

  @override
  Future<bool> showRewardedAd() async => false;

  @override
  bool get isInterstitialAdReady => false;

  @override
  Future<void> showInterstitialAd() async {}

  @override
  void dispose() {}
}
