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

  /// 出せなかった（読み込めていない・期限切れ）。
  unavailable,

  /// 読み込めていたのに表示に失敗した（iPad の分割画面・小さいウィンドウなど）。
  showFailed,
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

  /// 表示できる全画面広告が手元にあるか。
  bool get isInterstitialReady;

  /// 動画広告が読み込み中なら、届くまで最大 [max] 待つ。手元に出せる動画があれば true。
  Future<bool> waitForRewarded(Duration max);

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
  bool get isInterstitialReady => false;

  @override
  Future<bool> waitForRewarded(Duration max) async => false;

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
  static const _maxRetry = Duration(minutes: 5);

  /// 表示が終わったことが伝わってこない場合の上限（固まらないように）。
  static const _showTimeout = Duration(minutes: 3);

  /// 既定のテスト用IDのままか（リリースの CI で本物に替わっているかを確かめる）。
  static bool get isUsingTestUnitId =>
      _rewardedUnitId.startsWith(_testUnitIdPrefix) || _interstitialUnitId.startsWith(_testUnitIdPrefix);

  /// 読み込み中のまま返事が来ないときの上限（これを過ぎたら読み直してよい）。
  static const _loadTimeout = Duration(minutes: 1);

  /// 動画を閉じた通知が、報酬の通知より先に届いたときに待つ時間。
  static const _rewardGrace = Duration(milliseconds: 500);

  bool _disposed = false;

  /// 全年齢向けの設定と SDK の準備が済んだか。済むまでは読み込まない（設定の掛かっていない広告を読まないため）。
  bool _initialized = false;

  final _rewardedSlot = _Slot<RewardedAd>();
  final _interstitialSlot = _Slot<InterstitialAd>();

  @override
  Future<void> initialize() async {
    // 広告を消した後に返金されたときは、もう一度ここから始める
    _disposed = false;
    // 広告の中身は全年齢向け（G）まで。4+ のアプリに合わない広告を出さない（Apple 2.5.18）
    await MobileAds.instance.updateRequestConfiguration(RequestConfiguration(maxAdContentRating: MaxAdContentRating.g));
    await MobileAds.instance.initialize();
    _initialized = true;
    _loadRewarded();
    _loadInterstitial();
  }

  void _loadRewarded() => _load(_rewardedSlot, _loadRewarded, (onLoaded, onFailed) {
    return RewardedAd.load(
      adUnitId: _rewardedUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(onAdLoaded: onLoaded, onAdFailedToLoad: onFailed),
    );
  });

  void _loadInterstitial() => _load(_interstitialSlot, _loadInterstitial, (onLoaded, onFailed) {
    return InterstitialAd.load(
      adUnitId: _interstitialUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(onAdLoaded: onLoaded, onAdFailedToLoad: onFailed),
    );
  });

  /// 1枠ぶんの読み込み。失敗したら間を空けて読み直し、読み込めたら期限の少し前に読み直す。
  void _load<T extends AdWithoutView>(
    _Slot<T> slot,
    void Function() again,
    Future<void> Function(void Function(T) onLoaded, void Function(LoadAdError) onFailed) start,
  ) {
    if (_disposed || !_initialized || slot.ready) return;
    // 読み込み中でも、返事が来ないまま長く経っていれば読み直す
    if (slot.loadingSince != null && DateTime.now().difference(slot.loadingSince!) < _loadTimeout) return;
    slot.clear();
    final token = Object();
    slot.loadingToken = token;
    slot.loadingSince = DateTime.now();
    void failed() {
      if (_disposed || !identical(slot.loadingToken, token)) return;
      slot.loadingToken = null;
      slot.loadingSince = null;
      slot.notify();
      // 在庫切れ・通信断は珍しくない。失敗が続くほど間を空けて読み直す（30秒→1分→2分→4分で止める）
      final wait = _retryAfter * (1 << slot.failures.clamp(0, 3));
      slot.failures++;
      slot.timer = Timer(wait > _maxRetry ? _maxRetry : wait, again);
    }

    try {
      start((ad) {
        if (_disposed || !identical(slot.loadingToken, token)) {
          ad.dispose();
          return;
        }
        slot.loadingToken = null;
        slot.loadingSince = null;
        slot.ad = ad;
        slot.loadedAt = DateTime.now();
        slot.failures = 0;
        slot.notify();
        // 期限が切れる前に、次を読み込んでおく（長く遊んだ後の最初のヒントで失敗しないように）
        slot.timer = Timer(_maxAge, () {
          slot.loadedAt = null; // 端末の時計を戻されても、経過時間で必ず読み直す
          again();
        });
      }, (_) => failed()).catchError((_) => failed());
    } catch (_) {
      failed();
    }
  }

  @override
  bool get isRewardedAdReady => _rewardedSlot.ready;

  @override
  bool get isInterstitialReady => _interstitialSlot.ready;

  @override
  Future<bool> waitForRewarded(Duration max) async {
    if (_rewardedSlot.ready) return true;
    if (_rewardedSlot.loadingSince == null) return false;
    try {
      await _rewardedSlot.changed().timeout(max);
    } on TimeoutException {
      // 間に合わなかった
    }
    return _rewardedSlot.ready;
  }

  @override
  void ensureLoaded() {
    // 利用者が広告を求めた（アプリに戻った・ヒントを押した）ので、延びていた読み直しの間隔を戻してすぐ読む
    _rewardedSlot.failures = 0;
    _interstitialSlot.failures = 0;
    _loadRewarded();
    _loadInterstitial();
  }

  /// 全画面の広告を出して、閉じられるまで待つ。出せなければ false。
  ///
  /// [keepAfterDismiss] が true なら、閉じた通知では広告を捨てない（呼んだ側が後で捨てる）。
  /// 捨てた広告の通知はプラグインが握りつぶすので、閉じた後に届く報酬の通知を受けるにはこれが要る。
  Future<bool> _present(
    AdWithoutView ad,
    void Function(FullScreenContentCallback<AdWithoutView>) setCallback,
    Future<void> Function() show, {
    bool keepAfterDismiss = false,
  }) async {
    final closed = Completer<bool>();
    final started = Completer<void>();
    setCallback(
      FullScreenContentCallback(
        onAdShowedFullScreenContent: (_) {
          if (!started.isCompleted) started.complete();
        },
        onAdDismissedFullScreenContent: (a) {
          if (!keepAfterDismiss) a.dispose();
          if (!started.isCompleted) started.complete();
          if (!closed.isCompleted) closed.complete(true);
        },
        onAdFailedToShowFullScreenContent: (a, _) {
          a.dispose();
          if (!closed.isCompleted) closed.complete(false);
        },
      ),
    );
    try {
      await show();
    } catch (_) {
      ad.dispose();
      return false;
    }
    // 表示が始まらないまま返事が無いときだけ打ち切る。始まった後は、広告から App Store へ
    // 行って長く戻らなくても、閉じられるまで待つ（途中で打ち切ると、見終えた報酬を取りこぼす）
    final began = await Future.any([
      started.future.then((_) => true),
      closed.future.then((_) => true),
      Future.delayed(_showTimeout, () => false),
    ]);
    if (!began) {
      ad.dispose();
      return false;
    }
    return closed.future;
  }

  @override
  Future<RewardResult> showRewardedAd() async {
    final ad = _rewardedSlot.take();
    if (ad == null) {
      _loadRewarded();
      return RewardResult.unavailable;
    }
    // 見ている間に次の1本を読み始める（続けてヒントを押したときに待たせない）
    _loadRewarded();
    var earned = false;
    final shown = await _present(
      ad,
      (cb) => ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
        onAdShowedFullScreenContent: cb.onAdShowedFullScreenContent,
        onAdDismissedFullScreenContent: cb.onAdDismissedFullScreenContent,
        onAdFailedToShowFullScreenContent: cb.onAdFailedToShowFullScreenContent,
      ),
      () => ad.show(onUserEarnedReward: (_, _) => earned = true),
      keepAfterDismiss: true,
    );
    // 閉じた通知が報酬の通知より先に届くことがあるので、少しだけ待ってから捨てる
    if (shown && !earned) await Future<void>.delayed(_rewardGrace);
    ad.dispose(); // 2回目の dispose はプラグイン側で何もしない
    _loadRewarded(); // 見ている間の読み込みに失敗していたときのため
    if (earned) return RewardResult.earned;
    return shown ? RewardResult.closedEarly : RewardResult.showFailed;
  }

  @override
  Future<bool> showInterstitialAd() async {
    final ad = _interstitialSlot.take();
    if (ad == null) {
      _loadInterstitial();
      return false;
    }
    // 閉じられるまで待たないと、広告の裏で次の面が始まってしまう
    final shown = await _present(
      ad,
      (cb) => ad.fullScreenContentCallback = FullScreenContentCallback<InterstitialAd>(
        onAdShowedFullScreenContent: cb.onAdShowedFullScreenContent,
        onAdDismissedFullScreenContent: cb.onAdDismissedFullScreenContent,
        onAdFailedToShowFullScreenContent: cb.onAdFailedToShowFullScreenContent,
      ),
      () => ad.show(),
    );
    // 次の面への切り替えと重ならないよう、少し置いてから次を読む
    unawaited(Future<void>.delayed(const Duration(seconds: 2), _loadInterstitial));
    return shown;
  }

  @override
  void dispose() {
    _disposed = true;
    _rewardedSlot.clear();
    _interstitialSlot.clear();
  }
}

/// 読み込んだ広告1本と、その読み込みの状態。
class _Slot<T extends AdWithoutView> {
  T? ad;
  DateTime? loadedAt;

  /// 読み込み中の印（古い読み込みの返事を見分ける）と、始めた時刻。
  Object? loadingToken;
  DateTime? loadingSince;

  /// 読み直しの予約（失敗後の再試行、または期限切れの前の読み直し）。
  Timer? timer;

  Completer<void>? _changed;

  /// 読み込みが終わる（成功・失敗）まで待つ。
  Future<void> changed() => (_changed ??= Completer<void>()).future;

  void notify() {
    final c = _changed;
    _changed = null;
    if (c != null && !c.isCompleted) c.complete();
  }

  /// 続けて読み込みに失敗した回数（読み直しの間隔を伸ばす）。
  int failures = 0;

  bool get ready => ad != null && loadedAt != null && DateTime.now().difference(loadedAt!) < AdMobAdService._maxAge;

  /// 出せる広告を取り出す（取り出したら枠は空になる）。期限切れなら捨てて null。
  T? take() {
    final a = ready ? ad : null;
    if (a != null) {
      ad = null;
      loadedAt = null;
      timer?.cancel();
    } else if (ad != null) {
      // 期限切れ。読み込み中の分は触らない
      ad!.dispose();
      ad = null;
      loadedAt = null;
    }
    return a;
  }

  void clear() {
    timer?.cancel();
    timer = null;
    ad?.dispose();
    ad = null;
    loadedAt = null;
    loadingToken = null;
    loadingSince = null;
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
