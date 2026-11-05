// 本物の表示の処理(AdMobAdService.presentRewarded / presentInterstitial)を、
// 本物の google_mobile_ads と同じ順で知らせが届く偽の広告で試す(2026-11-05)。
//
// **`show` は表示を頼んだ時点で返り、表示の始まり・報酬・閉じる通知は後から届く。**
// monetization_test の FakeAds は `show` の中で結果を決めるので、ここ(待ち方)は通らない。
// サカマネはこの形で「最後まで見ても何ももらえない」を出してしまった(docs/app-pitfalls.md 9番)。
import 'dart:async';

import 'package:basketball_career/monetization/ad_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class _LateRewarded implements RewardedAd {
  @override
  FullScreenContentCallback<RewardedAd>? fullScreenContentCallback;
  OnUserEarnedRewardCallback? _onReward;
  bool showCalled = false;
  int disposed = 0;
  Object? showThrows;

  @override
  Future<void> show({required OnUserEarnedRewardCallback onUserEarnedReward}) async {
    showCalled = true;
    if (showThrows != null) throw showThrows!;
    _onReward = onUserEarnedReward;
    // ここでは何も知らせずに返る(本物と同じ)
  }

  void begin() => fullScreenContentCallback!.onAdShowedFullScreenContent!(this);
  void earn() => _onReward!(this, RewardItem(1, 'sp'));
  void dismiss() => fullScreenContentCallback!.onAdDismissedFullScreenContent!(this);
  void failToShow() =>
      fullScreenContentCallback!.onAdFailedToShowFullScreenContent!(this, AdError(0, 'test', 'fail'));

  @override
  Future<void> dispose() async => disposed++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _LateInterstitial implements InterstitialAd {
  @override
  FullScreenContentCallback<InterstitialAd>? fullScreenContentCallback;
  int disposed = 0;

  @override
  Future<void> show() async {}

  void begin() => fullScreenContentCallback!.onAdShowedFullScreenContent!(this);
  void dismiss() => fullScreenContentCallback!.onAdDismissedFullScreenContent!(this);
  void failToShow() =>
      fullScreenContentCallback!.onAdFailedToShowFullScreenContent!(this, AdError(0, 'test', 'fail'));

  @override
  Future<void> dispose() async => disposed++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

const _grace = Duration(milliseconds: 50);

void main() {
  group('動画広告: 見終えるまで待ち、報酬を取りこぼさない(app-pitfalls #9)', () {
    test('show がすぐ返っても、閉じるまで結果を出さない。後から届いた報酬で「見終えた」になる', () async {
      final ad = _LateRewarded();
      RewardResult? got;
      unawaited(AdMobAdService.presentRewarded(ad, rewardGrace: _grace).then((r) => got = r));
      await settle();
      expect(ad.showCalled, isTrue);
      expect(got, isNull, reason: 'show が返った時点で結果を出している');
      ad.begin();
      await settle();
      expect(got, isNull);
      ad.earn();
      ad.dismiss();
      await settle();
      expect(got, RewardResult.earned);
      expect(ad.disposed, greaterThan(0));
    });

    test('閉じる通知が報酬より先に届いても、少し待って報酬を受け取る', () async {
      final ad = _LateRewarded();
      final r = AdMobAdService.presentRewarded(ad, rewardGrace: const Duration(milliseconds: 300));
      await settle();
      ad.begin();
      ad.dismiss();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      ad.earn();
      expect(await r, RewardResult.earned);
    });

    test('報酬なしで閉じたら「途中で閉じた」', () async {
      final ad = _LateRewarded();
      final r = AdMobAdService.presentRewarded(ad, rewardGrace: _grace);
      await settle();
      ad.begin();
      ad.dismiss();
      expect(await r, RewardResult.closedEarly);
    });

    test('表示に失敗したら「表示に失敗」。広告は捨てる', () async {
      final ad = _LateRewarded();
      final r = AdMobAdService.presentRewarded(ad, rewardGrace: _grace);
      await settle();
      ad.failToShow();
      expect(await r, RewardResult.showFailed);
      expect(ad.disposed, greaterThan(0));
    });

    test('show が例外を投げたら「表示に失敗」(固まらない)', () async {
      final ad = _LateRewarded()..showThrows = StateError('no view');
      expect(await AdMobAdService.presentRewarded(ad, rewardGrace: _grace), RewardResult.showFailed);
      expect(ad.disposed, greaterThan(0));
    });

    test('表示が始まらないまま返事が無ければ、上限で打ち切る(固まらない)', () async {
      final ad = _LateRewarded();
      final r = await AdMobAdService.presentRewarded(ad,
          rewardGrace: _grace, showTimeout: const Duration(milliseconds: 100));
      expect(r, RewardResult.showFailed);
    });

    test('表示が始まった後は、上限を過ぎても閉じるまで待つ(広告から App Store へ行って戻っても受け取る)', () async {
      final ad = _LateRewarded();
      RewardResult? got;
      unawaited(AdMobAdService.presentRewarded(ad,
              rewardGrace: _grace, showTimeout: const Duration(milliseconds: 100))
          .then((r) => got = r));
      await settle();
      ad.begin();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(got, isNull, reason: '見ている途中で打ち切っている');
      ad.earn();
      ad.dismiss();
      await settle();
      expect(got, RewardResult.earned);
    });
  });

  group('全画面広告: 閉じるまで待つ(広告の裏で次へ進まない)', () {
    test('閉じるまで戻らず、閉じたら「出せた」', () async {
      final ad = _LateInterstitial();
      bool? got;
      unawaited(AdMobAdService.presentInterstitial(ad).then((r) => got = r));
      await settle();
      ad.begin();
      await settle();
      expect(got, isNull);
      ad.dismiss();
      await settle();
      expect(got, isTrue);
      expect(ad.disposed, greaterThan(0));
    });

    test('表示に失敗したら「出せなかった」', () async {
      final ad = _LateInterstitial();
      final r = AdMobAdService.presentInterstitial(ad);
      await settle();
      ad.failToShow();
      expect(await r, isFalse);
    });

    test('始まらないまま返事が無ければ、上限で「出せなかった」', () async {
      final ad = _LateInterstitial();
      expect(await AdMobAdService.presentInterstitial(ad, showTimeout: const Duration(milliseconds: 100)),
          isFalse);
    });
  });
}
