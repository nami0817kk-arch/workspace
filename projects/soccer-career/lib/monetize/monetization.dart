import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ad_service.dart';
import 'purchase_service.dart';

/// 広告と課金の状態を持ち、いつ広告を出すかを決める。
///
/// **セーブデータではなく端末側（SharedPreferences）に置く。** 購入は
/// ストアのアカウントに紐づくもので、どのキャリアを遊んでいるかとは
/// 関係がない。引き継ぎコードにも載せない（他人の端末へ購入が移ってしまう）。
class Monetization extends ChangeNotifier {
  Monetization({AdService? ads, PurchaseService? purchases})
    : _ads = ads ?? createAdService(),
      _purchases = purchases ?? createPurchaseService();

  static const String _noAdsKey = 'monetize.noAds';
  static const String _tipsKey = 'monetize.tips';

  /// **何シーズン終えたら広告を出し始めるか。**
  ///
  /// 前は `freeSeasons = 3`（＝最初の2回の季末が無料）だったが、
  /// **広告が出る場所は季末しか無く、1キャリアは 18.6季**なので、
  /// 無料にするぶんがそのまま上限を削る。1 にして「1季目の終わりから」
  /// にした（2026-09-26、ユーザーの判断「少し上げる」）。
  ///
  /// 数え方は `seasonsPlayed >= adsFromSeason`。1季目を終えた時点で
  /// `seasonsPlayed == 1` なので、**1 なら1季目の終わりから出る**。
  static const int adsFromSeason = 1;

  /// 広告と広告のあいだに必ず空ける時間。
  ///
  /// シーズンは自動で飛ばせるので、間隔を置かないと連続で出る。
  /// **ここは遊ぶ側を守るための線**で、飛ばして遊ぶ人にだけ効く
  /// （1シーズンを手で進めれば数十分かかるので、普通は当たらない）。
  static const Duration adInterval = Duration(minutes: 3);

  final AdService _ads;
  final PurchaseService _purchases;

  bool initialized = false;

  /// 広告を消す買い切りを持っているか。
  bool noAds = false;

  /// 応援を受け取った回数。**ゲームには何も効かない。**
  int tips = 0;

  /// ストアが使えるか。使えない環境では購入の導線を出さない。
  bool storeAvailable = false;

  /// 表示用の価格。取れていなければ null。
  final Map<Product, String> prices = {};

  DateTime? _lastAd;

  /// 広告ユニットIDがテスト用のままか。設定画面に注意を出すために見る。
  bool get usingTestAdUnit => !kIsWeb && AdMobAdService.isUsingTestUnitId;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    noAds = prefs.getBool(_noAdsKey) ?? false;
    tips = prefs.getInt(_tipsKey) ?? 0;

    if (!noAds) await _ads.initialize();
    // **渡すのはここ1か所。** 買った瞬間に `buy()` の側で渡していた頃、
    // アプリを落としている間に決済が通った購入は誰も受け取らなかった。
    _purchases.onDelivered = _grant;
    await _purchases.initialize();
    storeAvailable = await _purchases.isAvailable();
    if (storeAvailable) {
      for (final product in Product.values) {
        final price = await _purchases.priceOf(product);
        if (price != null) prices[product] = price;
      }
    }

    initialized = true;
    notifyListeners();
  }

  /// いま広告を出してよいか。**判定と表示が同じここを読む。**
  ///
  /// 純粋な関数にしてあるのはテストのため。時計を渡せないと、
  /// 「4分あいているか」を確かめる方法が無くなる。
  bool shouldShowSeasonAd({required int seasonsPlayed, DateTime? now}) {
    if (noAds) return false;
    if (seasonsPlayed < adsFromSeason) return false;
    final last = _lastAd;
    if (last == null) return true;
    return (now ?? DateTime.now()).difference(last) >= adInterval;
  }

  /// シーズンの切れ目に出す全画面広告。閉じられるまで待つ。
  ///
  /// 在庫が無ければ [AdService] 側が何もせずに戻るので、広告のせいで
  /// シーズンが進まなくなることはない。
  Future<void> showSeasonAd({required int seasonsPlayed, DateTime? now}) async {
    if (!shouldShowSeasonAd(seasonsPlayed: seasonsPlayed, now: now)) return;
    final at = now ?? DateTime.now();
    // **出せた回だけ間隔を数える。** 前は出す前に記録していたので、
    // 在庫が無くて何も起きなかった回まで「出した」ことになり、
    // **見せていないのに次の機会が潰れていた**（広告の在庫は毎回あるとは
    // 限らないので、そのぶんそのまま収入が消える）。
    // 遊ぶ側から見ても、出ていないものを数える理由は無い。
    if (await _ads.showInterstitial()) _lastAd = at;
  }

  /// 買う。**受け取るのは [_grant] のほう**なので、ここでは結果を返すだけ。
  Future<PurchaseOutcome> buy(Product product) => _purchases.buy(product);

  Future<PurchaseOutcome> restore() => _purchases.restore();

  /// 届いたものを受け取る。ストアから流れてきたぶんも、買った直後のぶんも、
  /// 復元したぶんも、全部ここを通る。
  Future<void> _grant(Product product) async {
    final prefs = await SharedPreferences.getInstance();
    switch (product) {
      case Product.noAds:
        if (noAds) return;
        noAds = true;
        // もう出さないので、読み込み済みの広告も手放す。
        _ads.dispose();
        await prefs.setBool(_noAdsKey, true);
      case Product.tip:
        tips++;
        await prefs.setInt(_tipsKey, tips);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _ads.dispose();
    _purchases.dispose();
    super.dispose();
  }
}
