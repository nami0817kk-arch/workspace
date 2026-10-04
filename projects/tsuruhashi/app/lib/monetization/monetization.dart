import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ad_service.dart';
import 'purchase_service.dart';

/// 動画広告と引き換えの特典を渡してよいかの答え。
enum RewardGate {
  /// 渡してよい（広告を消した人・動画を見終えた）。
  granted,

  /// 動画を途中で閉じた。渡さない。
  declined,

  /// 動画を読み込めていない（通信なし・在庫切れ）。**タダでは渡さない**。
  unavailable,

  /// 動画はあったが表示に失敗した。**タダでは渡さない**。
  showFailed,
}

/// つるはし採掘の広告と「広告を消す」の決まり（2026-10-03、projects/tsuruhashi/CLAUDE.md）。
///
/// - 動画広告（報酬型）だけ: 「採掘の倍率を上げる（見るたびに ×2→×3→…）」と「留守の分を2倍で受け取る」。
///   倍率の数えはゲーム本体（JS）が持つ。ここは「見せて、見終えたか」だけを答える。
/// - 全画面広告・バナーは出さない。
/// - 広告を消す（買い切り）: 動画の特典を動画なしで受け取れる。
class Monetization extends ChangeNotifier {
  Monetization(this._prefs, {AdService? ads, PurchaseService? store})
    : ads = ads ?? NoOpAdService(),
      store = store ?? NoOpPurchaseService();

  final SharedPreferences _prefs;
  final AdService ads;
  final PurchaseService store;

  bool get adFree => _prefs.getBool('adFree') ?? false;

  /// 届いた購入の数。照合の最中に購入が届いたら、古い記録での判定を捨てるために使う。
  int _deliveries = 0;

  Future<void> start() async {
    store.onDelivered = (id) async {
      if (id != PurchaseService.removeAdsId) return;
      _deliveries++;
      await _setAdFree();
    };
    store.onRevoked = (id) async {
      if (id != PurchaseService.removeAdsId) return;
      final seen = _deliveries;
      if (await store.hasEntitlement() == true || seen != _deliveries) return;
      await _clearAdFree();
    };
    try {
      await store.initialize();
    } catch (_) {}
    try {
      await _reconcile().timeout(const Duration(seconds: 3));
    } catch (_) {}
    if (!adFree) {
      try {
        await ads.initialize();
      } catch (_) {}
    }
  }

  /// 端末の購入記録と照らし合わせる。再インストール後は「購入を復元」を押さなくても広告なしに戻す。
  Future<void> _reconcile() async {
    final seen = _deliveries;
    final e = await store.hasEntitlement();
    if (e == true && !adFree) await _setAdFree();
    if (e == false && adFree && seen == _deliveries) await _clearAdFree();
  }

  Future<void> _clearAdFree() async {
    if (!adFree) return;
    await _prefs.setBool('adFree', false);
    notifyListeners();
    try {
      await ads.initialize();
    } catch (_) {}
  }

  Future<void> _setAdFree() async {
    if (!adFree) ads.dispose();
    await _prefs.setBool('adFree', true);
    notifyListeners();
  }

  /// アプリが前面に戻ったときに呼ぶ。期限切れの広告を読み直す。
  void refreshAds() {
    if (!adFree) ads.ensureLoaded();
  }

  /// 特典の前に呼ぶ。広告を消した人はそのまま、それ以外は動画を1本見てもらう。
  Future<RewardGate> beforeReward({void Function()? onWaiting}) async {
    if (adFree) return RewardGate.granted;
    if (!ads.isRewardedAdReady) {
      ads.ensureLoaded();
      onWaiting?.call();
      if (!await ads.waitForRewarded(const Duration(seconds: 6))) {
        return adFree ? RewardGate.granted : RewardGate.unavailable;
      }
    }
    if (!_foreground) return RewardGate.unavailable;
    final r = await ads.showRewardedAd();
    // 見ている間に「広告を消す」が届いた（家族の承認など）なら、そのまま渡す
    if (adFree) return RewardGate.granted;
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

  Future<bool> get canBuy async => !adFree && await store.isAvailable();
  Future<String?> get price => store.priceLabel();

  Future<PurchaseOutcome> buy() async {
    final r = await store.buyRemoveAds();
    if (r == PurchaseOutcome.purchased) await _setAdFree();
    return r;
  }

  Future<PurchaseOutcome> restore() async {
    final r = await store.restore();
    if (r == PurchaseOutcome.purchased) await _setAdFree();
    return r;
  }
}
