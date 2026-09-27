import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/puzzle.dart';
import 'ad_service.dart';
import 'purchase_service.dart';

/// ヒントを使えるかの答え。
enum HintGate {
  /// 使ってよい（広告を消した人・動画を見終えた・広告が無い環境）。
  granted,

  /// 動画を途中で閉じた。ヒントは出さない。
  declined,

  /// 動画を読み込めていない（通信なし・在庫切れ）。**タダでは出さない**。
  unavailable,

  /// 動画はあったが表示に失敗した（iPad の分割画面など）。**タダでは出さない**。
  showFailed,
}

/// 広告と「広告を消す」の決まり（2026-09-27 ユーザー決定: 無料＋広告＋広告を消す 370円）。
///
/// - 全画面広告: 面をクリアして次へ進むとき、3面に1回。舞台1のあいだと、広告を消した人には出さない。
///   失敗したとき（逃げられたとき）には出さない。
/// - 動画広告: 見るとヒントが1回使える。読み込めていないときはヒントを出さない
///   （2026-09-27 ユーザー指示「人のやる回数を減らすものはやめて」で、無料で出す逃げ道を外した）。
/// - 広告を消す: 全画面広告が出なくなり、ヒントも動画なしで使える。
class Monetization extends ChangeNotifier {
  Monetization(this._prefs, {AdService? ads, PurchaseService? store})
    : ads = ads ?? NoOpAdService(),
      store = store ?? NoOpPurchaseService();

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
    // 購入記録との照合を先に済ませる（再インストール後に買った人の端末で広告の準備をしない）。
    // 端末の中の記録を読むだけなので速い。念のため上限を置く
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

  /// 端末の購入記録と照らし合わせる。アプリを閉じている間に返金された分を戻し、
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
    // 戻ってすぐの「次の面へ」で全画面広告が出ないよう、数えは始めから
    await _prefs.setInt('clearsSinceAd', 0);
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

  /// 次の「次の面へ」で全画面広告を出す番か（出す前に少し間を置くため）。
  bool interstitialDue(Level level) => _interstitialTurn(level) && ads.isInterstitialReady;

  bool _interstitialTurn(Level level) =>
      !adFree && level.world != 1 && (_prefs.getInt('clearsSinceAd') ?? 0) + 1 >= interstitialEvery;

  /// 面をクリアしたときに呼ぶ。次の「次の面へ」で広告を出す番なら、結果を見ている間に読み込んでおく。
  void prepareNext(Level level) {
    if (_interstitialTurn(level) && !ads.isInterstitialReady) ads.ensureLoaded();
  }

  /// 面をクリアして次へ進む直前に呼ぶ。出すべきなら全画面広告を出し、閉じるまで待つ。
  ///
  /// [mayShow] が false なら、番でも出さずに次の回へ回す（直前に間を置けなかったとき。押した指が広告に当たらないように）。
  Future<bool> afterClear(Level level, {bool mayShow = true}) async {
    if (adFree || level.world == 1) return false;
    final n = (_prefs.getInt('clearsSinceAd') ?? 0) + 1;
    if (n < interstitialEvery) {
      await _prefs.setInt('clearsSinceAd', n);
      return false;
    }
    // 出せたときだけ数え直す。在庫が無くて出せなければ、次の「次の面へ」でもう一度試す
    // 出す前に数え直しておく（広告の途中で終了されても、次のクリアで続けて出ないように）
    if (!mayShow || !_foreground) {
      await _prefs.setInt('clearsSinceAd', n);
      return false;
    }
    await _prefs.setInt('clearsSinceAd', 0);
    final shown = await ads.showInterstitialAd();
    if (!shown) await _prefs.setInt('clearsSinceAd', n);
    return shown;
  }

  /// ヒントの前に呼ぶ。広告を消した人はそのまま、それ以外は動画を1本見てもらう。
  ///
  /// 動画を読み込み中なら少しだけ待つ（[onWaiting] で「読み込み中」を出せる）。届かなければ出さない。
  Future<HintGate> beforeHint({void Function()? onWaiting}) async {
    if (adFree) return HintGate.granted;
    if (!ads.isRewardedAdReady) {
      // 読み込みに失敗したままにならないよう、ここで読み直しを始める
      ads.ensureLoaded();
      onWaiting?.call();
      if (!await ads.waitForRewarded(const Duration(seconds: 6))) {
        return adFree ? HintGate.granted : HintGate.unavailable;
      }
    }
    // 待っている間にアプリを裏へ回したなら出さない（戻った瞬間に広告を差し込まない）
    if (!_foreground) return HintGate.unavailable;
    final r = await ads.showRewardedAd();
    // 動画を見ている間に「広告を消す」が届いた（家族の承認など）なら、そのままヒントを出す
    if (adFree) return HintGate.granted;
    return switch (r) {
      RewardResult.earned => HintGate.granted,
      RewardResult.closedEarly => HintGate.declined,
      RewardResult.unavailable => HintGate.unavailable,
      RewardResult.showFailed => HintGate.showFailed,
    };
  }

  /// アプリが前面にあるか（テストなどで分からないときは前面とみなす）。
  bool get _foreground {
    try {
      return (WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed) == AppLifecycleState.resumed;
    } catch (_) {
      return true; // 画面の仕組みが無い所（単体テスト）
    }
  }

  /// ヒントのボタンに「動画」の印を付けるか（広告を消した人以外は、いつも動画が要る）。
  bool get hintNeedsAd => !adFree;

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
