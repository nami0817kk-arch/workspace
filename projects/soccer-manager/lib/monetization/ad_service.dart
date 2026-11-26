import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// 広告の読み込みと表示。
///
/// 出すのは全画面広告(インタースティシャル)の1種類だけ。ゲームの中で
/// 3か月たつごとに1回出る([MonetizationController.showQuarterlyInterstitial])。
/// 「広告を消す」の購入で出なくなる。
///
/// 自分で選んで見る動画広告(リワード)は 2026-11-26 にやめた。ご褒美の
/// 「次の1節の収入1.5倍」が要らないと決まったため。見られる前から先に
/// 読み込んでいたので、表示率(7日でリクエスト231回に表示6回)を下げる
/// いちばんの原因でもあった。
///
/// 実装を差し替えられるようにしてあるのは、広告SDKがAndroid/iOSでしか
/// 動かないため。Web版・テスト・デスクトップでは何もしない実装を使う。
abstract class AdService {
  Future<void> initialize();

  /// 全画面広告が手元にあるか。
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
///       --dart-define=ADMOB_INTERSTITIAL_ANDROID=ca-app-pub-xxx/zzz
class AdMobAdService implements AdService {
  static const _interstitialAndroidUnitId = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_ANDROID',
    defaultValue: 'ca-app-pub-3940256099942544/1033173712',
  );
  static const _interstitialIosUnitId = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_IOS',
    defaultValue: 'ca-app-pub-3940256099942544/4411468910',
  );

  InterstitialAd? _interstitial;
  DateTime? _interstitialLoadedAt;
  Completer<void>? _pendingInterstitialLoad;

  /// 読み込んだ広告が使える時間。
  ///
  /// **AdMob の広告は1時間で期限切れになる。** 公式が「1時間ごとに捨てて
  /// 読み直せ」と書いている。持ったままにしていたため、起動時に読んだ広告を
  /// 何時間も「準備できている」と扱い、いざ出そうとすると失敗していた。
  /// https://developers.google.com/admob/android/interstitial
  static const Duration adLifetime = Duration(minutes: 55);

  /// 広告を出す場面で読むのに待てる時間。
  /// これを過ぎたら広告なしで先へ進める。
  static const Duration interstitialLoadTimeout = Duration(seconds: 5);

  /// 読み込んでから[adLifetime]を過ぎていれば、もう出せない。
  /// 時計を渡せるようにしてあるのは、検査から呼ぶため。
  static bool adExpired(DateTime? loadedAt, {DateTime? now}) =>
      loadedAt == null ||
      (now ?? DateTime.now()).difference(loadedAt) >= adLifetime;

  /// 期限切れの広告を捨てる。
  void _dropIfExpired() {
    if (_interstitial != null && adExpired(_interstitialLoadedAt)) {
      _interstitial!.dispose();
      _interstitial = null;
      _interstitialLoadedAt = null;
    }
  }

  static String get _interstitialUnitId =>
      _isIOS ? _interstitialIosUnitId : _interstitialAndroidUnitId;

  static const _testUnitIdPrefix = 'ca-app-pub-3940256099942544';

  /// 既定のテスト用IDのままか。設定画面に警告を出すために使う。
  ///
  /// **いま動いているプラットフォームのIDだけを見る。** 両方を見ると、
  /// iOS ビルドでは Android 用の --dart-define が渡らず既定のテストIDのまま
  /// 残るため、iOS のIDを正しく渡していても警告が出てしまう(実際に出た)。
  /// Web版は広告SDKを読み込まないので、判定する意味がない。
  static bool get isUsingTestUnitId {
    if (kIsWeb) return false;
    return _interstitialUnitId.startsWith(_testUnitIdPrefix);
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
    // **起動時には読まない。** 出るのはゲームの中の3か月ごとで、起動して
    // すぐ出すとは限らない。読んで出さずに捨てると、リクエストだけが
    // 数えられて表示率が下がる。出す直前に読む([showInterstitialAd])。
  }

  /// 広告が届く（か、届かないと分かる）まで完了しない Future を返す。
  ///
  /// **`InterstitialAd.load` を `await` しても広告は待てない。** あれが返るのは
  /// 「ネイティブ側に読み込みを頼み終えた」時点（中身は
  /// `channel.invokeMethod('loadInterstitialAd')` ひとつ）で、広告そのものは
  /// `onAdLoaded` で後から届く。`await` した直後に在庫を見ると必ず空なので、
  /// [showInterstitialAd] で「出す直前に読む」作りが成り立たない——待った
  /// つもりで毎回「在庫なし」になる。だから待ち合わせを自分で持つ。
  Future<void> _loadInterstitial() {
    if (_interstitial != null) return Future<void>.value();
    // すでに読み込み中なら、その待ち合わせに相乗りする（二重に頼まない）。
    final pending = _pendingInterstitialLoad;
    if (pending != null) return pending.future;

    final completer = Completer<void>();
    _pendingInterstitialLoad = completer;
    void done() {
      if (_pendingInterstitialLoad == completer) {
        _pendingInterstitialLoad = null;
      }
      if (!completer.isCompleted) completer.complete();
    }

    InterstitialAd.load(
      adUnitId: _interstitialUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitial = ad;
          _interstitialLoadedAt = DateTime.now();
          done();
        },
        onAdFailedToLoad: (error) {
          _interstitial = null;
          _interstitialLoadedAt = null;
          done();
        },
      ),
    ).catchError((Object _) {
      _interstitial = null;
      _interstitialLoadedAt = null;
      done();
    });
    return completer.future;
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
      // **出す直前に読む。** 節を進める処理の後なので、ここで少し待てる。
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

    // 閉じられるまで待たないと、広告の裏で次の画面が動き出してしまう。
    final closed = Completer<void>();
    void finish(Ad ad) {
      ad.dispose();
      // 次に出すのは3か月先なので、ここでは先読みしない(期限切れになる)。
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
