import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// 動画広告（ヒントと引き換え）を出した結果。
enum RewardResult {
  /// 最後まで見た。特典を渡してよい。
  earned,

  /// 途中で閉じた。
  closedEarly,

  /// 出せなかった（読み込めていない・期限切れ・表示に失敗）。
  unavailable,
}

/// 広告の読み込みと表示（soccer-manager の ad_service.dart を iOS だけに絞り、
/// 2026-09-28 のリリース前の点検で、読み直し・期限切れ・表示失敗の扱いを足したもの）。
///
/// 2種類ある。ヒントと引き換えに見る動画（リワード）と、面と面の間に出る全画面広告。
/// 広告SDKは iOS でしか動かないので、Web版・テストでは何もしない実装を使う。
abstract class AdService {
  Future<void> initialize();

  /// 表示できる動画広告が手元にあるか。
  bool get isRewardedAdReady;

  /// 手元に無ければ読み込みを始める（読み込み失敗の後、次に使うときのため）。
  void ensureLoaded();

  /// 動画を見せる。閉じられるまで待つ。
  Future<RewardResult> showRewardedAd();

  /// 全画面広告を出し、閉じられるまで待つ。出せたら true。
  /// 在庫が無ければ何もせず false で戻る（進行を止めない）。
  Future<bool> showInterstitialAd();

  void dispose();
}

/// 広告を扱わない実装。Web版・テストで使う。
class NoOpAdService implements AdService {
  @override
  Future<void> initialize() async {}

  @override
  bool get isRewardedAdReady => false;

  @override
  void ensureLoaded() {}

  @override
  Future<RewardResult> showRewardedAd() async => RewardResult.unavailable;

  @override
  Future<bool> showInterstitialAd() async => false;

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

  /// 読み込んだ広告は約1時間で出せなくなる（AdMob の仕様）。少し手前で捨てて読み直す。
  static const _maxAge = Duration(minutes: 55);

  /// 読み込みに失敗したら、この間隔を空けて読み直す（在庫切れ・電波なしが続いても叩きすぎない）。
  static const _retryAfter = Duration(seconds: 30);

  /// 表示が終わったことが伝わってこない場合の上限（固まらないように）。
  static const _showTimeout = Duration(minutes: 3);

  /// 既定のテスト用IDのままか（リリースの CI で本物に替わっているかを確かめる）。
  static bool get isUsingTestUnitId =>
      _rewardedUnitId.startsWith(_testUnitIdPrefix) || _interstitialUnitId.startsWith(_testUnitIdPrefix);

  RewardedAd? _rewarded;
  DateTime? _rewardedAt;
  bool _loadingRewarded = false;
  Timer? _rewardedRetry;

  InterstitialAd? _interstitial;
  DateTime? _interstitialAt;
  bool _loadingInterstitial = false;
  Timer? _interstitialRetry;

  @override
  Future<void> initialize() async {
    // 広告の中身は全年齢向け（G）まで。4+ のアプリに合わない広告を出さない（Apple 2.5.18）
    await MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(maxAdContentRating: MaxAdContentRating.g),
    );
    await MobileAds.instance.initialize();
    _loadRewarded();
    _loadInterstitial();
  }

  bool _fresh(DateTime? at) => at != null && DateTime.now().difference(at) < _maxAge;

  void _loadRewarded() {
    if (_loadingRewarded) return;
    if (_rewarded != null && _fresh(_rewardedAt)) return;
    _rewarded?.dispose();
    _rewarded = null;
    _loadingRewarded = true;
    _rewardedRetry?.cancel();
    try {
      RewardedAd.load(
        adUnitId: _rewardedUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _rewarded = ad;
            _rewardedAt = DateTime.now();
            _loadingRewarded = false;
          },
          // 在庫切れ・通信断は珍しくない。間を空けて読み直す
          onAdFailedToLoad: (_) {
            _loadingRewarded = false;
            _rewardedRetry = Timer(_retryAfter, _loadRewarded);
          },
        ),
      );
    } catch (_) {
      _loadingRewarded = false;
      _rewardedRetry = Timer(_retryAfter, _loadRewarded);
    }
  }

  void _loadInterstitial() {
    if (_loadingInterstitial) return;
    if (_interstitial != null && _fresh(_interstitialAt)) return;
    _interstitial?.dispose();
    _interstitial = null;
    _loadingInterstitial = true;
    _interstitialRetry?.cancel();
    try {
      InterstitialAd.load(
        adUnitId: _interstitialUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _interstitial = ad;
            _interstitialAt = DateTime.now();
            _loadingInterstitial = false;
          },
          onAdFailedToLoad: (_) {
            _loadingInterstitial = false;
            _interstitialRetry = Timer(_retryAfter, _loadInterstitial);
          },
        ),
      );
    } catch (_) {
      _loadingInterstitial = false;
      _interstitialRetry = Timer(_retryAfter, _loadInterstitial);
    }
  }

  @override
  bool get isRewardedAdReady => _rewarded != null && _fresh(_rewardedAt);

  @override
  void ensureLoaded() {
    _loadRewarded();
    _loadInterstitial();
  }

  /// 全画面の広告を出して、閉じられるまで待つ。出せなければ false。
  Future<bool> _present(AdWithoutView ad, void Function(FullScreenContentCallback<AdWithoutView>) setCallback,
      Future<void> Function() show) async {
    final closed = Completer<bool>();
    setCallback(FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        if (!closed.isCompleted) closed.complete(true);
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        a.dispose();
        if (!closed.isCompleted) closed.complete(false);
      },
    ));
    try {
      await show();
    } catch (_) {
      ad.dispose();
      return false;
    }
    return closed.future.timeout(_showTimeout, onTimeout: () => false);
  }

  @override
  Future<RewardResult> showRewardedAd() async {
    final ad = _rewarded;
    if (ad == null || !_fresh(_rewardedAt)) {
      _loadRewarded();
      return RewardResult.unavailable;
    }
    _rewarded = null;
    var earned = false;
    final shown = await _present(
      ad,
      (cb) => ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
        onAdDismissedFullScreenContent: cb.onAdDismissedFullScreenContent,
        onAdFailedToShowFullScreenContent: cb.onAdFailedToShowFullScreenContent,
      ),
      () => ad.show(onUserEarnedReward: (_, _) => earned = true),
    );
    _loadRewarded(); // 次のヒントのために先読み
    if (earned) return RewardResult.earned;
    return shown ? RewardResult.closedEarly : RewardResult.unavailable;
  }

  @override
  Future<bool> showInterstitialAd() async {
    final ad = _interstitial;
    if (ad == null || !_fresh(_interstitialAt)) {
      _loadInterstitial();
      return false;
    }
    _interstitial = null;
    // 閉じられるまで待たないと、広告の裏で次の面が始まってしまう
    final shown = await _present(
      ad,
      (cb) => ad.fullScreenContentCallback = FullScreenContentCallback<InterstitialAd>(
        onAdDismissedFullScreenContent: cb.onAdDismissedFullScreenContent,
        onAdFailedToShowFullScreenContent: cb.onAdFailedToShowFullScreenContent,
      ),
      () => ad.show(),
    );
    _loadInterstitial();
    return shown;
  }

  @override
  void dispose() {
    _rewardedRetry?.cancel();
    _interstitialRetry?.cancel();
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
