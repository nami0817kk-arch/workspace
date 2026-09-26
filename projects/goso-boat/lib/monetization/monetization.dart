import 'package:flutter/foundation.dart';
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
}

/// 広告と「広告を消す」の決まり（2026-09-27 ユーザー決定: 無料＋広告＋広告を消す 370円）。
///
/// - 全画面広告: 面をクリアして次へ進むとき、3面に1回。舞台1のあいだと、広告を消した人には出さない。
///   失敗したとき（逃げられたとき）には出さない。
/// - 動画広告: 見るとヒントが1回使える。**読み込めていないときはそのままヒントを出す**
///   （通信が無い・在庫切れで詰まらせないため）。
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
      if (id == PurchaseService.removeAdsId) await _setAdFree();
    };
    await store.initialize();
    if (!adFree) await ads.initialize();
  }

  Future<void> _setAdFree() async {
    await _prefs.setBool('adFree', true);
    notifyListeners();
  }

  /// 面をクリアして次へ進む直前に呼ぶ。出すべきなら全画面広告を出し、閉じるまで待つ。
  Future<bool> afterClear(Level level) async {
    if (adFree || level.world == 1) return false;
    final n = (_prefs.getInt('clearsSinceAd') ?? 0) + 1;
    if (n < interstitialEvery) {
      await _prefs.setInt('clearsSinceAd', n);
      return false;
    }
    await _prefs.setInt('clearsSinceAd', 0);
    await ads.showInterstitialAd();
    return true;
  }

  /// ヒントの前に呼ぶ。広告を消した人はそのまま、それ以外は動画を1本見てもらう。
  Future<HintGate> beforeHint() async {
    if (adFree || !ads.isRewardedAdReady) return HintGate.granted;
    return await ads.showRewardedAd() ? HintGate.granted : HintGate.declined;
  }

  /// ヒントのボタンに「動画」の印を付けるか。
  bool get hintNeedsAd => !adFree && ads.isRewardedAdReady;

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
