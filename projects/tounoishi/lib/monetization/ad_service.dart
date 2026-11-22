import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// 全画面広告（インタースティシャル）の読み込みと表示。
///
/// ひかりの指名（projects/hikari7/app）の ad_service.dart から、動画広告（リワード）を外して写したもの。
/// 塔の意志は全画面広告だけを使う（2026-11-22 決定。リワードは入れない）。
/// 広告SDKは iOS でしか動かないので、テストでは何もしない実装を使う。
abstract class AdService {
  Future<void> initialize();

  /// 表示できる全画面広告が手元にあるか。
  bool get isInterstitialReady;

  /// 全画面広告を読み込み始める。**出しそうなときだけ呼ぶ**（起動時から読み続けると、
  /// 表示に対してリクエストばかり増える。docs/app-pitfalls.md 3番）。
  void prepareInterstitial();

  /// 手元に無ければ読み込みを始める（アプリに戻ったとき。期限切れの読み直し）。
  void ensureLoaded();

  /// 全画面広告が読み込み中なら、届くまで最大 [max] 待つ。
  Future<bool> waitForInterstitial(Duration max);

  /// 全画面広告を出し、閉じられるまで待つ。出せたら true。表示が始まったら [onShown] を呼ぶ。
  /// 在庫が無ければ何もせず false で戻る（進行を止めない）。
  Future<bool> showInterstitialAd({void Function()? onShown});

  void dispose();
}

/// 広告を扱わない実装。テスト・iOS 以外で使う。
class NoOpAdService implements AdService {
  @override
  Future<void> initialize() async {}

  @override
  bool get isInterstitialReady => false;

  @override
  void prepareInterstitial() {}

  @override
  void ensureLoaded() {}

  @override
  Future<bool> waitForInterstitial(Duration max) async => false;

  @override
  Future<bool> showInterstitialAd({void Function()? onShown}) async => false;

  @override
  void dispose() {}
}

/// AdMob を使う実装。
///
/// 広告ユニットIDは --dart-define で渡す。既定値は Google が公開している**テスト用ID**。
/// 本物のIDを渡し忘れたまま配信しても、本物の広告が出ず規約違反にならないようにするため。
class AdMobAdService implements AdService {
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

  /// 表示が始まったことが伝わってこない場合の上限（固まらないように）。
  static const _showTimeout = Duration(minutes: 3);

  /// 読み込み中のまま返事が来ないときの上限（これを過ぎたら読み直してよい）。
  static const _loadTimeout = Duration(minutes: 1);

  /// 既定のテスト用IDのままか（リリースの CI で本物に替わっているかを確かめる）。
  static bool get isUsingTestUnitId => _interstitialUnitId.startsWith(_testUnitIdPrefix);

  bool _disposed = false;

  /// 全年齢向けの設定と SDK の準備が済んだか。済むまでは読み込まない（設定の掛かっていない広告を読まないため）。
  bool _initialized = false;

  final _slot = _Slot<InterstitialAd>();

  /// 全画面広告を頼まれているか（ゲームが「この先で出しそう」と言ってから、出し終えるまで）。
  bool _want = false;

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
      // 準備が失敗しても読み込みは試す
    }
    _initialized = true;
    _loadIfWanted();
  }

  @override
  void prepareInterstitial() {
    _want = true;
    _slot.failures = 0;
    _loadIfWanted();
  }

  @override
  void ensureLoaded() {
    _slot.failures = 0;
    _loadIfWanted();
  }

  @override
  Future<bool> waitForInterstitial(Duration max) async {
    if (_slot.ready) return true;
    if (!_initialized || _slot.loadingSince == null) return false;
    try {
      // 読み込みの返事（onAdLoaded / onAdFailedToLoad）は後から届く。Completer で待ち合わせる
      await _slot.changed().timeout(max);
    } on TimeoutException {
      // 間に合わなかった
    }
    return _slot.ready;
  }

  void _loadIfWanted() {
    if (_want) _load();
  }

  /// 読み込みを頼む。**`InterstitialAd.load` は await しない**（返るのは「ネイティブ側に頼み終えた」時点で、
  /// 広告は onAdLoaded で後から届く。docs/app-pitfalls.md 3番）。
  void _load() {
    final slot = _slot;
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
      slot.timer = Timer(wait > _maxRetry ? _maxRetry : wait, _loadIfWanted);
    }

    void loaded(InterstitialAd ad) {
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
      // 期限が切れる前に、次を読み込んでおく
      slot.timer = Timer(_maxAge, () {
        slot.loadedAt = null; // 端末の時計を戻されても、経過時間で必ず読み直す
        _loadIfWanted();
      });
    }

    try {
      InterstitialAd.load(
        adUnitId: _interstitialUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(onAdLoaded: loaded, onAdFailedToLoad: (_) => failed()),
      ).catchError((_) => failed());
    } catch (_) {
      failed();
    }
  }

  @override
  bool get isInterstitialReady => _slot.ready;

  @override
  Future<bool> showInterstitialAd({void Function()? onShown}) async {
    final ad = _slot.take();
    if (ad == null) return false;
    // 出したら、次に頼まれるまで読み込まない
    _want = false;
    final closed = Completer<bool>();
    final started = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback<InterstitialAd>(
      onAdShowedFullScreenContent: (_) {
        if (!started.isCompleted) {
          started.complete();
          onShown?.call();
        }
      },
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        if (!started.isCompleted) started.complete();
        if (!closed.isCompleted) closed.complete(true);
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        a.dispose();
        if (!closed.isCompleted) closed.complete(false);
      },
    );
    try {
      // show は「表示を頼んだ」時点で返る。閉じたかどうかは上の通知で待つ（docs/app-pitfalls.md 9番）
      await ad.show();
    } catch (_) {
      ad.dispose();
      return false;
    }
    // 表示が始まらないまま返事が無いときだけ打ち切る。始まった後は閉じられるまで待つ
    // （待たないと、広告の裏で結果画面や次の階が始まってしまう）
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
  void dispose() {
    _disposed = true;
    _want = false;
    _slot.clear();
    _slot.notify();
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

  bool get ready => ad != null && loadedAt != null && isFresh(loadedAt!, DateTime.now());

  /// 読み込んだ時刻から見て、まだ出せるか（55分を過ぎたら出さない）。
  static bool isFresh(DateTime loadedAt, DateTime now) => now.difference(loadedAt) < AdMobAdService._maxAge;

  /// 出せる広告を取り出す（取り出したら枠は空になる）。期限切れなら捨てて null。
  T? take() {
    final a = ready ? ad : null;
    if (a != null) {
      ad = null;
      loadedAt = null;
      timer?.cancel();
    } else if (ad != null) {
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

/// 期限の判定（テストから見る）。
@visibleForTesting
bool adIsFresh(DateTime loadedAt, DateTime now) => _Slot.isFresh(loadedAt, now);

/// 広告の期限（テストから見る。1時間より短いこと）。
@visibleForTesting
const adLifetime = AdMobAdService._maxAge;

/// この端末で使う実装を選ぶ。iOS 以外（テストなど）では広告を出さない。
AdService createAdService() {
  if (kIsWeb) return NoOpAdService();
  try {
    if (Platform.isIOS) return AdMobAdService();
  } catch (_) {
    // テスト環境など Platform を参照できない場合
  }
  return NoOpAdService();
}
