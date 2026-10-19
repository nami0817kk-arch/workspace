import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ad_service.dart';
import 'purchase_service.dart';

/// 動画を見て元気になれるかの答え。
enum RecoverGate {
  /// 回復してよい（広告を消した人・動画を見終えた）。
  granted,

  /// 動画を途中で閉じた。回復はしない。
  declined,

  /// 動画を読み込めていない・表示に失敗した。**タダでは回復しない**。
  unavailable,
}

/// 広告と「広告を消す」の決まり（2026-10-19 ユーザー決定: 無料＋広告＋広告を消す 370円。
/// 護送ボート・サカマネと同じ形）。
///
/// - 全画面広告: 大会が終わって次の過ごし方を選ぶとき、[interstitialEvery] 回の大会ごとに1回。
///   最初の1年(6歳の大会)と、広告を消した人には出さない。出せなければ進行を止めない。
/// - 動画広告: 見ると疲れと気持ちが回復する(怪我も早く治る)。読み込めていなければ回復しない。
/// - 広告を消す: 全画面広告が出なくなり、回復も動画なしで使える。
class Monetization extends ChangeNotifier {
  Monetization(this._prefs, {AdService? ads, PurchaseService? store})
      : ads = ads ?? NoOpAdService(),
        store = store ?? NoOpPurchaseService();

  /// 何回の大会ごとに全画面広告を出すか。
  static const interstitialEvery = 3;

  final SharedPreferences _prefs;
  final AdService ads;
  final PurchaseService store;

  bool get adFree => _prefs.getBool('adFree') ?? false;

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
    // 購入記録との照合を先に済ませる(再インストール後に買った人の端末で広告の準備をしない)。
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

  /// 返金されたら広告を戻す。
  Future<void> _clearAdFree() async {
    if (!adFree) return;
    await _prefs.setBool('adFree', false);
    // 戻ってすぐの次の操作で全画面広告が出ないよう、数えは始めから
    await _prefs.setInt('tournamentsSinceAd', 0);
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
    await _prefs.setBool('adFree', true);
    notifyListeners();
  }

  /// 大会が1つ終わったときに呼ぶ。次の過ごし方を選ぶときに全画面広告を出す番を数える。
  /// 次が広告の番なら、結果を見ている間に読み込んでおく。
  Future<void> tournamentPlayed() async {
    if (adFree) return;
    final n = (_prefs.getInt('tournamentsSinceAd') ?? 0) + 1;
    await _prefs.setInt('tournamentsSinceAd', n);
    if (n >= interstitialEvery && !ads.isInterstitialReady) ads.ensureLoaded();
  }

  /// 全画面広告を出す番か。
  bool get interstitialDue =>
      !adFree && (_prefs.getInt('tournamentsSinceAd') ?? 0) >= interstitialEvery;

  /// 次の過ごし方を選ぶ直前に呼ぶ。番なら全画面広告を出し、閉じるまで待つ。出したら true。
  ///
  /// 在庫が無くて出せなければ、数えはそのままで次の機会に回す(進行は止めない)。
  Future<bool> beforeAction() async {
    if (!interstitialDue || !_foreground) return false;
    // 出す前に数え直す(広告の途中で終了されても、次の操作で続けて出ないように)
    await _prefs.setInt('tournamentsSinceAd', 0);
    final shown = await ads.showInterstitialAd();
    if (!shown) {
      await _prefs.setInt('tournamentsSinceAd', interstitialEvery);
    }
    return shown;
  }

  /// 「動画を見て元気になる」の前に呼ぶ。広告を消した人はそのまま、それ以外は動画を1本見てもらう。
  ///
  /// 動画を読み込み中なら少しだけ待つ([onWaiting] で「読み込み中」を出せる)。届かなければ回復しない。
  Future<RecoverGate> beforeRecover({void Function()? onWaiting}) async {
    if (adFree) return RecoverGate.granted;
    if (!ads.isRewardedAdReady) {
      ads.ensureLoaded();
      onWaiting?.call();
      if (!await ads.waitForRewarded(const Duration(seconds: 6))) {
        return adFree ? RecoverGate.granted : RecoverGate.unavailable;
      }
    }
    // 待っている間にアプリを裏へ回したなら出さない(戻った瞬間に広告を差し込まない)
    if (!_foreground) return RecoverGate.unavailable;
    final r = await ads.showRewardedAd();
    // 動画を見ている間に「広告を消す」が届いた(家族の承認など)なら、そのまま回復する
    if (adFree) return RecoverGate.granted;
    return switch (r) {
      RewardResult.earned => RecoverGate.granted,
      RewardResult.closedEarly => RecoverGate.declined,
      RewardResult.unavailable || RewardResult.showFailed =>
        RecoverGate.unavailable,
    };
  }

  /// アプリが前面にあるか(テストなどで分からないときは前面とみなす)。
  bool get _foreground {
    try {
      return (WidgetsBinding.instance.lifecycleState ??
              AppLifecycleState.resumed) ==
          AppLifecycleState.resumed;
    } catch (_) {
      return true; // 画面の仕組みが無い所(単体テスト)
    }
  }

  /// 回復のボタンに「動画」の印を付けるか(広告を消した人以外は、いつも動画が要る)。
  bool get recoverNeedsAd => !adFree;

  Future<bool> get canBuy async => !adFree && await store.isAvailable();
  Future<String?> get price => store.priceLabel();

  Future<PurchaseOutcome> buy() async {
    final r = await store.buyRemoveAds();
    // 届いた時点で onDelivered が adFree にしているが、念のためここでも立てる
    if (r == PurchaseOutcome.purchased) await _setAdFree();
    return r;
  }

  Future<PurchaseOutcome> restore() async {
    final r = await store.restore();
    if (r == PurchaseOutcome.purchased) await _setAdFree();
    return r;
  }
}
