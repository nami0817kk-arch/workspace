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
  Future<void> showInterstitial();

  void dispose();
}

/// 広告を扱わない実装。Web 版・テスト・広告を消した構成で使う。
class NoAdService implements AdService {
  @override
  Future<void> initialize() async {}

  @override
  bool get isInterstitialReady => false;

  @override
  Future<void> showInterstitial() async {}

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
  bool _loading = false;

  @override
  Future<void> initialize() async {
    await MobileAds.instance.initialize();
    unawaited(_load());
  }

  Future<void> _load() async {
    if (_loading || _ad != null) return;
    _loading = true;
    try {
      await InterstitialAd.load(
        adUnitId: _unitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _ad = ad;
            _loading = false;
          },
          // 読み込み失敗は珍しくない（在庫切れ・通信断）。例外にせず、
          // 次に必要になったときに読み直す。
          onAdFailedToLoad: (error) {
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
  bool get isInterstitialReady => _ad != null;

  @override
  Future<void> showInterstitial() async {
    final ad = _ad;
    if (ad == null) {
      unawaited(_load());
      return;
    }
    _ad = null;

    // **閉じられるまで待つ。** 待たないと、広告の裏で次のシーズンの
    // 画面が動き出す。
    final closed = Completer<void>();
    void finish(Ad ad) {
      ad.dispose();
      unawaited(_load()); // 次のシーズンのために先読みする
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
