import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';

import 'entitlements.dart';

/// 購入の結果（ページへは文字列で返す）。
enum PurchaseOutcome {
  purchased,
  pending,
  canceled,
  unavailable,
  failed,

  /// 払えたが、端末への書き込みに失敗した。完了通知は返していないので、次の起動でもう一度届く。
  undelivered,

  /// ほかの商品の購入を手続き中。
  busy,
}

/// 端末の購入記録の1件（返金・取り消し済みか）。
class StoreTransaction {
  const StoreTransaction(this.productId, {this.revoked = false});
  final String productId;
  final bool revoked;
}

/// App Store とのやりとり（テストで差し替えるための薄い窓口）。
abstract class StoreApi {
  Stream<List<PurchaseDetails>> get purchaseStream;
  Future<bool> isAvailable();
  Future<List<ProductDetails>> queryProducts(Set<String> ids);
  Future<bool> buy(ProductDetails product, {required bool consumable});
  Future<void> completePurchase(PurchaseDetails p);
  Future<void> restorePurchases();

  /// 端末に残っている取引の記録（StoreKit 2 の Transaction.all。使い終えた消費型は含まれない）。読めなければ null。
  Future<List<StoreTransaction>?> transactions();
}

/// 本物の App Store（in_app_purchase）。
class IapStoreApi implements StoreApi {
  final InAppPurchase _iap = InAppPurchase.instance;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _iap.purchaseStream;
  @override
  Future<bool> isAvailable() => _iap.isAvailable();
  @override
  Future<List<ProductDetails>> queryProducts(Set<String> ids) async => (await _iap.queryProductDetails(ids)).productDetails;
  @override
  Future<bool> buy(ProductDetails product, {required bool consumable}) {
    final param = PurchaseParam(productDetails: product);
    return consumable ? _iap.buyConsumable(purchaseParam: param, autoConsume: false) : _iap.buyNonConsumable(purchaseParam: param);
  }

  @override
  Future<void> completePurchase(PurchaseDetails p) => _iap.completePurchase(p);
  @override
  Future<void> restorePurchases() => _iap.restorePurchases();
  @override
  Future<List<StoreTransaction>?> transactions() async {
    try {
      final all = await SK2Transaction.transactions();
      return [for (final t in all) StoreTransaction(t.productId, revoked: revokedJson(t.jsonRepresentation))];
    } catch (_) {
      return null;
    }
  }
}

/// 取引の JSON（Transaction.jsonRepresentation）に返金・取り消しの日付があるか。
bool revokedJson(String? json) {
  if (json == null || json.isEmpty) return false;
  try {
    final j = jsonDecode(json);
    return j is Map && j['revocationDate'] != null;
  } catch (_) {
    return false;
  }
}

/// 課金の窓口。商品は5つ（非消費型2・消費型3）。docs/app-pitfalls.md 1番に従い、
/// **届いたものは待っているかどうかに関係なく [onDelivered] で受け取り、受け取りが済むまで完了通知を返さない。**
abstract class PurchaseService {
  /// 届いた購入（購入・復元・起動時の再送）。受け取りが済んだら正常に戻ること。失敗なら投げる。
  set onDelivered(Future<void> Function(String productId, String? purchaseId)? callback);

  /// 返金・取り消された購入が届いたら呼ぶ。
  set onRevoked(Future<void> Function(String productId)? callback);

  Future<void> initialize();
  Future<bool> isAvailable();

  /// 商品の表示価格（「¥610」など）。取れた分だけ。
  Future<Map<String, String>> prices();
  Future<PurchaseOutcome> buy(String productId);
  Future<PurchaseOutcome> restore();

  /// 端末の購入記録から見て、いまその買い切りの権利があるか。
  /// true=有効な取引がある、false=取引はあるが全部返金済み、null=分からない（記録が無い・読めない）。
  Future<bool?> hasEntitlement(String productId);
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
  Future<bool?> hasEntitlement(String productId) async => null;
  @override
  void dispose() {}
}

/// いま待っている購入（どの商品か）。
class _Buying {
  _Buying(this.id);
  final String id;
  final c = Completer<PurchaseOutcome>();
}

class StorePurchaseService implements PurchaseService {
  StorePurchaseService({StoreApi? api, this.buyWait = const Duration(minutes: 5), this.restoreWait = const Duration(seconds: 30)})
    : _api = api ?? IapStoreApi();

  final StoreApi _api;

  /// 購入の結果を待つ上限（過ぎたら「承認待ち」と返す。後から届けば受け取る）。
  final Duration buyWait;

  /// 復元の結果を待つ上限。StoreKit は記録を通知で少し遅れて流すので長めに待つ（2026-11-17：5秒で打ち切って「見つからない」と出ていた）。
  final Duration restoreWait;

  StreamSubscription<List<PurchaseDetails>>? _sub;
  Future<void> Function(String productId, String? purchaseId)? _onDelivered;
  Future<void> Function(String productId)? _onRevoked;
  _Buying? _buying;
  Completer<PurchaseOutcome>? _restoring;
  final Map<String, ProductDetails> _products = {};

  /// 届いた通知を1本ずつ順に処理する（同じ取引が続けて届いても、受け取りが重ならないように）。
  Future<void> _queue = Future<void>.value();

  /// 届いている通知の処理がすべて終わるまで待つ（テスト用）。
  Future<void> get idle => _queue;

  @override
  set onDelivered(Future<void> Function(String productId, String? purchaseId)? callback) => _onDelivered = callback;
  @override
  set onRevoked(Future<void> Function(String productId)? callback) => _onRevoked = callback;

  /// 返金・取り消し済みの取引か（StoreKit 2 は取り消された取引も購入として流してくる）。
  static bool isRevoked(PurchaseDetails p) => revokedJson(p.verificationData.localVerificationData);

  @override
  Future<void> initialize() async {
    _sub ??= _api.purchaseStream.listen(
      (list) => _queue = _queue.then((_) => _onUpdate(list)).catchError((Object _) {}),
      onError: (Object _) {
        _finishBuy(null, PurchaseOutcome.failed);
        _finish(_restoring, PurchaseOutcome.failed);
      },
    );
  }

  Future<void> _complete(PurchaseDetails p) async {
    if (!p.pendingCompletePurchase) return;
    try {
      await _api.completePurchase(p);
    } catch (_) {
      // 完了を返せなかったら、次の起動でもう一度届く（受け取りの控えで二度は渡らない）
    }
  }

  Future<void> _onUpdate(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (!allProductIds.contains(p.productID)) continue;
      final id = p.productID;
      if (p.status == PurchaseStatus.pending) {
        _finishBuy(id, PurchaseOutcome.pending); // 保護者の承認待ち。承認されたら改めて届く
        continue;
      }
      final ok = p.status == PurchaseStatus.purchased || p.status == PurchaseStatus.restored;
      if (ok && isRevoked(p)) {
        try {
          await _onRevoked?.call(id);
          await _complete(p);
        } catch (_) {
          // 戻せなかったら完了させない。次の起動でもう一度届く
        }
        continue;
      }
      var received = true;
      if (ok) {
        try {
          await _onDelivered?.call(id, p.purchaseID);
        } catch (_) {
          received = false;
        }
      }
      switch (p.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          // いま買っている商品のときだけ、その購入の結果にする（別の商品の再送を「購入できました」と出さない）
          _finishBuy(id, received ? PurchaseOutcome.purchased : PurchaseOutcome.undelivered);
          _finish(_restoring, received ? PurchaseOutcome.purchased : PurchaseOutcome.undelivered);
        case PurchaseStatus.canceled:
          _finishBuy(id, PurchaseOutcome.canceled);
        case PurchaseStatus.error:
          _finishBuy(id, PurchaseOutcome.failed);
          _finish(_restoring, PurchaseOutcome.failed);
        case PurchaseStatus.pending:
          break;
      }
      // 受け取れなかったぶんは完了通知を返さない（次の起動でストアがもう一度送ってくる）
      if (received) await _complete(p);
    }
  }

  /// いま待っている購入を終える。[id] が null なら商品を問わない（通知の流れそのものが壊れたとき）。
  void _finishBuy(String? id, PurchaseOutcome o) {
    final b = _buying;
    if (b == null || (id != null && b.id != id)) return;
    _buying = null;
    if (!b.c.isCompleted) b.c.complete(o);
  }

  void _finish(Completer<PurchaseOutcome>? c, PurchaseOutcome o) {
    if (c == null || c.isCompleted) return;
    if (identical(c, _restoring)) _restoring = null;
    c.complete(o);
  }

  @override
  Future<bool> isAvailable() async {
    try {
      return await _api.isAvailable();
    } catch (_) {
      return false;
    }
  }

  Future<void> _load() async {
    if (_products.length == allProductIds.length) return;
    for (final d in await _api.queryProducts(allProductIds)) {
      _products[d.id] = d;
    }
  }

  @override
  Future<Map<String, String>> prices() async {
    try {
      await _load();
    } catch (_) {
      // 取れた分だけ返す
    }
    return {for (final e in _products.entries) e.key: e.value.price};
  }

  @override
  Future<PurchaseOutcome> buy(String productId) async {
    if (!allProductIds.contains(productId)) return PurchaseOutcome.unavailable;
    final running = _buying;
    if (running != null && !running.c.isCompleted) {
      return running.id == productId ? running.c.future : PurchaseOutcome.busy; // 2度押しは同じ結果を返す
    }
    final b = _buying = _Buying(productId);
    try {
      await _load();
      if (b.c.isCompleted) return await b.c.future;
      final d = _products[productId];
      if (d == null) {
        _finishBuy(productId, PurchaseOutcome.unavailable);
        return await b.c.future;
      }
      final started = await _api.buy(d, consumable: consumableIds.contains(productId));
      if (!started) _finishBuy(productId, PurchaseOutcome.failed);
      return await b.c.future.timeout(buyWait, onTimeout: () {
        _finishBuy(productId, PurchaseOutcome.pending); // 取りやめと決めつけない。後から届けば受け取る
        return PurchaseOutcome.pending;
      });
    } catch (e) {
      _finishBuy(productId, '$e'.contains('userCancelled') ? PurchaseOutcome.canceled : PurchaseOutcome.failed);
      return await b.c.future;
    }
  }

  @override
  Future<PurchaseOutcome> restore() async {
    final running = _restoring;
    if (running != null && !running.isCompleted) return running.future;
    final c = _restoring = Completer<PurchaseOutcome>();
    try {
      await _api.restorePurchases();
      // 端末の記録に買い切りが1つも無ければ、待たずに「見つからない」と返す
      final rec = await _api.transactions();
      if (rec != null && !rec.any((t) => nonConsumableIds.contains(t.productId))) {
        _finish(c, PurchaseOutcome.unavailable);
      }
    } catch (_) {
      // 確認できない購入が混じるとエラーで戻るが、確認できた分は通知で届く。待ってから決める
    }
    // 打ち切ったら「確認中」。後から届けば受け取って反映する
    return c.future.timeout(restoreWait, onTimeout: () {
      _finish(c, PurchaseOutcome.pending);
      return PurchaseOutcome.pending;
    });
  }

  @override
  Future<bool?> hasEntitlement(String productId) async {
    final rec = await _api.transactions();
    if (rec == null) return null;
    final mine = rec.where((t) => t.productId == productId).toList();
    if (mine.isEmpty) return null;
    return mine.any((t) => !t.revoked);
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
