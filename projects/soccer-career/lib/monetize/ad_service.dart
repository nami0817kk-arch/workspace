import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// 広告の読み込みと表示。
///
/// **このゲームが出すのは全画面広告（インタースティシャル）1種類だけ。**
/// シーズンの切れ目にだけ出る。リワード広告は置いていない——見返りに
/// 渡せるものが「金」か「伸びしろ」しかなく、どちらも
/// `balance_sim` で測って調整してきたものだから（CLAUDE.md の
/// 「金は資源であって点数ではない」）。広告で強くなれるなら、
/// あの調整は意味を失う。
///
/// 実装を差し替えられるようにしてあるのは、広告SDKが Android/iOS でしか
/// 動かないため。**Web 版・テストでは何もしない実装**を使う。
abstract class AdService {
  Future<void> initialize();

  /// 出せる広告が手元にあるか。
  bool get isInterstitialReady;

  /// 全画面広告を出し、閉じられるまで待つ。
  /// 在庫が無いときは何もせずに戻る（広告のために進行を止めない）。
  ///
  /// **実際に出せたかどうかを返す。** 返さないと、在庫が無くて何も
  /// 起きなかった回まで「出した」ことになり、次の機会が潰れる。
  Future<bool> showInterstitial();

  void dispose();
}

/// 広告を扱わない実装。Web 版・テスト・広告を消した構成で使う。
class NoAdService implements AdService {
  @override
  Future<void> initialize() async {}

  @override
  bool get isInterstitialReady => false;

  @override
  Future<bool> showInterstitial() async => false;

  @override
  void dispose() {}
}

/// AdMob を使う実装。
///
/// 広告ユニットIDは `--dart-define` で渡す。**既定値は Google が公開している
/// テスト用ID**にしてある。自分のIDを設定し忘れたまま配信しても、本物の
/// 広告が出ず規約違反にならないようにするため。
///
///     flutter build ipa --release \
///       --dart-define=ADMOB_INTERSTITIAL_IOS=ca-app-pub-xxx/yyy
class AdMobAdService implements AdService {
  static const String _iosUnitId = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_IOS',
    defaultValue: 'ca-app-pub-3940256099942544/4411468910',
  );
  static const String _androidUnitId = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_ANDROID',
    defaultValue: 'ca-app-pub-3940256099942544/1033173712',
  );

  /// Google のテスト用IDの先頭。設定画面に警告を出すために見る。
  static const String testUnitIdPrefix = 'ca-app-pub-3940256099942544';

  /// **いま動いているプラットフォームのIDだけを見る。**
  /// 両方を見ると、iOS ビルドでは Android 用の `--dart-define` が渡らず
  /// テストIDのまま残るので、iOS を正しく渡していても警告が出る
  /// （`soccer-manager` で実際に出た）。
  static bool get isUsingTestUnitId {
    if (kIsWeb) return false;
    return (isIOS ? _iosUnitId : _androidUnitId).startsWith(testUnitIdPrefix);
  }

  /// `Platform` は Web で参照できない。手前で `kIsWeb` を見ること。
  static bool get isIOS {
    try {
      return Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  static String get _unitId => isIOS ? _iosUnitId : _androidUnitId;

  InterstitialAd? _ad;
  DateTime? _loadedAt;
  Completer<void>? _pendingLoad;

  /// 読み込んだ広告が使える時間。
  ///
  /// **AdMob の広告は1時間で期限切れになる。** 公式が「キャッシュを捨てて
  /// 1時間ごとに読み直せ」と書いている。持ったままにしていると、読んだ広告を
  /// 何時間でも「準備できている」と扱い、いざ出そうとして失敗する。
  /// `soccer-manager` はこれで、実測7日のリクエスト231回に対して表示6回だった。
  /// https://developers.google.com/admob/android/rewarded
  static const Duration adLifetime = Duration(minutes: 55);

  /// シーズンの切れ目で広告を読むのに待てる時間。
  /// これを過ぎたら広告なしで先へ進める（広告のために進行を止めない）。
  static const Duration loadTimeout = Duration(seconds: 5);

  /// 読み込んでから[adLifetime]を過ぎていれば、もう出せない。
  /// 時計を渡せるようにしてあるのは、検査から呼ぶため。
  static bool adExpired(DateTime? loadedAt, {DateTime? now}) =>
      loadedAt == null ||
      (now ?? DateTime.now()).difference(loadedAt) >= adLifetime;

  /// 期限切れの広告を捨てる。**ここで読み直さない**——次に出すのは
  /// 38節先なので、読み直してもまた期限切れになる。
  void _dropIfExpired() {
    if (_ad != null && adExpired(_loadedAt)) {
      _ad!.dispose();
      _ad = null;
      _loadedAt = null;
    }
  }

  @override
  Future<void> initialize() async {
    await MobileAds.instance.initialize();
    // **ここで先読みしない。** 広告が出るのはシーズンの切れ目だけで、
    // 1シーズンは38節ある。起動時に読んでも、出す頃には必ず期限切れに
    // なっている——1シーズンに1回の確実な表示を、そのたびに落とすことになる。
    // 読むのは[showInterstitial]の直前。
  }

  /// 広告が届く（か、届かないと分かる）まで完了しない Future を返す。
  ///
  /// **`InterstitialAd.load` を `await` しても広告は待てない。** あれが返るのは
  /// 「ネイティブ側に読み込みを頼み終えた」時点で、広告そのものは
  /// `onAdLoaded` で後から届く。`await` しただけで在庫を見ると必ず空なので、
  /// 出す直前に読む作りが成り立たなくなる。だから待ち合わせを自分で持つ。
  Future<void> _load() {
    if (_ad != null) return Future<void>.value();
    // すでに読み込み中なら、その待ち合わせに相乗りする（二重に頼まない）。
    final pending = _pendingLoad;
    if (pending != null) return pending.future;

    final completer = Completer<void>();
    _pendingLoad = completer;
    void done() {
      if (_pendingLoad == completer) _pendingLoad = null;
      if (!completer.isCompleted) completer.complete();
    }

    InterstitialAd.load(
      adUnitId: _unitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _loadedAt = DateTime.now();
          done();
        },
        // 読み込み失敗は珍しくない（在庫切れ・通信断）。例外にせず、
        // 次に必要になったときに読み直す。
        onAdFailedToLoad: (error) {
          _ad = null;
          _loadedAt = null;
          done();
        },
      ),
    ).catchError((Object _) {
      _ad = null;
      _loadedAt = null;
      done();
    });
    return completer.future;
  }

  @override
  bool get isInterstitialReady {
    _dropIfExpired();
    return _ad != null;
  }

  @override
  Future<bool> showInterstitial() async {
    _dropIfExpired();
    if (_ad == null) {
      // **出す直前に読む。** シーズンの切れ目は集計の後なので、ここで
      // 数秒は待てる。読めなければ広告なしで先へ進める。
      await _load().timeout(loadTimeout, onTimeout: () {});
    }
    final ad = _ad;
    if (ad == null) return false;
    _ad = null;
    _loadedAt = null;

    // **閉じられるまで待つ。** 待たないと、広告の裏で次のシーズンの
    // 画面が動き出す。
    final closed = Completer<void>();
    void finish(Ad ad) {
      ad.dispose();
      // 次のシーズンは38節先。ここで読んでも期限切れになるので読まない。
      if (!closed.isCompleted) closed.complete();
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: finish,
      onAdFailedToShowFullScreenContent: (ad, _) => finish(ad),
    );
    await ad.show();
    await closed.future;
    return true;
  }

  @override
  void dispose() {
    _ad?.dispose();
    _ad = null;
    _loadedAt = null;
  }
}

/// この端末で使う実装を選ぶ。
///
/// 広告SDKは Android/iOS 以外では動かないので、それ以外では何もしない
/// 実装を返す。**Web 版に広告は出ない。**
AdService createAdService() {
  if (kIsWeb) return NoAdService();
  try {
    if (Platform.isAndroid || Platform.isIOS) return AdMobAdService();
  } catch (_) {
    // テスト環境など、Platform を参照できない場合。
  }
  return NoAdService();
}
