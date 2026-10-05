import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../monetization/monetization.dart';
import '../monetization/purchase_service.dart';

/// ゲーム本体（WebView の中の JS）の保存先。端末の SharedPreferences に「web:」を付けて置く。
///
/// WebView の localStorage は消えることがあるので使わない。ゲームは起動のときに
/// [snapshot] を受け取り（`window.__TENBIN_APP.store`）、書くたびに `store` の頼みを送る。
class WebStore {
  WebStore(this._prefs);
  final SharedPreferences _prefs;
  static const prefix = 'web:';

  Map<String, String> snapshot() => {
    for (final k in _prefs.getKeys())
      if (k.startsWith(prefix) && _prefs.getString(k) != null) k.substring(prefix.length): _prefs.getString(k)!,
  };

  Future<void> set(String key, String? value) =>
      value == null ? _prefs.remove(prefix + key) : _prefs.setString(prefix + key, value);
}

/// ページの `<head>` の直後に、起動のときの値（保存データ・広告を消したか）を埋め込む。
/// `</script>` で閉じられないよう、`</` は `<\/` にしてから入れる。
String injectBoot(String html, Map<String, Object?> boot) {
  final json = jsonEncode(boot).replaceAll('</', r'<\/');
  const head = '<head>';
  final i = html.indexOf(head);
  final tag = '<script>window.__TENBIN_APP=$json;</script>';
  if (i < 0) return tag + html;
  return html.substring(0, i + head.length) + tag + html.substring(i + head.length);
}

/// ゲーム本体から届く頼みごとを受けて、広告・課金・保存・外部リンクにつなぐ。
///
/// 届く形は JSON 1つ: `{"type": "store"|"reward"|"rewardCancel"|"between"|"prepInter"|"refresh"|"buy"|"restore"|"open"|"licenses"|"haptic"|"share"|"review", ...}`。
/// 返事は JS の関数を呼んで返す（prototype/monetization.js の `tenbinAdWaiting` / `tenbinAdResult` / `tenbinBetweenDone` / `tenbinSetApp`）。
/// 動画の頼みには番号（id）が付き、返事にも同じ番号を付ける（「やめる」の後に届いた結果を、別の特典に入れないため）。
class GameBridge {
  GameBridge({
    required this.money,
    required this.store,
    required this.runJs,
    required this.openUrl,
    required this.showLicenses,
    this.haptic,
    this.share,
    this.review,
  });

  final Monetization money;
  final WebStore store;
  final Future<void> Function(String js) runJs;
  final Future<void> Function(Uri url) openUrl;
  final void Function() showLicenses;

  /// 振動（`light` / `success` / `warn`）
  final void Function(String kind)? haptic;

  /// 結果をシェア（共有シート）
  final Future<void> Function(String text)? share;

  /// レビューのお願い（出すかどうか・回数は iOS が決める）
  final Future<void> Function()? review;

  bool _rewardBusy = false;

  /// ゲームで「やめる」が押された動画の番号。
  final _canceled = <Object?>{};

  /// 開いてよい外部ページ（プライバシーポリシーと問い合わせ先）。それ以外は開かない。
  static const allowedHosts = {'mojitsumi.pages.dev'};

  Future<void> handle(String raw) async {
    Map<String, Object?> m;
    try {
      m = (jsonDecode(raw) as Map).cast<String, Object?>();
    } catch (_) {
      return;
    }
    switch (m['type']) {
      case 'store':
        final k = m['k'];
        final v = m['v'];
        if (k is String && (v == null || v is String)) await store.set(k, v as String?);
      case 'reward':
        await _reward(m['id']);
      case 'rewardCancel':
        _canceled.add(m['id']);
      case 'between':
        var shown = false;
        try {
          shown = await money.betweenGames();
        } catch (_) {
          shown = false;
        } finally {
          // 広告を閉じてから次を始める（出さなかったときもすぐ返す）
          await runJs('window.tenbinBetweenDone&&tenbinBetweenDone($shown)');
        }
      case 'prepInter':
        money.prepareInterstitial();
      case 'refresh':
        money.refreshAds();
        await pushApp();
      case 'buy':
        await _buy();
      case 'restore':
        await _restore();
      case 'open':
        final u = Uri.tryParse('${m['url']}');
        if (u != null && u.scheme == 'https' && allowedHosts.contains(u.host)) await openUrl(u);
      case 'licenses':
        showLicenses();
      case 'haptic':
        final k = m['k'];
        if (k is String && const {'light', 'success', 'warn'}.contains(k)) haptic?.call(k);
      case 'share':
        final t = m['text'];
        if (t is String && t.isNotEmpty && t.length <= 500) await share?.call(t);
      case 'review':
        await review?.call();
    }
  }

  /// 動画を見せて、見終えたかを返す。**ゲーム側は返事を受けてから特典を渡す**
  /// （返事は画面がどこにあっても届く。ゲーム本体の待ち手は消えない。docs/app-pitfalls.md 2番）。
  Future<void> _reward(Object? id) async {
    final idJs = jsonEncode(id is num ? id : null);
    if (_rewardBusy) {
      // 前の動画をまだ扱っている。黙って捨てず、この頼みには「使えなかった」と返す
      await runJs("tenbinAdResult('unavailable',$idJs)");
      return;
    }
    _rewardBusy = true;
    try {
      final g = await money.beforeReward(
        onWaiting: () => unawaited(runJs('window.tenbinAdWaiting&&tenbinAdWaiting()')),
        canceled: () => _canceled.contains(id),
      );
      await runJs("tenbinAdResult('${g.name}',$idJs)");
    } finally {
      _canceled.remove(id);
      _rewardBusy = false;
    }
  }

  Future<void> _buy() async {
    final r = await money.buy();
    await pushApp(msg: switch (r) {
      PurchaseOutcome.purchased => '広告を消しました。ありがとうございます',
      PurchaseOutcome.pending => '保護者の承認を待っています。承認されると広告が消えます',
      PurchaseOutcome.timedOut => '購入の結果がまだ届いていません。届きしだい自動で広告が消えます',
      PurchaseOutcome.canceled => null,
      PurchaseOutcome.unavailable => 'ストアに接続できませんでした',
      PurchaseOutcome.failed => '購入できませんでした',
    });
  }

  Future<void> _restore() async {
    final r = await money.restore();
    await pushApp(msg: r == PurchaseOutcome.purchased || money.adFree ? '購入を復元しました' : '復元できる購入が見つかりませんでした');
  }

  /// 広告を消したか・価格をゲーム本体に伝える（購入が後から届いたときにも呼ぶ）。
  Future<void> pushApp({String? msg}) async {
    final s = await appState();
    if (msg != null) s['msg'] = msg;
    await runJs('window.tenbinSetApp&&tenbinSetApp(${jsonEncode(s)})');
  }

  Future<Map<String, Object?>> appState() async {
    // 1つ取れなくても、ほかは渡す（まとめて try にすると、1つの失敗で全部が消える）
    Future<T?> get<T>(Future<T?> f) async {
      try {
        return await f.timeout(const Duration(seconds: 3));
      } catch (_) {
        return null;
      }
    }

    return {
      'adFree': money.adFree,
      'price': await get<String>(money.price),
      'canBuy': await get<bool>(money.canBuy) ?? false,
    };
  }
}
