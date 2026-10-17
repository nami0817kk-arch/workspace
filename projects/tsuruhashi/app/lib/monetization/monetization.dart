import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ad_service.dart';
import 'purchase_service.dart';

/// 動画広告と引き換えの特典を渡してよいかの答え。
enum RewardGate {
  /// 渡してよい（動画を見終えた）。
  granted,

  /// 動画を途中で閉じた。渡さない。
  declined,

  /// 動画を読み込めていない（通信なし・在庫切れ）。**タダでは渡さない**。
  unavailable,

  /// 動画はあったが表示に失敗した。**タダでは渡さない**。
  showFailed,
}

/// つるはし採掘の広告と課金アイテムの決まり（projects/tsuruhashi/CLAUDE.md）。
///
/// - 動画広告（報酬型）だけ: 「採掘の倍率を上げる（見るたびに ×2→×3→…）」と「留守の分を2倍で受け取る」。
///   倍率の数えはゲーム本体（JS）が持つ。ここは「見せて、見終えたか」だけを答える。
/// - 全画面広告・バナーは出さない。「広告を消す」は売らない（2026-10-04 に課金アイテムへ切り替え）。
/// - 課金アイテム: 買い切り（持っているか）は端末に、使い切りの特製弁当は「これまでに届いた合計」を端末に持つ。
///   ゲーム本体は合計との差だけを受け取るので、何度伝えても二度は渡らない。
class Monetization extends ChangeNotifier {
  Monetization(this._prefs, {AdService? ads, PurchaseService? store})
    : ads = ads ?? NoOpAdService(),
      store = store ?? NoOpPurchaseService();

  final SharedPreferences _prefs;
  final AdService ads;
  final PurchaseService store;

  static const _ownPrefix = 'own:';
  static const _bentoKey = 'bentoTotal';
  static const _txKey = 'bentoTx';

  /// 持っている買い切りの短い名前（canteen / cart）。
  List<String> get owned => [
    for (final id in PurchaseService.permanent)
      if (_prefs.getBool(_ownPrefix + id) ?? false) PurchaseService.keyOf(id),
  ];

  bool owns(String productId) => _prefs.getBool(_ownPrefix + productId) ?? false;

  /// これまでに届いた特製弁当の合計（使った数は引かない。引くのはゲーム本体）。
  int get bentoTotal => _prefs.getInt(_bentoKey) ?? 0;

  /// 届いた購入の数。照合の最中に購入が届いたら、古い記録での判定を捨てるために使う。
  int _deliveries = 0;

  Future<void> start() async {
    store.onDelivered = _deliver;
    store.onRevoked = (id) async {
      if (!PurchaseService.permanent.contains(id)) return;
      final seen = _deliveries;
      if (await store.hasEntitlement(id) == true || seen != _deliveries) return;
      await _setOwned(id, false);
    };
    try {
      await store.initialize();
    } catch (_) {}
    try {
      await _reconcile().timeout(const Duration(seconds: 3));
    } catch (_) {}
    try {
      await ads.initialize();
    } catch (_) {}
  }

  /// 届いた購入を受け取る。**ここが終わるまでストアに完了を返さない**（docs/app-pitfalls.md 1番）。
  Future<void> _deliver(String id, String? purchaseId) async {
    _deliveries++;
    if (PurchaseService.permanent.contains(id)) {
      await _setOwned(id, true);
      return;
    }
    final units = PurchaseService.consumable[id];
    if (units == null) return;
    // 同じ取引がもう一度届いても（完了を返す前に落ちた・起動時の再送）二度は渡さない
    final seen = _prefs.getStringList(_txKey) ?? const <String>[];
    if (purchaseId != null && purchaseId.isNotEmpty && seen.contains(purchaseId)) return;
    // 先に数を足してから取引を記録する（間で落ちたら、失うより二度渡すほうを選ぶ）
    await _prefs.setInt(_bentoKey, bentoTotal + units);
    if (purchaseId != null && purchaseId.isNotEmpty) {
      final next = [...seen, purchaseId];
      await _prefs.setStringList(_txKey, next.length > 200 ? next.sublist(next.length - 200) : next);
    }
    notifyListeners();
  }

  /// 端末の購入記録と照らし合わせる。再インストール後は「購入を復元」を押さなくても買い切りを戻す。
  Future<void> _reconcile() async {
    for (final id in PurchaseService.permanent) {
      final seen = _deliveries;
      final e = await store.hasEntitlement(id);
      if (e == true && !owns(id)) await _setOwned(id, true);
      if (e == false && owns(id) && seen == _deliveries) await _setOwned(id, false);
    }
  }

  Future<void> _setOwned(String id, bool v) async {
    if (owns(id) == v) return;
    await _prefs.setBool(_ownPrefix + id, v);
    notifyListeners();
  }

  /// アプリが前面に戻ったときに呼ぶ。期限切れの広告を読み直す。
  void refreshAds() => ads.ensureLoaded();

  /// 特典の前に呼ぶ。動画を1本見てもらう。
  Future<RewardGate> beforeReward({void Function()? onWaiting}) async {
    if (!ads.isRewardedAdReady) {
      ads.ensureLoaded();
      onWaiting?.call();
      if (!await ads.waitForRewarded(const Duration(seconds: 6))) return RewardGate.unavailable;
    }
    if (!_foreground) return RewardGate.unavailable;
    final r = await ads.showRewardedAd();
    return switch (r) {
      RewardResult.earned => RewardGate.granted,
      RewardResult.closedEarly => RewardGate.declined,
      RewardResult.unavailable => RewardGate.unavailable,
      RewardResult.showFailed => RewardGate.showFailed,
    };
  }

  bool get _foreground {
    try {
      return (WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed) == AppLifecycleState.resumed;
    } catch (_) {
      return true;
    }
  }

  Future<bool> get canBuy => store.isAvailable();

  /// 短い名前 → 表示用の価格。
  Future<Map<String, String>> get prices async =>
      (await store.priceLabels()).map((id, p) => MapEntry(PurchaseService.keyOf(id), p));

  /// 買う。**渡すのは [_deliver] だけ**（ストアの通知で届く）。ここの戻り値では渡さない。
  Future<PurchaseOutcome> buy(String productId) => store.buy(productId);

  Future<PurchaseOutcome> restore() => store.restore();
}
