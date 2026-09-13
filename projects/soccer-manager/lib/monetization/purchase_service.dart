import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'funds_pack.dart';

/// サポーター購入(買い切り・非消費型)の結果。
enum PurchaseOutcome {
  /// 購入が成立した、または過去の購入が復元された。
  purchased,

  /// 利用者が自分で取りやめた。エラー扱いにしない。
  canceled,

  /// ストアに繋がらない、商品が見つからないなど。
  unavailable,

  /// ストアから失敗が返った。
  failed,
}

/// サポーター購入の窓口。
///
/// 広告を任意視聴にしてある以上、「広告を消す」だけの購入では買っても
/// 何も変わらない。この購入は「広告を見ずに同じ特典を受け取れる」ものとして
/// 設計している (回数上限は RewardOffer を参照)。
abstract class PurchaseService {
  /// 商品IDはストア側の登録と一致させること。
  static const String supporterProductId = 'soccer_manager_supporter';

  /// 扱う商品のすべて。ストアからの通知はIDでしか届かないため、
  /// 知らないIDを取り違えないようここで突き合わせる。
  static Set<String> get allProductIds =>
      {supporterProductId, ...FundsPack.productIds};

  Future<void> initialize();

  /// ストアが使えるか。使えなければ購入ボタンを出さない。
  Future<bool> isAvailable();

  /// 表示用の価格 (「¥480」など)。取得できなければ null。
  Future<String?> priceLabel();

  /// 資金パックの表示用の価格。取得できなければ null。
  Future<String?> priceLabelFor(FundsPack pack);

  Future<PurchaseOutcome> buySupporter();

  /// 資金パックを買う。消費型なので何度でも買える。
  Future<PurchaseOutcome> buyFundsPack(FundsPack pack);

  /// 機種変更・再インストール後に購入済み状態を戻す。
  /// iOS は復元導線の提供が審査要件になっている。
  Future<PurchaseOutcome> restorePurchases();

  void dispose();
}

/// 課金を扱わない実装。Web版・テストで使う。
class NoOpPurchaseService implements PurchaseService {
  @override
  Future<void> initialize() async {}

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<String?> priceLabel() async => null;

  @override
  Future<String?> priceLabelFor(FundsPack pack) async => null;

  @override
  Future<PurchaseOutcome> buySupporter() async => PurchaseOutcome.unavailable;

  @override
  Future<PurchaseOutcome> buyFundsPack(FundsPack pack) async =>
      PurchaseOutcome.unavailable;

  @override
  Future<PurchaseOutcome> restorePurchases() async =>
      PurchaseOutcome.unavailable;

  @override
  void dispose() {}
}

/// ストアの課金基盤を使う実装。
class StorePurchaseService implements PurchaseService {
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  /// 購入・復元の完了を待つための受け皿。
  /// 課金の結果はストリームで非同期に返ってくるため、
  /// 呼び出し側が await できる形に変換している。
  Completer<PurchaseOutcome>? _pending;

  /// いま待っている商品ID。復元では複数の通知が流れてくるため null にする。
  String? _pendingProductId;

  /// 商品IDごとの明細。ストアへの問い合わせは1回で済ませる。
  final Map<String, ProductDetails> _products = {};
  bool _queried = false;

  @override
  Future<void> initialize() async {
    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (_) => _complete(PurchaseOutcome.failed),
    );
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      // 知らない商品IDは無視する。取り違えて別の特典を渡さないため。
      if (!PurchaseService.allProductIds.contains(purchase.productID)) continue;
      // 待っている商品と違うものが流れてきたら、完了通知だけ返して見送る。
      if (_pendingProductId != null &&
          purchase.productID != _pendingProductId) {
        if (purchase.pendingCompletePurchase) {
          unawaited(_iap.completePurchase(purchase));
        }
        continue;
      }

      switch (purchase.status) {
        case PurchaseStatus.pending:
          continue;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _complete(PurchaseOutcome.purchased);
        case PurchaseStatus.canceled:
          _complete(PurchaseOutcome.canceled);
        case PurchaseStatus.error:
          _complete(PurchaseOutcome.failed);
      }

      // 完了通知を返さないと、ストアが同じ購入を送り続ける。
      if (purchase.pendingCompletePurchase) {
        unawaited(_iap.completePurchase(purchase));
      }
    }
  }

  void _complete(PurchaseOutcome outcome) {
    final pending = _pending;
    if (pending == null || pending.isCompleted) return;
    _pending = null;
    _pendingProductId = null;
    pending.complete(outcome);
  }

  @override
  Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    try {
      return await _iap.isAvailable();
    } catch (_) {
      return false;
    }
  }

  Future<ProductDetails?> _loadProduct(String productId) async {
    final cached = _products[productId];
    if (cached != null) return cached;
    if (!_queried) {
      // 商品はまとめて問い合わせる。購入のたびに聞き直すと待たされる。
      final response =
          await _iap.queryProductDetails(PurchaseService.allProductIds);
      for (final p in response.productDetails) {
        _products[p.id] = p;
      }
      _queried = true;
    }
    return _products[productId];
  }

  @override
  Future<String?> priceLabel() async {
    try {
      return (await _loadProduct(PurchaseService.supporterProductId))?.price;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> priceLabelFor(FundsPack pack) async {
    try {
      return (await _loadProduct(pack.productId))?.price;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<PurchaseOutcome> buyFundsPack(FundsPack pack) async =>
      _buy(pack.productId, consumable: true);

  @override
  Future<PurchaseOutcome> buySupporter() async =>
      _buy(PurchaseService.supporterProductId, consumable: false);

  /// 消費型と非消費型で呼ぶ API が違うだけで、待ち方は同じ。
  Future<PurchaseOutcome> _buy(String productId,
      {required bool consumable}) async {
    try {
      final product = await _loadProduct(productId);
      if (product == null) return PurchaseOutcome.unavailable;

      final completer = Completer<PurchaseOutcome>();
      _pending = completer;
      _pendingProductId = productId;
      final param = PurchaseParam(productDetails: product);
      final started = consumable
          ? await _iap.buyConsumable(purchaseParam: param)
          : await _iap.buyNonConsumable(purchaseParam: param);
      if (!started) {
        _pending = null;
        _pendingProductId = null;
        return PurchaseOutcome.failed;
      }
      // ストアの画面から戻ってこない場合に永久に待たないよう上限を置く。
      return await completer.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () => PurchaseOutcome.canceled,
      );
    } catch (_) {
      _pending = null;
      _pendingProductId = null;
      return PurchaseOutcome.failed;
    }
  }

  @override
  Future<PurchaseOutcome> restorePurchases() async {
    try {
      final completer = Completer<PurchaseOutcome>();
      _pending = completer;
      // 復元で戻るのはサポーター(非消費型)だけ。ここを null にしておくと、
      // 残っていた資金パックの通知でサポーター扱いになりかねない。
      _pendingProductId = PurchaseService.supporterProductId;
      await _iap.restorePurchases();
      // 購入履歴が無い場合はストリームに何も流れてこないので、
      // 待ち続けずに「対象なし」で返す。
      return await completer.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () => PurchaseOutcome.unavailable,
      );
    } catch (_) {
      _pending = null;
      _pendingProductId = null;
      return PurchaseOutcome.failed;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}

PurchaseService createPurchaseService() =>
    kIsWeb ? NoOpPurchaseService() : StorePurchaseService();
