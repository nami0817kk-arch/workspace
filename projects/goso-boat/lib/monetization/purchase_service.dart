import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// 購入の結果。
enum PurchaseOutcome {
  /// 購入が成立した、または過去の購入が復元された。
  purchased,

  /// 利用者が自分で取りやめた。エラー扱いにしない。
  canceled,

  /// ストアに繋がらない、商品が見つからない、復元する購入が無い。
  unavailable,

  /// ストアから失敗が返った。
  failed,
}

/// 「広告を消す」（買い切り・非消費型、370円。ユーザー決定 2026-09-27）の窓口。
/// soccer-manager の purchase_service.dart を1商品に絞ったもの。
abstract class PurchaseService {
  /// App Store Connect の商品IDと一致させること。
  static const removeAdsId = 'goso_boat_remove_ads';

  /// **届いたら、待っているかどうかに関係なく呼ぶ。** ストアの通知は購入を始めた
  /// 瞬間に返るとは限らない（家族の承認・別の端末での購入・起動時の再送）。
  set onDelivered(Future<void> Function(String productId)? callback);

  Future<void> initialize();
  Future<bool> isAvailable();

  /// 表示用の価格（「¥370」など）。取れなければ null。
  Future<String?> priceLabel();

  Future<PurchaseOutcome> buyRemoveAds();

  /// 機種変更・再インストール後に戻す。iOS は復元の導線が審査要件。
  Future<PurchaseOutcome> restore();

  void dispose();
}

/// 課金を扱わない実装。Web版・テストで使う。
class NoOpPurchaseService implements PurchaseService {
  @override
  set onDelivered(Future<void> Function(String productId)? callback) {}

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<String?> priceLabel() async => null;

  @override
  Future<PurchaseOutcome> buyRemoveAds() async => PurchaseOutcome.unavailable;

  @override
  Future<PurchaseOutcome> restore() async => PurchaseOutcome.unavailable;

  @override
  void dispose() {}
}

/// App Store の課金を使う実装。
class StorePurchaseService implements PurchaseService {
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  Future<void> Function(String productId)? _onDelivered;
  Completer<PurchaseOutcome>? _pending;
  ProductDetails? _product;

  @override
  set onDelivered(Future<void> Function(String productId)? callback) => _onDelivered = callback;

  @override
  Future<void> initialize() async {
    _subscription = _iap.purchaseStream.listen(_onUpdate, onError: (_) => _complete(PurchaseOutcome.failed));
  }

  Future<void> _onUpdate(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.productID != PurchaseService.removeAdsId || p.status == PurchaseStatus.pending) continue;
      var received = true;
      if (p.status == PurchaseStatus.purchased || p.status == PurchaseStatus.restored) {
        try {
          await _onDelivered?.call(p.productID);
        } catch (_) {
          received = false;
        }
      }
      switch (p.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _complete(PurchaseOutcome.purchased);
        case PurchaseStatus.canceled:
          _complete(PurchaseOutcome.canceled);
        case PurchaseStatus.error:
          _complete(PurchaseOutcome.failed);
        case PurchaseStatus.pending:
          break;
      }
      // 受け取れなかったぶんは完了通知を返さない。次の起動でストアがもう一度送ってくる
      if (received && p.pendingCompletePurchase) unawaited(_iap.completePurchase(p));
    }
  }

  void _complete(PurchaseOutcome o) {
    final c = _pending;
    if (c == null || c.isCompleted) return;
    _pending = null;
    c.complete(o);
  }

  @override
  Future<bool> isAvailable() async {
    try {
      return await _iap.isAvailable();
    } catch (_) {
      return false;
    }
  }

  Future<ProductDetails?> _load() async {
    if (_product != null) return _product;
    final r = await _iap.queryProductDetails({PurchaseService.removeAdsId});
    return _product = r.productDetails.where((p) => p.id == PurchaseService.removeAdsId).firstOrNull;
  }

  @override
  Future<String?> priceLabel() async {
    try {
      return (await _load())?.price;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<PurchaseOutcome> buyRemoveAds() async {
    try {
      final product = await _load();
      if (product == null) return PurchaseOutcome.unavailable;
      final c = _pending = Completer<PurchaseOutcome>();
      final started = await _iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: product));
      if (!started) {
        _pending = null;
        return PurchaseOutcome.failed;
      }
      // ストアの画面から戻ってこない場合に永久に待たない
      return await c.future.timeout(const Duration(minutes: 5), onTimeout: () => PurchaseOutcome.canceled);
    } catch (_) {
      _pending = null;
      return PurchaseOutcome.failed;
    }
  }

  @override
  Future<PurchaseOutcome> restore() async {
    try {
      final c = _pending = Completer<PurchaseOutcome>();
      await _iap.restorePurchases();
      // 購入履歴が無いと何も流れてこないので、待ち続けずに「対象なし」で返す
      return await c.future.timeout(const Duration(seconds: 20), onTimeout: () => PurchaseOutcome.unavailable);
    } catch (_) {
      _pending = null;
      return PurchaseOutcome.failed;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}

PurchaseService createPurchaseService() {
  if (kIsWeb) return NoOpPurchaseService();
  try {
    if (Platform.isIOS) return StorePurchaseService();
  } catch (_) {}
  return NoOpPurchaseService();
}
