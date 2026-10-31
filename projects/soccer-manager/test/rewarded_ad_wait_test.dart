import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/monetization/ad_service.dart';
import 'package:soccer_manager/monetization/funds_pack.dart';
import 'package:soccer_manager/monetization/monetization_controller.dart';
import 'package:soccer_manager/monetization/purchase_service.dart';

/// 本物の google_mobile_ads と同じ順で通知を返す差し替え広告。
///
/// **`show` は表示を頼んだ時点で返り、報酬と閉じる通知は後から届く。**
/// 以前の差し替え(結果を返す前に報酬を確定させる)では、`await ad.show()`
/// の直後に報酬を見る壊れた形が通ってしまい、「動画を見ても資金が入らない」
/// を見逃していた。
class _LateRewardedAd implements RewardedAd {
  @override
  FullScreenContentCallback<RewardedAd>? fullScreenContentCallback;

  OnUserEarnedRewardCallback? _onReward;
  bool showCalled = false;
  int disposeCount = 0;

  @override
  Future<void> show(
      {required OnUserEarnedRewardCallback onUserEarnedReward}) async {
    showCalled = true;
    _onReward = onUserEarnedReward;
    // ここで何も通知せずに返る(本物と同じ)。
  }

  void earn() => _onReward!(this, RewardItem(1, 'coins'));

  void dismiss() =>
      fullScreenContentCallback!.onAdDismissedFullScreenContent!(this);

  void failToShow() => fullScreenContentCallback!
      .onAdFailedToShowFullScreenContent!(this, AdError(0, 'test', 'fail'));

  @override
  Future<void> dispose() async {
    disposeCount++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// [AdMobAdService.showAndAwaitReward] を通す AdService。
class _AdMobLikeAds implements AdService {
  _AdMobLikeAds(this.ad);
  final _LateRewardedAd ad;

  @override
  Future<void> initialize() async {}
  @override
  bool get isRewardedAdReady => true;
  @override
  Future<bool> showRewardedAd() => AdMobAdService.showAndAwaitReward(ad,
      rewardGrace: const Duration(milliseconds: 200));
  @override
  bool get isInterstitialAdReady => false;
  @override
  Future<void> showInterstitialAd() async {}
  @override
  void dispose() {}
}

class _NoStore implements PurchaseService {
  @override
  set onDelivered(
      Future<void> Function(String productId, String? purchaseId)? callback) {}
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> isAvailable() async => false;
  @override
  Future<String?> priceLabel() async => null;
  @override
  Future<PurchaseOutcome> buySupporter() async => PurchaseOutcome.unavailable;
  @override
  Future<String?> priceLabelFor(FundsPack pack) async => null;
  @override
  Future<PurchaseOutcome> buyFundsPack(FundsPack pack) async =>
      PurchaseOutcome.unavailable;
  @override
  Future<PurchaseOutcome> restorePurchases() async =>
      PurchaseOutcome.unavailable;
  @override
  void dispose() {}
}

void main() {
  group('リワード広告は閉じられるまで待つ', () {
    test('show が先に返り、報酬→閉じる が後から来ても特典が付く', () async {
      final ad = _LateRewardedAd();
      var closedCount = 0;
      var done = false;
      bool? result;
      final future =
          AdMobAdService.showAndAwaitReward(ad, onClosed: () => closedCount++)
              .then((v) {
        done = true;
        result = v;
      });

      await Future<void>.delayed(Duration.zero);
      expect(ad.showCalled, isTrue);
      expect(done, isFalse, reason: '広告がまだ閉じられていないのに結果を返した');

      ad.earn();
      await Future<void>.delayed(Duration.zero);
      expect(done, isFalse, reason: '閉じる前に結果を返した');

      ad.dismiss();
      await future;
      expect(result, isTrue, reason: '最後まで見たのに特典が付かない');
      expect(ad.disposeCount, 1);
      expect(closedCount, 1);
    });

    test('報酬の通知が閉じる通知より遅れて届いても特典が付く', () async {
      final ad = _LateRewardedAd();
      final future = AdMobAdService.showAndAwaitReward(ad,
          rewardGrace: const Duration(seconds: 1));
      await Future<void>.delayed(Duration.zero);

      ad.dismiss();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      ad.earn();

      expect(await future, isTrue, reason: '遅れて届いた報酬を捨てている');
    });

    test('報酬なしで閉じたら特典は付かない(待ちは短い)', () async {
      final ad = _LateRewardedAd();
      final watch = Stopwatch()..start();
      final future = AdMobAdService.showAndAwaitReward(ad,
          rewardGrace: const Duration(milliseconds: 100));
      await Future<void>.delayed(Duration.zero);
      ad.dismiss();
      expect(await future, isFalse);
      expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
      expect(ad.disposeCount, 1);
    });

    test('表示に失敗したら特典は付かず、待たずに返る', () async {
      final ad = _LateRewardedAd();
      final future = AdMobAdService.showAndAwaitReward(ad,
          rewardGrace: const Duration(seconds: 30));
      await Future<void>.delayed(Duration.zero);
      ad.failToShow();
      expect(await future.timeout(const Duration(seconds: 2)), isFalse);
      expect(ad.disposeCount, 1);
    });

    test('既定の待ち時間は短い(1秒前後)', () {
      expect(AdMobAdService.rewardAfterCloseGrace,
          lessThanOrEqualTo(const Duration(seconds: 2)));
      expect(AdMobAdService.rewardAfterCloseGrace, greaterThan(Duration.zero));
    });
  });

  group('受け取りの結果は閉じた後で決まる', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('見終えて閉じたら granted', () async {
      final ad = _LateRewardedAd();
      final money =
          MonetizationController(adService: _AdMobLikeAds(ad), purchases: _NoStore());
      await money.initialize();

      ClaimResult? result;
      final claim = money.claimReward().then((r) => result = r);
      await Future<void>.delayed(Duration.zero);
      expect(result, isNull, reason: '広告が閉じる前に結果が出ている');

      ad.earn();
      ad.dismiss();
      await claim;
      expect(result, ClaimResult.granted);
      expect(money.claimedToday, 1);
    });

    test('途中で閉じたら adNotCompleted(「受け取れませんでした」)で回数は減らない',
        () async {
      final ad = _LateRewardedAd();
      final money =
          MonetizationController(adService: _AdMobLikeAds(ad), purchases: _NoStore());
      await money.initialize();

      ClaimResult? result;
      final claim = money.claimReward().then((r) => result = r);
      await Future<void>.delayed(Duration.zero);
      expect(result, isNull);

      ad.dismiss();
      await claim;
      expect(result, ClaimResult.adNotCompleted);
      expect(money.claimedToday, 0);
    });
  });
}
