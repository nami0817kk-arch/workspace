import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ad_service.dart';
import 'purchase_service.dart';

/// 疲れを取る動画を見たときの答え。
enum RecoveryGate {
  /// 取ってよい（広告を消した人・動画を見終えた）。
  granted,

  /// 動画を途中で閉じた。
  declined,

  /// 動画を読み込めていない（通信なし・在庫切れ）。**タダでは取らせない**。
  unavailable,

  /// 動画はあったが表示に失敗した。**タダでは取らせない**。
  showFailed,
}

/// 広告と「広告を消す」の決まり（無料＋広告＋広告を消す 370円。護送ボートと同じ。2026-10-21）。
///
/// - 全画面広告: 年が変わる節目で、4年に1回。13歳になるまで（少年野球のあいだ）と、広告を消した人には出さない。
///   選択の途中には出さない（年を進めた直後に、少し置いてから出す）。
/// - 動画広告: 疲れがたまった年に1度、見ると疲れが大きく抜ける（任意）。読み込めていないときは出さない。
/// - 広告を消す: 全画面広告が出なくなり、疲れを取る特典も動画なしで使える。
class Monetization extends ChangeNotifier {
  Monetization(this._prefs, {AdService? ads, PurchaseService? store})
      : ads = ads ?? NoOpAdService(),
        store = store ?? NoOpPurchaseService();

  /// 全画面広告を出す間隔（年）。
  static const interstitialEvery = 4;

  /// 全画面広告を出さない年齢（これ未満は少年野球のあいだ）。
  static const interstitialFromAge = 13;

  final SharedPreferences _prefs;
  final AdService ads;
  final PurchaseService store;

  static const _adFreeKey = 'baseball_adFree';
  static const _yearsKey = 'baseball_yearsSinceAd';

  bool get adFree => _prefs.getBool(_adFreeKey) ?? false;

  Future<void> start() async {
    store.onDelivered = (id) async {
      if (id != PurchaseService.removeAdsId) return;
      _deliveries++;
      await _setAdFree();
    };
    store.onRevoked = (id) async {
      if (id != PurchaseService.removeAdsId) return;
      // 家族から共有された分や買い直した分など、ほかに有効な取引が残っていれば広告は戻さない
      final seen = _deliveries;
      if (await store.hasEntitlement() == true || seen != _deliveries) return;
      await _clearAdFree();
    };
    try {
      await store.initialize();
    } catch (_) {
      // ストアの準備に失敗しても、広告は準備する
    }
    // 購入記録との照合を先に済ませる（再インストール後に買った人の端末で広告の準備をしない）
    try {
      await _reconcile().timeout(const Duration(seconds: 3));
    } catch (_) {}
    if (!adFree) {
      try {
        await ads.initialize();
      } catch (_) {}
    }
  }

  /// 届いた購入の数。照合の最中に購入が届いたら、古い記録での判定を捨てるために使う。
  int _deliveries = 0;

  /// 端末の購入記録と照らし合わせる。閉じている間に返金された分を戻し、
  /// 再インストール後は「購入を復元」を押さなくても広告なしに戻す。記録が読めなければ何もしない。
  Future<void> _reconcile() async {
    final seen = _deliveries;
    final e = await store.hasEntitlement();
    if (e == true && !adFree) await _setAdFree();
    if (e == false && adFree && seen == _deliveries) await _clearAdFree();
  }

  Future<void> _clearAdFree() async {
    if (!adFree) return;
    await _prefs.setBool(_adFreeKey, false);
    // 戻ってすぐの年替わりで全画面広告が出ないよう、数えは始めから
    await _prefs.setInt(_yearsKey, 0);
    notifyListeners();
    try {
      await ads.initialize();
    } catch (_) {}
  }

  /// アプリが前面に戻ったときに呼ぶ。期限切れの広告を読み直す。
  void refreshAds() {
    if (!adFree) ads.ensureLoaded();
  }

  Future<void> _setAdFree() async {
    // 読み込み済みの広告と、電波が無いときの読み直しを止める
    if (!adFree) ads.dispose();
    await _prefs.setBool(_adFreeKey, true);
    notifyListeners();
  }

  /// 年が変わって [age] 歳になった。出す番なら全画面広告を出し、閉じるまで待つ。出したら true。
  ///
  /// 出せなかった（在庫なし・アプリが裏）ときは数え直さず、次の年にもう一度試す。
  Future<bool> afterYear(int age) async {
    if (adFree || age < interstitialFromAge) return false;
    final n = (_prefs.getInt(_yearsKey) ?? 0) + 1;
    if (n < interstitialEvery) {
      await _prefs.setInt(_yearsKey, n);
      return false;
    }
    if (!_foreground || !ads.isInterstitialReady) {
      // 次の年に出せるよう、いまのうちに読んでおく
      ads.ensureLoaded();
      await _prefs.setInt(_yearsKey, n);
      return false;
    }
    // 出す前に数え直しておく（広告の途中で終了されても、続けて出ないように）
    await _prefs.setInt(_yearsKey, 0);
    final shown = await ads.showInterstitialAd();
    if (!shown) await _prefs.setInt(_yearsKey, n);
    return shown;
  }

  /// 疲れを取る特典の前に呼ぶ。広告を消した人はそのまま、それ以外は動画を1本見てもらう。
  Future<RecoveryGate> beforeRecovery({void Function()? onWaiting}) async {
    if (adFree) return RecoveryGate.granted;
    if (!ads.isRewardedAdReady) {
      ads.ensureLoaded();
      onWaiting?.call();
      if (!await ads.waitForRewarded(const Duration(seconds: 6))) {
        return adFree ? RecoveryGate.granted : RecoveryGate.unavailable;
      }
    }
    // 待っている間にアプリを裏へ回したなら出さない
    if (!_foreground) return RecoveryGate.unavailable;
    final r = await ads.showRewardedAd();
    // 動画を見ている間に「広告を消す」が届いた（家族の承認など）なら、そのまま渡す
    if (adFree) return RecoveryGate.granted;
    return switch (r) {
      RewardResult.earned => RecoveryGate.granted,
      RewardResult.closedEarly => RecoveryGate.declined,
      RewardResult.unavailable => RecoveryGate.unavailable,
      RewardResult.showFailed => RecoveryGate.showFailed,
    };
  }

  bool get _foreground {
    try {
      return (WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed) == AppLifecycleState.resumed;
    } catch (_) {
      return true; // 画面の仕組みが無い所（単体テスト）
    }
  }

  /// 動画のボタンに「動画」の印を付けるか（広告を消した人以外は、いつも動画が要る）。
  bool get needsAd => !adFree;

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
