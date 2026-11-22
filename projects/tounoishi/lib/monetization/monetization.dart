import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ad_service.dart';
import 'purchase_service.dart';

/// 塔の意志の広告と「広告を消す」の決まり（2026-11-22。ひかりの指名の monetization.dart を写して絞ったもの）。
///
/// - 全画面広告: ゲームが頼んだとき（負けて結果を出す前・塔が1階伸びる前）に出す。出すかどうかはゲーム本体（JS）が決める。
/// - 広告を消す（370円・非消耗型）: 全画面広告が出なくなる。購入を復元できる。
/// - 動画広告（リワード）と ATT（トラッキング許可）は入れない。
class Monetization extends ChangeNotifier {
  Monetization(this._prefs, {AdService? ads, PurchaseService? store})
    : ads = ads ?? NoOpAdService(),
      store = store ?? NoOpPurchaseService();

  final SharedPreferences _prefs;
  final AdService ads;
  final PurchaseService store;

  static const adFreeKey = 'adFree';

  bool get adFree => _prefs.getBool(adFreeKey) ?? false;

  /// 届いた購入の数。照合の最中に購入が届いたら、古い記録での判定を捨てるために使う。
  int _deliveries = 0;

  Future<void> start() async {
    // 購入の受け取りはここ1か所だけ（待っている人がいてもいなくても、届いたら広告を消す。docs/app-pitfalls.md 1番）
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
    await _prefs.setBool(adFreeKey, false);
    notifyListeners();
    try {
      await ads.initialize();
    } catch (_) {}
  }

  Future<void> _setAdFree() async {
    if (!adFree) ads.dispose();
    await _prefs.setBool(adFreeKey, true);
    notifyListeners();
  }

  /// アプリが前面に戻ったときに呼ぶ。期限切れの広告を読み直す。
  void refreshAds() {
    if (!adFree) ads.ensureLoaded();
  }

  /// 全画面広告を出しそうな場面に入ったときに呼ぶ（ゲームが決める）。そのときだけ読み込む。
  void prepareInterstitial() {
    if (!adFree) ads.prepareInterstitial();
  }

  /// ゲームが出す番と決めたときに呼ぶ。全画面広告を出し、閉じるまで待つ。
  /// 在庫が無ければ少しだけ待ち、来なければ何もせず false（進行を止めない）。
  Future<bool> showInterstitial({void Function()? onShown}) async {
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
  Future<PurchaseOutcome> buy() => store.buy();

  Future<PurchaseOutcome> restore() async {
    final r = await store.restore();
    // 何が戻ったかは通知（onDelivered）で受け取る。念のため端末の記録とも照らし合わせる
    try {
      await _reconcile().timeout(const Duration(seconds: 3));
    } catch (_) {}
    return r;
  }
}
