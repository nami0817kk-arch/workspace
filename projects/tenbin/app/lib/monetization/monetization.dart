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

/// もじつみの広告と「広告を消す」（ひかりの指名の monetization.dart を写し、商品を1つに絞った）。
///
/// - 動画広告（報酬型）: 崩れたあとの「つづける」・アイテムを1つもらう（どちらも1回の遊びで1回）。
///   回数の数えはゲーム本体（JS）が持つ。ここは「見せて、見終えたか」だけを答える。
/// - 全画面広告: 結果から次を始めるとき、3回に1回（入れてすぐの3回と、動画を見てから2分は出さない）。
///   出す番の数えはゲーム本体（prototype/monetization.js の Money）が持つ。ここは出すだけ。
/// - 広告を消す: 全画面広告が出なくなり、動画の特典も動画なしで使える。
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
      if (!PurchaseService.allIds.contains(id)) return;
      _deliveries++;
      await _setAdFree();
    };
    store.onRevoked = (id) async {
      if (!PurchaseService.allIds.contains(id)) return;
      final seen = _deliveries;
      if (await store.hasEntitlement(id) == true || seen != _deliveries) return;
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
  /// [canceled] が true を返したら（ゲームで「やめる」が押された）、出さずに declined で返す。
  Future<RewardGate> beforeReward({void Function()? onWaiting, void Function()? onShown, bool Function()? canceled}) async {
    if (adFree) return RewardGate.granted;
    if (!ads.isRewardedAdReady) {
      ads.ensureLoaded();
      onWaiting?.call();
      if (!await ads.waitForRewarded(const Duration(seconds: 6))) {
        return adFree ? RewardGate.granted : RewardGate.unavailable;
      }
    }
    if (canceled?.call() ?? false) return RewardGate.declined;
    if (!_foreground) return RewardGate.unavailable;
    final r = await ads.showRewardedAd(onShown: onShown);
    // 見ている間に「広告を消す」が届いた（家族の承認など）なら、そのまま渡す
    if (adFree) return RewardGate.granted;
    return switch (r) {
      RewardResult.earned => RewardGate.granted,
      RewardResult.closedEarly => RewardGate.declined,
      RewardResult.unavailable => RewardGate.unavailable,
      RewardResult.showFailed => RewardGate.showFailed,
    };
  }

  /// 全画面広告を出しそうな場面に入ったときに呼ぶ（ゲームが決める）。そのときだけ読み込む。
  void prepareInterstitial() {
    if (!adFree) ads.prepareInterstitial();
  }

  /// ゲームが出す番と決めたときに呼ぶ（結果から次を始めるとき）。全画面広告を出し、閉じるまで待つ。
  /// 在庫が無ければ少しだけ待ち、来なければ何もせず false（進行を止めない）。
  Future<bool> betweenGames({void Function()? onShown}) async {
    if (adFree || !_foreground) return false;
    if (!ads.isInterstitialReady && !await ads.waitForInterstitial(const Duration(seconds: 2))) return false;
    if (adFree || !_foreground) return false;
    return ads.showInterstitialAd(onShown: onShown);
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
  Future<bool> get storeAvailable => store.isAvailable();

  /// 買う。手に入れる処理は onDelivered（通知）だけが受け持つ。ここは結果を返すだけ
  /// （通知を受け取れなかった購入は完了させず、次の起動で届き直す。ここで渡すと二重の入口になる）
  Future<PurchaseOutcome> buy() => store.buy(PurchaseService.removeAdsId);

  Future<PurchaseOutcome> restore() async {
    final r = await store.restore();
    // 何が戻ったかは通知（onDelivered）で受け取る。念のため端末の記録とも照らし合わせる
    try {
      await _reconcile().timeout(const Duration(seconds: 3));
    } catch (_) {}
    return r;
  }
}
