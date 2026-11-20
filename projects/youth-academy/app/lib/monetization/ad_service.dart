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

  /// 手元に無ければ動画の読み込みを始める（読み込み失敗の後、次に使うときのため）。
  void ensureLoaded();

  /// 全画面広告を出す番になったら呼ぶ。出す直前に読み込む（起動時からは読まない。docs/app-pitfalls.md 3番）。
  void prepareInterstitial();

  /// 動画を見せる。閉じられるまで待つ。
  Future<RewardResult> showRewardedAd();

  /// 全画面広告を出し、閉じられるまで待つ。出せたら true。
  /// 手元に無ければ数秒だけ読み込みを待ち、それでも無ければ何もせず false で戻る（進行を止めない）。
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
  void prepareInterstitial() {}

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
  static const maxAge = Duration(minutes: 55);

  /// 読み込んだ時刻 [loadedAt] の広告が、いま [now] まだ出せるか（未読み込みは false）。
  static bool isFresh(DateTime? loadedAt, DateTime now) => loadedAt != null && now.difference(loadedAt) < maxAge;

  /// 全画面広告を出す直前に、読み込みを待つ上限。
  static const _interstitialWait = Duration(seconds: 3);

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
  final _ready = Completer<void>();

  final _rewardedSlot = _Slot<RewardedAd>();
  final _interstitialSlot = _Slot<InterstitialAd>();

  @override
  Future<void> initialize() async {
    // 広告を消した後に返金されたときは、もう一度ここから始める
    _disposed = false;
    // 広告の中身は全年齢向け（G）まで。4+ のアプリに合わない広告を出さない（Apple 2.5.18）
    try {
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(maxAdContentRating: MaxAdContentRating.g),
      );
      await MobileAds.instance.initialize();
    } catch (_) {
      // 準備が失敗しても読み込みは試す（止めたままだと、その起動の間ヒントが一切出せなくなる）
    }
    _initialized = true;
    if (!_ready.isCompleted) _ready.complete();
    // 先読みするのは、利用者が選んで見る動画だけ。全画面は出す番になってから読む
    _loadRewarded();
  }

  void _loadRewarded() => _load(_rewardedSlot, _loadRewarded, (onLoaded, onFailed) {
    return RewardedAd.load(
      adUnitId: _rewardedUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(onAdLoaded: onLoaded, onAdFailedToLoad: onFailed),
    );
  });

  void _loadInterstitial() => _load(_interstitialSlot, _loadInterstitial, keepFresh: false, (onLoaded, onFailed) {
    return InterstitialAd.load(
      adUnitId: _interstitialUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(onAdLoaded: onLoaded, onAdFailedToLoad: onFailed),
    );
  });

  /// 1枠ぶんの読み込み。[keepFresh] なら、失敗したら間を空けて読み直し、読み込めたら期限の少し前に読み直す。
  /// そうでなければ（全画面）一度だけ読み、期限が来たら捨てる（使わない広告を読み続けない）。
  void _load<T extends AdWithoutView>(
    _Slot<T> slot,
    void Function() again,
    Future<void> Function(void Function(T) onLoaded, void Function(LoadAdError) onFailed) start, {
    bool keepFresh = true,
  }) {
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
      if (!keepFresh) return;
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
        slot.timer = Timer(maxAge, () {
          slot.loadedAt = null; // 端末の時計を戻されても、経過時間で必ず読み直す
          if (keepFresh) {
            again();
          } else {
            slot.clear();
          }
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
    final until = DateTime.now().add(max);
    try {
      // 起動直後で SDK の準備がまだなら、それも待つ
      if (!_initialized) await _ready.future.timeout(max);
      _loadRewarded();
      if (_rewardedSlot.ready) return true;
      if (_rewardedSlot.loadingSince == null) return false;
      final left = until.difference(DateTime.now());
      if (left > Duration.zero) await _rewardedSlot.changed().timeout(left);
    } on TimeoutException {
      // 間に合わなかった
    }
    return _rewardedSlot.ready;
  }

  @override
  void ensureLoaded() {
    // 利用者が広告を求めた（アプリに戻った・ヒントを押した）ので、延びていた読み直しの間隔を戻してすぐ読む
    _rewardedSlot.failures = 0;
    _loadRewarded();
  }

  @override
  void prepareInterstitial() {
    _interstitialSlot.failures = 0;
    _loadInterstitial();
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
    final watch = ShowWatch(grace: _rewardGrace, startTimeout: _showTimeout);
    // 閉じた通知では広告を捨てない（捨てた広告の通知はプラグインが握りつぶすので、閉じた後に届く報酬を取りこぼす）
    ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdShowedFullScreenContent: (_) => watch.onShowed(),
      onAdDismissedFullScreenContent: (_) => watch.onDismissed(),
      onAdFailedToShowFullScreenContent: (_, _) => watch.onFailed(),
    );
    final r = await watch.run(() => ad.show(onUserEarnedReward: (_, _) => watch.onEarned()));
    ad.dispose();
    _loadRewarded(); // 見ている間の読み込みに失敗していたときのため
    return r;
  }

  @override
  Future<bool> showInterstitialAd() async {
    if (!_interstitialSlot.ready) {
      prepareInterstitial();
      if (_interstitialSlot.loadingSince != null) {
        try {
          await _interstitialSlot.changed().timeout(_interstitialWait);
        } on TimeoutException {
          // 間に合わなければ出さない
        }
      }
    }
    final ad = _interstitialSlot.take();
    if (ad == null) return false;
    // 閉じられるまで待たないと、広告の裏で次の面が始まってしまう
    final watch = ShowWatch(grace: Duration.zero, startTimeout: _showTimeout);
    ad.fullScreenContentCallback = FullScreenContentCallback<InterstitialAd>(
      onAdShowedFullScreenContent: (_) => watch.onShowed(),
      onAdDismissedFullScreenContent: (_) => watch.onDismissed(),
      onAdFailedToShowFullScreenContent: (_, _) => watch.onFailed(),
    );
    final r = await watch.run(() => ad.show());
    ad.dispose();
    // 次は、また出す番が来てから読む
    return r == RewardResult.closedEarly || r == RewardResult.earned;
  }

  @override
  void dispose() {
    _disposed = true;
    _rewardedSlot.clear();
    _interstitialSlot.clear();
    // 動画を待っている人がいれば起こす（広告を消した直後に6秒待たせない）
    _rewardedSlot.notify();
  }
}

/// 全画面の広告1回ぶんの見終わり待ち（docs/app-pitfalls.md 9番）。
///
/// 広告の show() は「表示を頼んだ」時点ですぐ返り、報酬（[onEarned]）と閉じた（[onDismissed]）・
/// 失敗（[onFailed]）の通知は後から来る。閉じる通知が報酬より先に来ることもあるので、閉じた時点で
/// 報酬が無ければ [grace] だけ待つ。表示が始まらないまま [startTimeout] が過ぎたら打ち切る
/// （始まった後は、広告から App Store へ行って長く戻らなくても閉じられるまで待つ）。
class ShowWatch {
  ShowWatch({required this.grace, required this.startTimeout});
  final Duration grace;
  final Duration startTimeout;
  final _closed = Completer<bool>();
  final _started = Completer<bool>();
  bool _earned = false;

  void onShowed() {
    if (!_started.isCompleted) _started.complete(true);
  }

  void onEarned() => _earned = true;

  void onDismissed() {
    onShowed();
    if (!_closed.isCompleted) _closed.complete(true);
  }

  void onFailed() {
    if (!_started.isCompleted) _started.complete(true);
    if (!_closed.isCompleted) _closed.complete(false);
  }

  Future<RewardResult> run(Future<void> Function() show) async {
    try {
      await show();
    } catch (_) {
      return RewardResult.showFailed;
    }
    final t = Timer(startTimeout, () {
      if (!_started.isCompleted) _started.complete(false);
    });
    final began = await _started.future;
    t.cancel();
    if (!began) return RewardResult.showFailed;
    final shown = await _closed.future;
    if (shown && !_earned && grace > Duration.zero) await Future<void>.delayed(grace);
    if (_earned) return RewardResult.earned;
    return shown ? RewardResult.closedEarly : RewardResult.showFailed;
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

  bool get ready => ad != null && AdMobAdService.isFresh(loadedAt, DateTime.now());

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
