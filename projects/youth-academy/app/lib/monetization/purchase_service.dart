import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'entitlements.dart';

/// 購入の結果（ページへは文字列で返す）。
enum PurchaseOutcome { purchased, pending, canceled, unavailable, failed }

/// 課金の窓口。商品は5つ（非消費型2・消費型3）。docs/app-pitfalls.md 1番に従い、
/// **届いたものは待っているかどうかに関係なく [onDelivered] で受け取り、受け取りが済むまで完了通知を返さない。**
abstract class PurchaseService {
  /// 届いた購入（購入・復元・起動時の再送）。受け取りが済んだら正常に戻ること。
  set onDelivered(Future<void> Function(String productId, String? purchaseId)? callback);

  /// 返金・取り消された購入が届いたら呼ぶ。
  set onRevoked(Future<void> Function(String productId)? callback);

  Future<void> initialize();
  Future<bool> isAvailable();

  /// 商品の表示価格（「¥610」など）。取れた分だけ。
  Future<Map<String, String>> prices();
  Future<PurchaseOutcome> buy(String productId);
  Future<PurchaseOutcome> restore();
  void dispose();
}

class NoOpPurchaseService implements PurchaseService {
  @override
  set onDelivered(Future<void> Function(String productId, String? purchaseId)? callback) {}
  @override
  set onRevoked(Future<void> Function(String productId)? callback) {}
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> isAvailable() async => false;
  @override
  Future<Map<String, String>> prices() async => {};
  @override
  Future<PurchaseOutcome> buy(String productId) async => PurchaseOutcome.unavailable;
  @override
  Future<PurchaseOutcome> restore() async => PurchaseOutcome.unavailable;
  @override
  void dispose() {}
}

class StorePurchaseService implements PurchaseService {
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  Future<void> Function(String productId, String? purchaseId)? _onDelivered;
  Future<void> Function(String productId)? _onRevoked;
  Completer<PurchaseOutcome>? _buying;
  Completer<PurchaseOutcome>? _restoring;
  final Map<String, ProductDetails> _products = {};

  @override
  set onDelivered(Future<void> Function(String productId, String? purchaseId)? callback) => _onDelivered = callback;
  @override
  set onRevoked(Future<void> Function(String productId)? callback) => _onRevoked = callback;

  /// 返金・取り消し済みの取引か（StoreKit 2 は取り消された取引も購入として流してくる）。
  static bool isRevoked(PurchaseDetails p) {
    final json = p.verificationData.localVerificationData;
    if (json.isEmpty) return false;
    try {
      final j = jsonDecode(json);
      return j is Map && j['revocationDate'] != null;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> initialize() async {
    _sub = _iap.purchaseStream.listen(_onUpdate, onError: (_) {
      _finish(_buying, PurchaseOutcome.failed);
      _finish(_restoring, PurchaseOutcome.failed);
    });
  }

  Future<void> _onUpdate(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (!allProductIds.contains(p.productID)) continue;
      if (p.status == PurchaseStatus.pending) {
        _finish(_buying, PurchaseOutcome.pending); // 保護者の承認待ち。承認されたら改めて届く
        continue;
      }
      if ((p.status == PurchaseStatus.purchased || p.status == PurchaseStatus.restored) && isRevoked(p)) {
        try {
          await _onRevoked?.call(p.productID);
          if (p.pendingCompletePurchase) unawaited(_iap.completePurchase(p));
        } catch (_) {
          // 戻せなかったら完了させない。次の起動でもう一度届く
        }
        continue;
      }
      var received = true;
      if (p.status == PurchaseStatus.purchased || p.status == PurchaseStatus.restored) {
        try {
          await _onDelivered?.call(p.productID, p.purchaseID);
        } catch (_) {
          received = false;
        }
      }
      switch (p.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _finish(_buying, PurchaseOutcome.purchased);
          _finish(_restoring, PurchaseOutcome.purchased);
        case PurchaseStatus.canceled:
          _finish(_buying, PurchaseOutcome.canceled);
        case PurchaseStatus.error:
          _finish(_buying, PurchaseOutcome.failed);
          _finish(_restoring, PurchaseOutcome.failed);
        case PurchaseStatus.pending:
          break;
      }
      // 受け取れなかったぶんは完了通知を返さない（次の起動でストアがもう一度送ってくる）
      if (received && p.pendingCompletePurchase) unawaited(_iap.completePurchase(p));
    }
  }

  void _finish(Completer<PurchaseOutcome>? c, PurchaseOutcome o) {
    if (c == null || c.isCompleted) return;
    if (identical(c, _buying)) _buying = null;
    if (identical(c, _restoring)) _restoring = null;
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

  Future<void> _load() async {
    if (_products.length == allProductIds.length) return;
    final r = await _iap.queryProductDetails(allProductIds);
    for (final d in r.productDetails) {
      _products[d.id] = d;
    }
  }

  @override
  Future<Map<String, String>> prices() async {
    try {
      await _load();
      return {for (final e in _products.entries) e.key: e.value.price};
    } catch (_) {
      return {};
    }
  }

  @override
  Future<PurchaseOutcome> buy(String productId) async {
    if (!allProductIds.contains(productId)) return PurchaseOutcome.unavailable;
    final running = _buying;
    if (running != null && !running.isCompleted) return running.future; // 2度押しは同じ結果を返す
    final c = _buying = Completer<PurchaseOutcome>();
    try {
      await _load();
      if (c.isCompleted) return await c.future;
      final d = _products[productId];
      if (d == null) {
        _finish(c, PurchaseOutcome.unavailable);
        return await c.future;
      }
      final param = PurchaseParam(productDetails: d);
      final started = consumableIds.contains(productId)
          ? await _iap.buyConsumable(purchaseParam: param, autoConsume: false)
          : await _iap.buyNonConsumable(purchaseParam: param);
      if (!started) _finish(c, PurchaseOutcome.failed);
      return await c.future.timeout(const Duration(minutes: 5), onTimeout: () {
        _finish(c, PurchaseOutcome.pending); // 取りやめと決めつけない。後から届けば受け取る
        return PurchaseOutcome.pending;
      });
    } catch (e) {
      _finish(c, '$e'.contains('userCancelled') ? PurchaseOutcome.canceled : PurchaseOutcome.failed);
      return await c.future;
    }
  }

  @override
  Future<PurchaseOutcome> restore() async {
    final running = _restoring;
    if (running != null && !running.isCompleted) return running.future;
    final c = _restoring = Completer<PurchaseOutcome>();
    try {
      await _iap.restorePurchases();
      return await c.future.timeout(const Duration(seconds: 5), onTimeout: () {
        _finish(c, PurchaseOutcome.unavailable);
        return PurchaseOutcome.unavailable;
      });
    } catch (_) {
      return await c.future.timeout(const Duration(seconds: 2), onTimeout: () {
        _finish(c, PurchaseOutcome.failed);
        return PurchaseOutcome.failed;
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}

PurchaseService createPurchaseService() {
  if (kIsWeb) return NoOpPurchaseService();
  try {
    if (Platform.isIOS) return StorePurchaseService();
  } catch (_) {}
  return NoOpPurchaseService();
}
