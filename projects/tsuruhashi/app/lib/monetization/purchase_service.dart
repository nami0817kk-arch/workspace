import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';

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

/// 課金アイテムの窓口（2026-10-04 ユーザー指示「広告を消すではなく、課金アイテムにする」）。
/// 護送ボートの purchase_service.dart（1商品）を、買い切り2つ＋使い切り2つに広げた。
///
/// ゲーム本体とは短い名前（[keyOf]）でやりとりする。値段は App Store Connect で決める。
abstract class PurchaseService {
  /// App Store Connect の商品IDと一致させること。
  static const prefix = 'tsuruhashi_';

  /// 買い切り（非消費型）。社員食堂（仲間の力 +25%）・大きな荷車（留守の上限 +4時間）
  static const permanent = {'${prefix}canteen', '${prefix}cart'};

  /// 使い切り（消費型）の特製弁当と、1回で届く個数
  static const consumable = {'${prefix}bento3': 3, '${prefix}bento10': 10};

  static Set<String> get all => {...permanent, ...consumable.keys};
  static String keyOf(String productId) => productId.substring(prefix.length);
  static String? idOf(String key) => all.contains(prefix + key) ? prefix + key : null;

  /// **届いたら、待っているかどうかに関係なく呼ぶ。** ストアの通知は購入を始めた
  /// 瞬間に返るとは限らない（家族の承認・別の端末での購入・起動時の再送）。
  /// [purchaseId] は取引の番号（使い切りを二度渡さないために使う）。
  set onDelivered(Future<void> Function(String productId, String? purchaseId)? callback);

  /// 買い切りが返金・取り消しされたら呼ぶ（効果を外す）。
  set onRevoked(Future<void> Function(String productId)? callback);

  Future<void> initialize();
  Future<bool> isAvailable();

  /// 表示用の価格（商品ID → 「¥370」など）。取れなかった商品は入らない。
  Future<Map<String, String>> priceLabels();

  Future<PurchaseOutcome> buy(String productId);

  /// 機種変更・再インストール後に買い切りを戻す。iOS は復元の導線が審査要件。
  Future<PurchaseOutcome> restore();

  /// 端末の購入記録から見て、いま買い切り [productId] の権利があるか。
  /// true=有効な取引がある、false=取引はあるが全部返金済み、null=分からない（記録が無い・読めない）。
  Future<bool?> hasEntitlement(String productId);

  void dispose();
}

/// 課金を扱わない実装。Web版・テストで使う。
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
  Future<Map<String, String>> priceLabels() async => const {};

  @override
  Future<PurchaseOutcome> buy(String productId) async => PurchaseOutcome.unavailable;

  @override
  Future<PurchaseOutcome> restore() async => PurchaseOutcome.unavailable;

  @override
  Future<bool?> hasEntitlement(String productId) async => null;

  @override
  void dispose() {}
}

/// App Store の課金を使う実装。
class StorePurchaseService implements PurchaseService {
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  Future<void> Function(String productId, String? purchaseId)? _onDelivered;
  Future<void> Function(String productId)? _onRevoked;

  /// いま待っている購入と復元。重ねて押されたら同じものを返す（2度押しで結果が食い違わないように）。
  /// 購入は一度に1つ（[_buyingId]）。別々に持つのは、復元の「対象なし」が購入の結果として返らないようにするため。
  Completer<PurchaseOutcome>? _buying;
  String? _buyingId;
  Completer<PurchaseOutcome>? _restoring;
  Map<String, ProductDetails>? _products;

  @override
  set onDelivered(Future<void> Function(String productId, String? purchaseId)? callback) => _onDelivered = callback;

  @override
  set onRevoked(Future<void> Function(String productId)? callback) => _onRevoked = callback;

  /// 返金・取り消し済みの取引か。StoreKit 2 のプラグインは取り消された取引も「購入」として流してくるので、
  /// 取引の JSON（Transaction.jsonRepresentation）の revocationDate で見分ける。
  static bool isRevoked(PurchaseDetails p) => _revokedJson(p.verificationData.localVerificationData);

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
      if (!PurchaseService.all.contains(p.productID)) continue;
      final mine = p.productID == _buyingId;
      if (p.status == PurchaseStatus.pending) {
        // 保護者の承認待ち。待っている側には「承認待ち」と返し、承認されたら改めて届く
        if (mine) _finish(_buying, PurchaseOutcome.pending);
        continue;
      }
      if ((p.status == PurchaseStatus.purchased || p.status == PurchaseStatus.restored) && isRevoked(p)) {
        // 返金された。買い切りは効果を外し、取引は片付ける。待っている購入・復元には「届いた」と返さない
        // （使い切りは渡した物を取り上げない）
        try {
          if (PurchaseService.permanent.contains(p.productID)) await _onRevoked?.call(p.productID);
          if (p.pendingCompletePurchase) unawaited(_iap.completePurchase(p));
        } catch (_) {
          // 外せなかったら完了させない。次の起動でもう一度届く
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
          if (!received) break; // 受け取れていない。次の起動でもう一度届く
          if (mine) _finish(_buying, PurchaseOutcome.purchased);
          if (PurchaseService.permanent.contains(p.productID)) _finish(_restoring, PurchaseOutcome.purchased);
        case PurchaseStatus.canceled:
          if (mine) _finish(_buying, PurchaseOutcome.canceled);
        case PurchaseStatus.error:
          if (mine) _finish(_buying, PurchaseOutcome.failed);
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
    if (identical(c, _buying)) {
      _buying = null;
      _buyingId = null;
    }
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

  Future<Map<String, ProductDetails>> _load() async {
    final have = _products;
    if (have != null && have.length == PurchaseService.all.length) return have;
    final r = await _iap.queryProductDetails(PurchaseService.all);
    return _products = {
      for (final p in r.productDetails)
        if (PurchaseService.all.contains(p.id)) p.id: p,
    };
  }

  @override
  Future<Map<String, String>> priceLabels() async {
    try {
      return (await _load()).map((id, p) => MapEntry(id, p.price));
    } catch (_) {
      return const {};
    }
  }

  @override
  Future<PurchaseOutcome> buy(String productId) async {
    if (!PurchaseService.all.contains(productId)) return PurchaseOutcome.unavailable;
    final running = _buying;
    if (running != null && !running.isCompleted) {
      // 別の商品の購入を待っている間は、重ねて買いに行かない
      return _buyingId == productId ? running.future : PurchaseOutcome.unavailable;
    }
    // 商品情報を取りに行く前に場所を取る（取得中の2度押しで2回買いに行かないように）
    final c = _buying = Completer<PurchaseOutcome>();
    _buyingId = productId;
    try {
      final product = (await _load())[productId];
      if (c.isCompleted) return await c.future; // 取得中に購入が届いた（起動時の再送・家族の承認）
      if (product == null) {
        _finish(c, PurchaseOutcome.unavailable);
        return await c.future;
      }
      final param = PurchaseParam(productDetails: product);
      final started = PurchaseService.consumable.containsKey(productId)
          ? await _iap.buyConsumable(purchaseParam: param)
          : await _iap.buyNonConsumable(purchaseParam: param);
      if (!started) _finish(c, PurchaseOutcome.failed);
      // StoreKit 2 では購入の画面が閉じてから戻り、結果は通知で届く。
      // 通知が来ないまま待ち続けないための上限（後から届いても onDelivered で渡す）
      return await c.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          // 取りやめと決めつけない。後から届けば onDelivered で渡す
          _finish(c, PurchaseOutcome.pending);
          return PurchaseOutcome.pending;
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
  Future<bool?> hasEntitlement(String productId) async {
    try {
      final mine = (await SK2Transaction.transactions())
          .where((t) => t.productId == productId)
          .toList();
      if (mine.isEmpty) return null;
      return mine.any((t) => !_revokedJson(t.jsonRepresentation));
    } catch (_) {
      return null;
    }
  }

  static bool _revokedJson(String? json) {
    if (json == null || json.isEmpty) return false;
    try {
      final j = jsonDecode(json);
      return j is Map && j['revocationDate'] != null;
    } catch (_) {
      return false;
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
