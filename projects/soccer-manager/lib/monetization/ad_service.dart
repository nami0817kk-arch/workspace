import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// 広告の読み込みと表示。
///
/// 2種類ある。任意で見るリワード広告と、シーズンの切り替わりで一度だけ出る
/// 全画面広告(インタースティシャル)。後者はサポーター購入で出なくなる。
///
/// 実装を差し替えられるようにしてあるのは、広告SDKがAndroid/iOSでしか
/// 動かないため。Web版・テスト・デスクトップでは何もしない実装を使う。
abstract class AdService {
  Future<void> initialize();

  /// 表示できる広告が手元にあるか。無ければボタンを押させない。
  bool get isRewardedAdReady;

  /// 広告を最後まで見せる。特典を与えてよい場合だけ true を返す。
  /// 途中で閉じられた場合は false。
  Future<bool> showRewardedAd();

  /// シーズンの切り替わりで出す全画面広告が手元にあるか。
  bool get isInterstitialAdReady;

  /// 全画面広告を出し、閉じられるまで待つ。特典は無いので結果を返さない。
  /// 在庫が無いときは何もせずに戻る(進行を止めない)。
  Future<void> showInterstitialAd();

  void dispose();
}

/// 広告を扱わない実装。Web版・テスト・広告を無効化した構成で使う。
class NoOpAdService implements AdService {
  @override
  Future<void> initialize() async {}

  @override
  bool get isRewardedAdReady => false;

  @override
  Future<bool> showRewardedAd() async => false;

  @override
  bool get isInterstitialAdReady => false;

  @override
  Future<void> showInterstitialAd() async {}

  @override
  void dispose() {}
}

/// AdMob を使う実装。
///
/// 広告ユニットIDは --dart-define で渡す。既定値は Google が公開している
/// **テスト用ID**にしてある。自分のIDを設定し忘れたまま配信しても、
/// 本物の広告が出ず規約違反にならないようにするため。
///
///     flutter build appbundle --release \
///       --dart-define=ADMOB_REWARDED_ANDROID=ca-app-pub-xxx/yyy \
///       --dart-define=ADMOB_INTERSTITIAL_ANDROID=ca-app-pub-xxx/zzz
class AdMobAdService implements AdService {
  static const _androidUnitId = String.fromEnvironment(
    'ADMOB_REWARDED_ANDROID',
    defaultValue: 'ca-app-pub-3940256099942544/5224354917',
  );
  static const _iosUnitId = String.fromEnvironment(
    'ADMOB_REWARDED_IOS',
    defaultValue: 'ca-app-pub-3940256099942544/1712485313',
  );
  static const _interstitialAndroidUnitId = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_ANDROID',
    defaultValue: 'ca-app-pub-3940256099942544/1033173712',
  );
  static const _interstitialIosUnitId = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_IOS',
    defaultValue: 'ca-app-pub-3940256099942544/4411468910',
  );

  RewardedAd? _ad;
  bool _loading = false;
  DateTime? _adLoadedAt;
  InterstitialAd? _interstitial;
  bool _loadingInterstitial = false;
  DateTime? _interstitialLoadedAt;

  /// 読み込んだ広告が使える時間。
  ///
  /// **AdMob の広告は1時間で期限切れになる。** 公式が「1時間ごとに捨てて
  /// 読み直せ」と書いている。持ったままにしていたため、起動時に読んだ広告を
  /// 何時間も「準備できている」と扱い、いざ出そうとすると失敗していた。
  /// 実測(7日)で リクエスト231回に対して表示6回。
  /// https://developers.google.com/admob/android/rewarded
  static const Duration adLifetime = Duration(minutes: 55);

  /// シーズンの切り替わりで広告を読むのに待てる時間。
  /// これを過ぎたら広告なしで先へ進める。
  static const Duration interstitialLoadTimeout = Duration(seconds: 5);

  /// 読み込んでから[adLifetime]を過ぎていれば、もう出せない。
  /// 時計を渡せるようにしてあるのは、検査から呼ぶため。
  static bool adExpired(DateTime? loadedAt, {DateTime? now}) =>
      loadedAt == null ||
      (now ?? DateTime.now()).difference(loadedAt) >= adLifetime;

  /// 期限切れの広告を捨てて読み直す。
  void _dropIfExpired() {
    if (_ad != null && adExpired(_adLoadedAt)) {
      _ad!.dispose();
      _ad = null;
      _adLoadedAt = null;
      unawaited(_load());
    }
    if (_interstitial != null && adExpired(_interstitialLoadedAt)) {
      _interstitial!.dispose();
      _interstitial = null;
      _interstitialLoadedAt = null;
    }
  }

  static String get _unitId => _isIOS ? _iosUnitId : _androidUnitId;

  static String get _interstitialUnitId =>
      _isIOS ? _interstitialIosUnitId : _interstitialAndroidUnitId;

  static const _testUnitIdPrefix = 'ca-app-pub-3940256099942544';

  /// 既定のテスト用IDのままか。設定画面に警告を出すために使う。
  ///
  /// **いま動いているプラットフォームのIDだけを見る。** 4つ全部を見ると、
  /// iOS ビルドでは Android 用の --dart-define が渡らず既定のテストIDのまま
  /// 残るため、iOS のIDを正しく渡していても警告が出てしまう(実際に出た)。
  /// Web版は広告SDKを読み込まないので、判定する意味がない。
  static bool get isUsingTestUnitId {
    if (kIsWeb) return false;
    final ids = _isIOS
        ? const [_iosUnitId, _interstitialIosUnitId]
        : const [_androidUnitId, _interstitialAndroidUnitId];
    return ids.any((id) => id.startsWith(_testUnitIdPrefix));
  }

  /// Platform は Web で参照できない。判定の手前で kIsWeb を見ること。
  static bool get _isIOS {
    try {
      return Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> initialize() async {
    await MobileAds.instance.initialize();
    unawaited(_load());
    // **インタースティシャルは起動時に読まない。** 出るのはシーズンの
    // 切り替わりだけで、1シーズンは38節ある。起動時に読んでも、出す頃には
    // 必ず期限切れになっている。出す直前に読む([showInterstitialAd])。
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
            _interstitialLoadedAt = DateTime.now();
            _loadingInterstitial = false;
          },
          onAdFailedToLoad: (error) {
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

  Future<void> _load() async {
    if (_loading || _ad != null) return;
    _loading = true;
    try {
      await RewardedAd.load(
        adUnitId: _unitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _ad = ad;
            _adLoadedAt = DateTime.now();
            _loading = false;
          },
          onAdFailedToLoad: (error) {
            // 読み込み失敗は珍しくない(在庫切れ・通信断)。
            // 例外にせず、次に押されたときに読み直す。
            _ad = null;
            _loading = false;
          },
        ),
      );
    } catch (_) {
      _ad = null;
      _loading = false;
    }
  }

  @override
  bool get isRewardedAdReady {
    _dropIfExpired();
    return _ad != null;
  }

  @override
  Future<bool> showRewardedAd() async {
    _dropIfExpired();
    final ad = _ad;
    if (ad == null) {
      unawaited(_load());
      return false;
    }
    _ad = null;
    _adLoadedAt = null;

    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        unawaited(_load()); // 次回のために先読みしておく
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        unawaited(_load());
      },
    );

    await ad.show(onUserEarnedReward: (_, __) => earned = true);
    return earned;
  }

  @override
  bool get isInterstitialAdReady {
    _dropIfExpired();
    return _interstitial != null;
  }

  @override
  Future<void> showInterstitialAd() async {
    _dropIfExpired();
    if (_interstitial == null) {
      // **出す直前に読む。** シーズンの切り替わりは数秒かかる処理の後なので、
      // ここで少し待てる。起動時に先読みしても必ず期限切れになっていた。
      await _loadInterstitial().timeout(interstitialLoadTimeout,
          onTimeout: () {});
    }
    final ad = _interstitial;
    if (ad == null) {
      // 読めなければ黙って先へ進める。広告のために進行を止めない。
      return;
    }
    _interstitial = null;
    _interstitialLoadedAt = null;

    // 閉じられるまで待たないと、広告の裏で次のシーズンの画面が
    // 動き出してしまう。
    final closed = Completer<void>();
    void finish(Ad ad) {
      ad.dispose();
      // 次のシーズンは38節先なので、ここでは先読みしない(期限切れになる)。
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
    _ad?.dispose();
    _ad = null;
    _interstitial?.dispose();
    _interstitial = null;
  }
}

/// この端末で使う実装を選ぶ。
///
/// 広告SDKは Android/iOS 以外では動かないので、それ以外では
/// 何もしない実装を返す。Web版に広告は出ない。
AdService createAdService() {
  if (kIsWeb) return NoOpAdService();
  try {
    if (Platform.isAndroid || Platform.isIOS) return AdMobAdService();
  } catch (_) {
    // テスト環境など Platform を参照できない場合。
  }
  return NoOpAdService();
}
