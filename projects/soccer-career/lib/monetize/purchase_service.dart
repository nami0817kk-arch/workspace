import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// 買えるもの。
///
/// **ゲームを強くするものは売らない。** 伸びしろも金も出場機会も、
/// `balance_sim` で測って釣り合わせてきたもので、売った瞬間にその調整が
/// 意味を失う（CLAUDE.md「常に正解になる選択肢を作らない」）。
/// 売るのは**広告を消すこと**だけ。
///
/// **「応援する」（消耗型）は 2026-10-01 に外した**（ユーザーの判断）。
/// 消耗型は復元できないので取りこぼすと払った額がそのまま消え、
/// しかもゲームには何も起きないので、割に合わない。
/// 商品を1つに絞ると、登録も審査も1件で済む。
enum Product {
  /// 広告を消す。買い切り・非消費型。
  noAds('soccer_career_no_ads', consumable: false);

  const Product(this.id, {required this.consumable});

  final String id;
  final bool consumable;

  static Set<String> get ids => {for (final p in Product.values) p.id};

  static Product? byId(String id) {
    for (final p in Product.values) {
      if (p.id == id) return p;
    }
    return null;
  }
}

/// 購入を試みた結果。
enum PurchaseOutcome {
  /// 成立した、または過去の購入が復元された。
  purchased,

  /// 利用者が自分で取りやめた。**失敗ではない**ので、そう見せない。
  canceled,

  /// 家族の承認待ち（Ask to Buy）。**取りやめではない。**
  /// 承認されたら改めてストアから届くので、そのとき [PurchaseService] の
  /// `onDelivered` が呼ばれる。ここで「取りやめました」と出すと、
  /// 待っている利用者に嘘を伝えることになる。
  pending,

  /// ストアに繋がらない、商品が見つからない。
  unavailable,

  /// ストアから失敗が返った。
  failed,
}

/// 課金の窓口。
abstract class PurchaseService {
  /// ストアの通知を受け取り始める。
  ///
  /// **[onDelivered] は必須。** 買ったものが届いたら、待っているかどうかに
  /// 関係なくこれを呼ぶ。ストアの通知は購入を始めた瞬間に返ってくるとは
  /// 限らない——アプリを落としている間に決済が通る、家族の承認を待つ、
  /// 5分の上限で待つのをやめた後に届く、別の端末で買ったものが起動時に
  /// 流れてくる。`await` している側だけに返していた頃、**これらは全部
  /// 「払ったのに何も起きない」**になっていた（`復元` を押すまで戻らない）。
  ///
  /// **引数にしてあるのは、渡し忘れと順番間違いを構造的に消すため。**
  /// 別の setter にしていた頃は、通知を受け取り始めたあとに設定することも、
  /// 設定しないまま始めることもできた。消耗型の商品（応援）は復元できないので、
  /// 取りこぼすと払った額がそのまま消える。
  /// [onRevoked] は返金・取り消しのとき。**非消耗型（広告を消す）が
  /// 返金されると、StoreKit は取り消し済みの取引を「購入」として流してくる。**
  /// 見分けないと、返金されたのに広告が消えたままになる。
  ///
  /// どちらも `Future` を返す。**受け取りが終わるまで完了通知
  /// （`completePurchase`）を返さない**ため——返すとストアは二度と
  /// 送ってこないので、保存の途中でアプリが落ちると払った額がそのまま消える。
  Future<void> initialize({
    required Future<void> Function(Product product) onDelivered,
    required Future<void> Function(Product product) onRevoked,
  });

  /// ストアが使えるか。使えなければ購入の導線を出さない。
  Future<bool> isAvailable();

  /// 表示用の価格（「¥400」など）。取得できなければ null。
  Future<String?> priceOf(Product product);

  Future<PurchaseOutcome> buy(Product product);

  /// 機種変更・再インストール後に購入済みの状態を戻す。
  /// **iOS は復元の導線を出すことが審査の要件**になっている。
  Future<PurchaseOutcome> restore();

  void dispose();
}

/// 課金を扱わない実装。Web 版・テストで使う。
class NoPurchaseService implements PurchaseService {
  @override
  Future<void> initialize({
    required Future<void> Function(Product product) onDelivered,
    required Future<void> Function(Product product) onRevoked,
  }) async {}

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<String?> priceOf(Product product) async => null;

  @override
  Future<PurchaseOutcome> buy(Product product) async =>
      PurchaseOutcome.unavailable;

  @override
  Future<PurchaseOutcome> restore() async => PurchaseOutcome.unavailable;

  @override
  void dispose() {}
}

/// ストアの課金基盤を使う実装。
class StorePurchaseService implements PurchaseService {
  final InAppPurchase _iap = InAppPurchase.instance;

  /// 届いたものの渡し先。`initialize` で必ず受け取る。
  Future<void> Function(Product product)? _onDelivered;

  /// 返金・取り消しの渡し先。
  Future<void> Function(Product product)? _onRevoked;

  /// 返金・取り消し済みの取引か。
  ///
  /// StoreKit 2 のプラグインは**取り消された取引も「購入」として流してくる**。
  /// 取引の JSON の `revocationDate` で見分ける。
  static bool isRevoked(PurchaseDetails purchase) =>
      _revokedJson(purchase.verificationData.localVerificationData);

  static bool _revokedJson(String? json) {
    if (json == null || json.isEmpty) return false;
    try {
      final decoded = jsonDecode(json);
      return decoded is Map && decoded['revocationDate'] != null;
    } catch (_) {
      return false;
    }
  }
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  /// 購入・復元の完了を待つ受け皿。結果はストリームで非同期に返ってくるので、
  /// 呼ぶ側が await できる形に変換している。
  Completer<PurchaseOutcome>? _pending;

  /// いま待っている商品ID。**待っていないものを取り違えないため**に持つ。
  String? _pendingId;

  final Map<String, ProductDetails> _products = {};
  bool _queried = false;

  @override
  Future<void> initialize({
    required Future<void> Function(Product product) onDelivered,
    required Future<void> Function(Product product) onRevoked,
  }) async {
    // **渡し先を先に持つ。** 起動時に残っていた購入は、購読した直後に
    // 流れてくる。先に持っていないと、そのぶんが落ちる。
    _onDelivered = onDelivered;
    _onRevoked = onRevoked;
    _subscription = _iap.purchaseStream.listen(
      _onUpdate,
      onError: (_) => _complete(PurchaseOutcome.failed),
    );
  }

  Future<void> _onUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      // 知らない商品IDは触らない。取り違えて別のものを渡さないため。
      final product = Product.byId(purchase.productID);
      if (product == null) continue;

      // 家族の承認待ち（Ask to Buy）。**取りやめではない。**
      // 承認されたら改めて届くので、ここでは待っている側にそう伝えるだけ。
      if (purchase.status == PurchaseStatus.pending) {
        if (_pendingId == null || purchase.productID == _pendingId) {
          _complete(PurchaseOutcome.pending);
        }
        continue;
      }

      final delivered = purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored;

      // 返金された取引。**「購入」として流れてくる**ので、渡す前に見分ける。
      if (delivered && isRevoked(purchase)) {
        try {
          await _onRevoked?.call(product);
          if (purchase.pendingCompletePurchase) {
            unawaited(_iap.completePurchase(purchase));
          }
        } catch (_) {
          // 戻せなかったら完了させない。次の起動でもう一度届く。
        }
        continue;
      }

      // **渡すほうは、待っているかどうかを見ない。** ここを
      // `await` している側だけに返していたので、アプリを落としている間に
      // 決済が通った購入は受け取り手が居ないまま完了通知だけ返され、
      // **払ったのに何も起きない**状態になっていた。
      //
      // **`await` するのは、保存が終わる前に完了通知を返さないため。**
      // 返すとストアは二度と送ってこないので、保存の途中で落ちると
      // 払った額がそのまま消える（消耗型の応援は復元もできない）。
      var received = true;
      if (delivered) {
        try {
          await _onDelivered?.call(product);
        } catch (_) {
          received = false;
        }
      }

      // 結果を `await` している側へ返すのは、待っている商品のときだけ。
      if (_pendingId == null || purchase.productID == _pendingId) {
        switch (purchase.status) {
          case PurchaseStatus.pending:
            break;
          case PurchaseStatus.purchased:
          case PurchaseStatus.restored:
            _complete(PurchaseOutcome.purchased);
          case PurchaseStatus.canceled:
            _complete(PurchaseOutcome.canceled);
          case PurchaseStatus.error:
            _complete(PurchaseOutcome.failed);
        }
      }

      // 完了通知を返さないと、ストアが同じ購入を送り続ける。
      // **受け取れなかったぶんは返さない。** 次の起動でもう一度届く。
      if (received && purchase.pendingCompletePurchase) {
        unawaited(_iap.completePurchase(purchase));
      }
    }
  }

  void _complete(PurchaseOutcome outcome) {
    final pending = _pending;
    if (pending == null || pending.isCompleted) return;
    _pending = null;
    _pendingId = null;
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

  Future<ProductDetails?> _load(Product product) async {
    final cached = _products[product.id];
    if (cached != null) return cached;
    if (!_queried) {
      // まとめて1回だけ問い合わせる。買うたびに聞き直すと待たされる。
      final response = await _iap.queryProductDetails(Product.ids);
      for (final p in response.productDetails) {
        _products[p.id] = p;
      }
      _queried = true;
    }
    return _products[product.id];
  }

  @override
  Future<String?> priceOf(Product product) async {
    try {
      return (await _load(product))?.price;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<PurchaseOutcome> buy(Product product) async {
    try {
      final details = await _load(product);
      if (details == null) return PurchaseOutcome.unavailable;

      final completer = Completer<PurchaseOutcome>();
      _pending = completer;
      _pendingId = product.id;
      final param = PurchaseParam(productDetails: details);
      final started = product.consumable
          ? await _iap.buyConsumable(purchaseParam: param)
          : await _iap.buyNonConsumable(purchaseParam: param);
      if (!started) {
        _pending = null;
        _pendingId = null;
        return PurchaseOutcome.failed;
      }
      // ストアの画面から戻ってこない場合に永久に待たないよう上限を置く。
      return await completer.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () => PurchaseOutcome.canceled,
      );
    } catch (_) {
      _pending = null;
      _pendingId = null;
      return PurchaseOutcome.failed;
    }
  }

  @override
  Future<PurchaseOutcome> restore() async {
    try {
      final completer = Completer<PurchaseOutcome>();
      _pending = completer;
      // **復元で戻るのは「広告を消す」だけ。** 応援は消耗型なので戻らない。
      // ここを null にすると、残っていた応援の通知で広告が消えかねない。
      _pendingId = Product.noAds.id;
      await _iap.restorePurchases();
      // 履歴が無い場合はストリームに何も流れないので、待ち続けずに
      // 「対象なし」で返す。
      return await completer.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () => PurchaseOutcome.unavailable,
      );
    } catch (_) {
      _pending = null;
      _pendingId = null;
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
    kIsWeb ? NoPurchaseService() : StorePurchaseService();
