import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ad_service.dart';
import 'funds_pack.dart';
import 'purchase_service.dart';
import 'reward_offer.dart';

/// 特典を受け取ろうとした結果。
enum ClaimResult {
  /// 受け取れた。呼び出し側が資金を加算する。
  granted,

  /// 今日の上限に達している。
  limitReached,

  /// 広告を最後まで見なかった、または表示できなかった。
  adNotCompleted,

  /// この端末では広告も課金も使えない (Web版など)。
  unavailable,
}

/// 広告・課金の状態を持ち、特典の受け取りを仲介する。
///
/// セーブデータではなく端末側 (SharedPreferences) に置いている。
/// 購入はストアのアカウントに紐づくもので、どのセーブスロットで
/// 遊んでいるかとは関係がないため。
class MonetizationController extends ChangeNotifier {
  MonetizationController({AdService? adService, PurchaseService? purchases})
      : _ads = adService ?? createAdService(),
        _purchases = purchases ?? createPurchaseService();

  static const _supporterKey = 'monetization.supporter';

  /// 届いたがまだクラブ資金に移していない資金パックの商品ID(順番付き)。
  ///
  /// 資金はセーブの中(クラブ資金)に入るので、セーブが無いあいだ・別の
  /// スロットを開いているあいだは渡せない。端末側に預かっておき、
  /// セーブが開かれたときに移す。消費型なので「復元」では戻らない——
  /// ここで預かり損ねると、払った額がそのまま消える。
  static const _undeliveredFundsKey = 'monetization.undeliveredFunds';
  static const _claimDayKey = 'monetization.claimDay';
  static const _claimCountKey = 'monetization.claimCount';

  final AdService _ads;
  final PurchaseService _purchases;

  bool initialized = false;

  /// サポーター購入済みか。
  bool isSupporter = false;

  /// 今日すでに受け取った回数。
  int claimedToday = 0;

  /// 上の回数がどの日のものか (端末のローカル日付、yyyy-mm-dd)。
  String _claimDay = '';

  /// ストアが使えるか。使えない環境では購入導線を出さない。
  bool storeAvailable = false;

  /// 届いたが、まだクラブ資金に移していない資金パック。
  List<FundsPack> undeliveredFundsPacks = const [];

  /// 表示用の価格。取得できていなければ null。
  String? priceLabel;

  int get dailyLimit => isSupporter
      ? RewardOffer.dailyLimitSupporter
      : RewardOffer.dailyLimitFree;

  int get remainingToday => (dailyLimit - claimedToday).clamp(0, dailyLimit);

  /// いま特典を受け取れるか。
  ///
  /// サポーターは広告なしで受け取れる。無料の利用者は広告の在庫が
  /// 無いと受け取れない (押せるのに何も起きない状態を避ける)。
  bool get canClaim {
    if (remainingToday <= 0) return false;
    return isSupporter || _ads.isRewardedAdReady;
  }

  /// 広告の視聴が必要か。ボタンの文言を切り替えるために使う。
  bool get requiresAd => !isSupporter;

  static String _today() {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d';
  }

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    isSupporter = prefs.getBool(_supporterKey) ?? false;
    _claimDay = prefs.getString(_claimDayKey) ?? '';
    claimedToday = prefs.getInt(_claimCountKey) ?? 0;
    _rolloverIfNewDay();

    undeliveredFundsPacks = _readUndelivered(prefs);

    await _ads.initialize();
    // **受け取りはここ1か所。** 買った瞬間に呼び出し側で渡していた頃、
    // アプリを落としている間に決済が通った購入は誰も受け取らなかった。
    // initialize() より先に繋ぐ(起動時に溜まっていた通知が流れてくる)。
    _purchases.onDelivered = _grant;
    await _purchases.initialize();
    storeAvailable = await _purchases.isAvailable();
    if (storeAvailable) {
      priceLabel = await _purchases.priceLabel();
      for (final pack in FundsPack.values) {
        final price = await _purchases.priceLabelFor(pack);
        if (price != null) fundsPackPrices[pack] = price;
      }
    }

    initialized = true;
    notifyListeners();
  }

  /// 日付が変わっていたら回数を0に戻す。
  ///
  /// 端末の時計を戻せば回数を増やせてしまうが、対戦相手のいない
  /// 単独プレイのゲームで、しかも設定画面に資金追加機能がある以上、
  /// ここを厳密にしても守るものがない。サーバーを持つ理由にはならない。
  void _rolloverIfNewDay() {
    final today = _today();
    if (_claimDay != today) {
      _claimDay = today;
      claimedToday = 0;
    }
  }

  Future<void> _persistClaims() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_claimDayKey, _claimDay);
    await prefs.setInt(_claimCountKey, claimedToday);
  }

  /// 特典の受け取りを試みる。
  ///
  /// 資金の加算はここでは行わない。ゲームの状態を触るのは GameState の
  /// 責務で、この層はストアと広告だけを見る。
  Future<ClaimResult> claimReward() async {
    _rolloverIfNewDay();
    if (remainingToday <= 0) return ClaimResult.limitReached;

    if (!isSupporter) {
      if (!_ads.isRewardedAdReady) return ClaimResult.unavailable;
      final watched = await _ads.showRewardedAd();
      // 途中で閉じた場合は回数を消費させない。
      if (!watched) return ClaimResult.adNotCompleted;
    }

    claimedToday++;
    await _persistClaims();
    notifyListeners();
    return ClaimResult.granted;
  }

  /// シーズンの切り替わりで出る全画面広告。閉じられるまで待つ。
  ///
  /// サポーターには出さない。「買えば全画面広告が消える」ことが、この
  /// 買い切りの主な値打ちになっている。
  /// 在庫が無いときは [AdService] 側が何もせずに戻るので、広告のせいで
  /// シーズンが進まなくなることはない。
  Future<void> showSeasonInterstitial() async {
    if (isSupporter) return;
    await _ads.showInterstitialAd();
  }

  /// いま [showSeasonInterstitial] を呼んだら実際に広告が出るか。
  bool get willShowSeasonInterstitial =>
      !isSupporter && _ads.isInterstitialAdReady;

  /// 資金パックの表示用の価格。取得できていなければ null。
  final Map<FundsPack, String> fundsPackPrices = {};

  /// 資金パックを買う。成立したら true。
  ///
  /// 資金の加算はここでは行わない。ゲームの状態を触るのは GameState の
  /// 責務で、この層はストアだけを見る(特典の受け取りと同じ切り分け)。
  ///
  /// リワード広告と違い1日の回数制限は無い。制限を付けると、広告の
  /// 代わりに買うだけの商品になってサポーターとの違いが消えるため。
  Future<PurchaseOutcome> buyFundsPack(FundsPack pack) =>
      _purchases.buyFundsPack(pack);

  /// 買う。**受け取るのは [_grant] のほう**なので、ここでは結果を返すだけ。
  Future<PurchaseOutcome> buySupporter() => _purchases.buySupporter();

  Future<PurchaseOutcome> restorePurchases() => _purchases.restorePurchases();

  /// 届いたものを受け取る。買った直後のぶんも、アプリを落としている間に
  /// 決済が通ったぶんも、復元したぶんも、全部ここを通る。
  ///
  /// ここで失敗すると窓口は完了通知を返さないので、次の起動でまた届く。
  Future<void> _grant(String productId) async {
    if (productId == PurchaseService.supporterProductId) {
      if (isSupporter) return; // 既に渡してある
      await _markSupporter();
      return;
    }

    final pack = FundsPack.values
        .where((p) => p.productId == productId)
        .firstOrNull;
    if (pack == null) return;

    // 資金はセーブの中に入るため、ここでは預かるだけ。
    final prefs = await SharedPreferences.getInstance();
    final queued = [..._readUndelivered(prefs), pack];
    await prefs.setStringList(
        _undeliveredFundsKey, queued.map((p) => p.productId).toList());
    undeliveredFundsPacks = queued;
    notifyListeners();
  }

  /// 預かっている資金パックをクラブ資金へ移したあとに呼ぶ。
  Future<void> markFundsPackDelivered(FundsPack pack) async {
    final remaining = [...undeliveredFundsPacks];
    final at = remaining.indexOf(pack);
    if (at < 0) return;
    remaining.removeAt(at); // 同じパックを複数抱えていても1つだけ消す
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _undeliveredFundsKey, remaining.map((p) => p.productId).toList());
    undeliveredFundsPacks = remaining;
    notifyListeners();
  }

  static List<FundsPack> _readUndelivered(SharedPreferences prefs) {
    final ids = prefs.getStringList(_undeliveredFundsKey) ?? const [];
    return [
      for (final id in ids)
        ...FundsPack.values.where((p) => p.productId == id),
    ];
  }

  Future<void> _markSupporter() async {
    isSupporter = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_supporterKey, true);
    notifyListeners();
  }

  @override
  void dispose() {
    _ads.dispose();
    _purchases.dispose();
    super.dispose();
  }
}
