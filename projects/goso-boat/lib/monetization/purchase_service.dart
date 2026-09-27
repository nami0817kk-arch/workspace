import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// 購入の結果。
enum PurchaseOutcome {
  /// 購入が成立した、または過去の購入が復元された。
  purchased,

  /// 保護者の承認待ち（ファミリー共有の「承認と購入のリクエスト」）。承認されたら届く。
  pending,

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

  /// 返金・取り消しされた購入が届いたら呼ぶ（広告を戻す）。
  set onRevoked(Future<void> Function(String productId)? callback);

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
  set onRevoked(Future<void> Function(String productId)? callback) {}

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
  Future<void> Function(String productId)? _onRevoked;

  /// いま待っている購入と復元。重ねて押されたら同じものを返す（2度押しで結果が食い違わないように）。
  /// 別々に持つのは、復元の「対象なし」が購入の結果として返らないようにするため。
  Completer<PurchaseOutcome>? _buying;
  Completer<PurchaseOutcome>? _restoring;
  ProductDetails? _product;

  @override
  set onDelivered(Future<void> Function(String productId)? callback) => _onDelivered = callback;

  @override
  set onRevoked(Future<void> Function(String productId)? callback) => _onRevoked = callback;

  /// 返金・取り消し済みの取引か。StoreKit 2 のプラグインは取り消された取引も「購入」として流してくるので、
  /// 取引の JSON（Transaction.jsonRepresentation）の revocationDate で見分ける。
  static bool isRevoked(PurchaseDetails p) {
    try {
      final j = jsonDecode(p.verificationData.localVerificationData);
      return j is Map && j['revocationDate'] != null;
    } catch (_) {
      return false; // JSON でない（StoreKit 1 のレシートなど）
    }
  }

  @override
  Future<void> initialize() async {
    _subscription = _iap.purchaseStream.listen(
      _onUpdate,
      onError: (_) {
        _finish(_buying, PurchaseOutcome.failed);
        _finish(_restoring, PurchaseOutcome.failed);
      },
    );
  }

  Future<void> _onUpdate(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.productID != PurchaseService.removeAdsId) continue;
      if (p.status == PurchaseStatus.pending) {
        // 保護者の承認待ち。待っている側には「承認待ち」と返し、承認されたら改めて届く
        _finish(_buying, PurchaseOutcome.pending);
        continue;
      }
      if ((p.status == PurchaseStatus.purchased || p.status == PurchaseStatus.restored) && isRevoked(p)) {
        // 返金された。広告を戻し、取引は片付ける。待っている購入・復元には「広告なし」と返さない
        try {
          await _onRevoked?.call(p.productID);
        } catch (_) {}
        if (p.pendingCompletePurchase) unawaited(_iap.completePurchase(p));
        continue;
      }
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
          // 買った・戻ったのなら、どちらを待っていても「広告なし」になった
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
      // 受け取れなかったぶんは完了通知を返さない。次の起動でストアがもう一度送ってくる
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
    final running = _buying;
    if (running != null && !running.isCompleted) return running.future;
    // 商品情報を取りに行く前に場所を取る（取得中の2度押しで2回買いに行かないように）
    final c = _buying = Completer<PurchaseOutcome>();
    try {
      final product = await _load();
      if (c.isCompleted) return await c.future; // 取得中に購入が届いた（起動時の再送・家族の承認）
      if (product == null) {
        _finish(c, PurchaseOutcome.unavailable);
        return await c.future;
      }
      final started = await _iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: product));
      if (!started) _finish(c, PurchaseOutcome.failed);
      // StoreKit 2 では購入の画面が閉じてから戻り、結果は通知で届く。
      // 通知が来ないまま待ち続けないための上限（届けば onDelivered で広告は消える）
      return await c.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          _finish(c, PurchaseOutcome.canceled);
          return PurchaseOutcome.canceled;
        },
      );
    } catch (e) {
      // StoreKit が取りやめを例外で返すことがある。自分でやめたのを「失敗」と出さない
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
      // StoreKit 2 の restorePurchases は、手元の購入の記録を通知に流してすぐ戻る。
      // 通知は少し遅れて届くので短く待ち、来なければ「対象なし」で確定する
      await _iap.restorePurchases();
      return await c.future.timeout(
        // 審査の担当が買った直後に試しても「見つからない」と出ないよう、少し長めに待つ
        const Duration(seconds: 5),
        onTimeout: () {
          _finish(c, PurchaseOutcome.unavailable);
          return PurchaseOutcome.unavailable;
        },
      );
    } catch (_) {
      // 確認できない購入が混じるとエラーで戻るが、確認できた分は通知で届く。少し待ってから失敗にする
      return await c.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          _finish(c, PurchaseOutcome.failed);
          return PurchaseOutcome.failed;
        },
      );
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
