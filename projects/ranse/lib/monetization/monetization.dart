import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ad_service.dart';
import 'purchase_service.dart';

/// やり直しを使えるかの答え。
enum RedoGate {
  /// 使ってよい（広告を消した人・動画を見終えた）。
  granted,

  /// 動画を途中で閉じた。
  declined,

  /// 動画を読み込めていない（通信なし・在庫切れ）。**タダではやり直させない**。
  unavailable,

  /// 動画はあったが表示に失敗した。**タダではやり直させない**。
  showFailed,
}

/// 広告と「広告を消す」の決まり（2026-11-25 ユーザー決定。projects/ranse/CLAUDE.md の「広告と課金」）。
///
/// - 全画面広告: 人生の終わり（「新たな生を引く」を押したとき）と、章の区切り（30・45・60歳）。
///   前の広告（全画面・動画のどちらでも）から [adGap] あいていなければ出さない。
///   最初の1回の人生（[inFirstLife]）と、広告を消した人には出さない。
/// - 動画広告: 見ると、亡くなった人生を亡くなった年の始めから1度だけやり直せる。読み込めなければやり直させない。
/// - 広告を消す（370円）: 全画面広告が出なくなり、やり直しも動画なしで使える（回数は同じ1度）。
class Monetization extends ChangeNotifier {
  Monetization(
    this._prefs, {
    AdService? ads,
    PurchaseService? store,
    DateTime Function()? clock,
    bool Function()? foreground,
  }) : ads = ads ?? NoOpAdService(),
       store = store ?? NoOpPurchaseService(),
       _clock = clock ?? DateTime.now,
       _fg = foreground;

  /// 広告と広告の間（ユーザー決定 2026-11-25「3分」）。
  static const adGap = Duration(minutes: 3);

  static const _kAdFree = 'ranse.adFree';
  static const _kLastAd = 'ranse.lastAdAt';
  static const _kLives = 'ranse.livesStarted';

  final SharedPreferences _prefs;
  final AdService ads;
  final PurchaseService store;
  final DateTime Function() _clock;
  final bool Function()? _fg;

  bool get adFree => _prefs.getBool(_kAdFree) ?? false;

  bool _started = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    store.onDelivered = (id) async {
      if (id != PurchaseService.removeAdsId) return;
      _deliveries++;
      await _setAdFree();
    };
    store.onRevoked = (id) async {
      if (id != PurchaseService.removeAdsId) return;
      // 家族から共有された分や買い直した分など、ほかに有効な取引が残っていれば広告は戻さない
      final seen = _deliveries;
      if (await store.hasEntitlement() == true || seen != _deliveries) return;
      await _clearAdFree();
    };
    try {
      await store.initialize();
    } catch (_) {
      // ストアの準備に失敗しても、広告は準備する
    }
    // 購入記録との照合を先に済ませる（再インストール後に買った人の端末で広告の準備をしない）
    try {
      // 課金の無い環境（Web 版・テスト）では待ちの上限の時計を置かない（画面のテストに時計が残らないように）
      if (store is NoOpPurchaseService) {
        await _reconcile();
      } else {
        await _reconcile().timeout(const Duration(seconds: 3));
      }
    } catch (_) {}
    if (!adFree) {
      try {
        await ads.initialize();
      } catch (_) {}
    }
  }

  /// 届いた購入の数。照合の最中に購入が届いたら、古い記録での判定を捨てるために使う。
  int _deliveries = 0;

  Future<void> _reconcile() async {
    final seen = _deliveries;
    final e = await store.hasEntitlement();
    if (e == true && !adFree) await _setAdFree();
    if (e == false && adFree && seen == _deliveries) await _clearAdFree();
  }

  Future<void> _clearAdFree() async {
    if (!adFree) return;
    await _prefs.setBool(_kAdFree, false);
    // 戻ってすぐに全画面広告が出ないよう、間隔は今から数える
    await _markAd();
    notifyListeners();
    try {
      await ads.initialize();
    } catch (_) {}
  }

  Future<void> _setAdFree() async {
    // 読み込み済みの広告と、電波が無いときの読み直しを止める
    if (!adFree) ads.dispose();
    await _prefs.setBool(_kAdFree, true);
    notifyListeners();
  }

  /// アプリが前面に戻ったときに呼ぶ。期限切れの広告を読み直す。
  void refreshAds() {
    if (!adFree) ads.ensureLoaded();
  }

  // ---------- 人生の数え ----------

  /// 新しい人生を始めたときに呼ぶ（やり直しは数えない）。
  /// [finishedBefore] は、この版より前に遊んだ人の「これまでの人生」の数（初めの人生とみなさないため）。
  Future<void> noteLifeStarted({int finishedBefore = 0}) async {
    final n = _prefs.getInt(_kLives) ?? 0;
    final base = n < finishedBefore ? finishedBefore : n;
    await _prefs.setInt(_kLives, base + 1);
  }

  /// いま遊んでいる（または終えたばかりの）人生が、最初の1回の人生か。
  bool get inFirstLife => (_prefs.getInt(_kLives) ?? 0) <= 1;

  // ---------- 全画面広告 ----------

  DateTime? get _lastAd {
    final ms = _prefs.getInt(_kLastAd);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> _markAd() =>
      _prefs.setInt(_kLastAd, _clock().millisecondsSinceEpoch);

  /// 前の広告から [adGap] があいているか（時計を戻されたときは、あいていないとみなす）。
  bool get _gapOk {
    final last = _lastAd;
    if (last == null) return true;
    final d = _clock().difference(last);
    return !d.isNegative && d >= adGap;
  }

  /// いま全画面広告を出す番か（在庫は見ない）。
  bool get interstitialTurn => !adFree && !inFirstLife && _gapOk;

  /// 出す番が近いときに呼ぶ（人生が終わった・章の年に入った）。在庫が無ければ読み込みを始める。
  void prepareInterstitial() {
    if (interstitialTurn && !ads.isInterstitialReady) ads.ensureLoaded();
  }

  /// 人生の終わり・章の区切りで呼ぶ。出す番なら全画面広告を出し、閉じるまで待つ。
  /// 在庫が無ければ待たずに戻る（進行を止めない）。出せたら true。
  Future<bool> maybeInterstitial() async {
    if (!interstitialTurn || !_foreground) return false;
    if (!ads.isInterstitialReady) {
      ads.ensureLoaded();
      return false;
    }
    // 出す前に時刻を残す（広告の途中で終了されても、次ですぐ続けて出ないように）
    final before = _prefs.getInt(_kLastAd);
    await _markAd();
    final shown = await ads.showInterstitialAd();
    if (!shown) {
      if (before == null) {
        await _prefs.remove(_kLastAd);
      } else {
        await _prefs.setInt(_kLastAd, before);
      }
    }
    return shown;
  }

  // ---------- やり直しの動画 ----------

  /// やり直しの前に呼ぶ。広告を消した人はそのまま、それ以外は動画を1本見てもらう。
  /// 動画を読み込み中なら少しだけ待つ（[onWaiting] で「読み込み中」を出せる）。
  Future<RedoGate> beforeRedo({void Function()? onWaiting}) async {
    if (adFree) return RedoGate.granted;
    if (!ads.isRewardedAdReady) {
      ads.ensureLoaded();
      onWaiting?.call();
      if (!await ads.waitForRewarded(const Duration(seconds: 6))) {
        return adFree ? RedoGate.granted : RedoGate.unavailable;
      }
    }
    // 待っている間にアプリを裏へ回したなら出さない（戻った瞬間に広告を差し込まない）
    if (!_foreground) return RedoGate.unavailable;
    final r = await ads.showRewardedAd();
    // 動画を見ている間に「広告を消す」が届いた（家族の承認など）なら、そのままやり直せる
    if (adFree) return RedoGate.granted;
    if (r == RewardResult.earned || r == RewardResult.closedEarly) {
      // 動画を出したので、すぐあとに全画面広告を重ねない
      await _markAd();
    }
    return switch (r) {
      RewardResult.earned => RedoGate.granted,
      RewardResult.closedEarly => RedoGate.declined,
      RewardResult.unavailable => RedoGate.unavailable,
      RewardResult.showFailed => RedoGate.showFailed,
    };
  }

  /// やり直しのボタンに「動画」の印を付けるか。
  bool get redoNeedsAd => !adFree;

  bool get _foreground {
    final f = _fg;
    if (f != null) return f();
    try {
      return (WidgetsBinding.instance.lifecycleState ??
              AppLifecycleState.resumed) ==
          AppLifecycleState.resumed;
    } catch (_) {
      return true; // 画面の仕組みが無い所（単体テスト）
    }
  }

  // ---------- 購入 ----------

  Future<bool> get canBuy async => !adFree && await store.isAvailable();
  Future<String?> get price => store.priceLabel();

  Future<PurchaseOutcome> buy() async {
    final r = await store.buyRemoveAds();
    // 届いた時点で onDelivered が adFree にしているが、念のためここでも立てる
    if (r == PurchaseOutcome.purchased) await _setAdFree();
    return r;
  }

  Future<PurchaseOutcome> restore() async {
    final r = await store.restore();
    if (r == PurchaseOutcome.purchased) await _setAdFree();
    return r;
  }
}
