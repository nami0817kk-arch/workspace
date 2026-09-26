import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// 広告の読み込みと表示（soccer-manager の ad_service.dart を iOS だけに絞ったもの）。
///
/// 2種類ある。ヒントと引き換えに見る動画（リワード）と、面と面の間に出る全画面広告。
/// 広告SDKは iOS でしか動かないので、Web版・テストでは何もしない実装を使う。
abstract class AdService {
  Future<void> initialize();

  /// 表示できる動画広告が手元にあるか。
  bool get isRewardedAdReady;

  /// 動画を最後まで見せる。特典を渡してよいときだけ true。途中で閉じられたら false。
  Future<bool> showRewardedAd();

  /// 全画面広告を出し、閉じられるまで待つ。在庫が無ければ何もせず戻る（進行を止めない）。
  Future<void> showInterstitialAd();

  void dispose();
}

/// 広告を扱わない実装。Web版・テストで使う。
class NoOpAdService implements AdService {
  @override
  Future<void> initialize() async {}

  @override
  bool get isRewardedAdReady => false;

  @override
  Future<bool> showRewardedAd() async => false;

  @override
  Future<void> showInterstitialAd() async {}

  @override
  void dispose() {}
}

/// AdMob を使う実装。
///
/// 広告ユニットIDは --dart-define で渡す。既定値は Google が公開している**テスト用ID**。
/// 本物のIDを渡し忘れたまま配信しても、本物の広告が出ず規約違反にならないようにするため。
class AdMobAdService implements AdService {
  static const _rewardedUnitId = String.fromEnvironment(
    'ADMOB_REWARDED_IOS',
    defaultValue: 'ca-app-pub-3940256099942544/1712485313',
  );
  static const _interstitialUnitId = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_IOS',
    defaultValue: 'ca-app-pub-3940256099942544/4411468910',
  );

  static const _testUnitIdPrefix = 'ca-app-pub-3940256099942544';

  /// 既定のテスト用IDのままか（リリースの CI で本物に替わっているかを確かめる）。
  static bool get isUsingTestUnitId =>
      _rewardedUnitId.startsWith(_testUnitIdPrefix) || _interstitialUnitId.startsWith(_testUnitIdPrefix);

  RewardedAd? _rewarded;
  bool _loadingRewarded = false;
  InterstitialAd? _interstitial;
  bool _loadingInterstitial = false;

  @override
  Future<void> initialize() async {
    await MobileAds.instance.initialize();
    unawaited(_loadRewarded());
    unawaited(_loadInterstitial());
  }

  Future<void> _loadRewarded() async {
    if (_loadingRewarded || _rewarded != null) return;
    _loadingRewarded = true;
    try {
      await RewardedAd.load(
        adUnitId: _rewardedUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _rewarded = ad;
            _loadingRewarded = false;
          },
          // 在庫切れ・通信断は珍しくない。例外にせず、次に使うときに読み直す。
          onAdFailedToLoad: (_) {
            _rewarded = null;
            _loadingRewarded = false;
          },
        ),
      );
    } catch (_) {
      _rewarded = null;
      _loadingRewarded = false;
    }
  }

  Future<void> _loadInterstitial() async {
    if (_loadingInterstitial || _interstitial != null) return;
    _loadingInterstitial = true;
    try {
      await InterstitialAd.load(
        adUnitId: _interstitialUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _interstitial = ad;
            _loadingInterstitial = false;
          },
          onAdFailedToLoad: (_) {
            _interstitial = null;
            _loadingInterstitial = false;
          },
        ),
      );
    } catch (_) {
      _interstitial = null;
      _loadingInterstitial = false;
    }
  }

  @override
  bool get isRewardedAdReady => _rewarded != null;

  @override
  Future<bool> showRewardedAd() async {
    final ad = _rewarded;
    if (ad == null) {
      unawaited(_loadRewarded());
      return false;
    }
    _rewarded = null;
    var earned = false;
    final closed = Completer<void>();
    void finish(Ad ad) {
      ad.dispose();
      unawaited(_loadRewarded()); // 次のヒントのために先読み
      if (!closed.isCompleted) closed.complete();
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: finish,
      onAdFailedToShowFullScreenContent: (ad, _) => finish(ad),
    );
    await ad.show(onUserEarnedReward: (_, _) => earned = true);
    await closed.future;
    return earned;
  }

  @override
  Future<void> showInterstitialAd() async {
    final ad = _interstitial;
    if (ad == null) {
      unawaited(_loadInterstitial());
      return;
    }
    _interstitial = null;
    // 閉じられるまで待たないと、広告の裏で次の面が始まってしまう
    final closed = Completer<void>();
    void finish(Ad ad) {
      ad.dispose();
      unawaited(_loadInterstitial());
      if (!closed.isCompleted) closed.complete();
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: finish,
      onAdFailedToShowFullScreenContent: (ad, _) => finish(ad),
    );
    await ad.show();
    await closed.future;
  }

  @override
  void dispose() {
    _rewarded?.dispose();
    _rewarded = null;
    _interstitial?.dispose();
    _interstitial = null;
  }
}

/// この端末で使う実装を選ぶ。iOS 以外（Web版・テスト）では広告を出さない。
AdService createAdService() {
  if (kIsWeb) return NoOpAdService();
  try {
    if (Platform.isIOS) return AdMobAdService();
  } catch (_) {
    // テスト環境など Platform を参照できない場合
  }
  return NoOpAdService();
}
