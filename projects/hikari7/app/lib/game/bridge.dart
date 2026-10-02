import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../monetization/monetization.dart';
import '../monetization/purchase_service.dart';

/// ゲーム本体（WebView の中の JS）の保存先。端末の SharedPreferences に「web:」を付けて置く。
///
/// WebView の localStorage は消えることがあるので使わない。ゲームは起動のときに
/// [snapshot] を受け取り、書くたびに [set] を呼ぶ（JS 側の HStore）。
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
  final tag = '<script>window.__HIKARI_APP=$json;</script>';
  if (i < 0) return tag + html;
  return html.substring(0, i + head.length) + tag + html.substring(i + head.length);
}

/// ゲーム本体から届く頼みごとを受けて、広告・課金・保存・外部リンクにつなぐ。
///
/// 届く形は JSON 1つ: `{"type": "reward"|"between"|"store"|"buy"|"restore"|"open"|"licenses"|"haptic"|"review"|"theme", ...}`。
/// 返事は JS の関数を呼んで返す（`hikariAdResult` / `hikariSetApp`）。
class GameBridge {
  GameBridge({
    required this.money,
    required this.store,
    required this.runJs,
    required this.openUrl,
    required this.showLicenses,
    this.haptic,
    this.review,
    this.theme,
  });

  final Monetization money;
  final WebStore store;
  final Future<void> Function(String js) runJs;
  final Future<void> Function(Uri url) openUrl;
  final void Function() showLicenses;

  /// 振動（`light` / `success` / `warn`）。ゲームの設定で切ってあれば、そもそも届かない
  final void Function(String kind)? haptic;

  /// レビューのお願い（出すかどうか・回数は iOS が決める）
  final Future<void> Function()? review;

  /// 画面の明るさ（上の帯の文字色を合わせる）
  final void Function(bool dark)? theme;

  bool _rewardBusy = false;

  /// 開いてよい外部ページ（プライバシーポリシーと問い合わせ先）。それ以外は開かない。
  static const allowedHosts = {'hikari7.pages.dev'};

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
        if (k is String) await store.set(k, m['v'] as String?);
      case 'reward':
        await _reward();
      case 'between':
        await money.betweenRounds((m['rnd'] as num?)?.toInt() ?? 0);
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
      case 'review':
        await review?.call();
      case 'theme':
        final d = m['dark'];
        if (d is bool) theme?.call(d);
    }
  }

  /// 動画を見せて、見終えたかを返す。**ゲーム側は返事を受けてから特典を渡す**
  /// （返事は画面がどこにあっても届く。ゲーム本体の待ち手は消えない）。
  Future<void> _reward() async {
    if (_rewardBusy) return;
    _rewardBusy = true;
    try {
      final g = await money.beforeReward(onWaiting: () => unawaited(runJs('window.hikariAdWaiting&&hikariAdWaiting()')));
      final msg = switch (g) {
        RewardGate.granted => null,
        RewardGate.declined => '動画を最後まで見ると使えます',
        RewardGate.unavailable => '動画を読み込めませんでした。少し待ってからもう一度お試しください',
        RewardGate.showFailed => '動画を表示できませんでした。画面を全体表示にしてお試しください',
      };
      await runJs('hikariAdResult(${g == RewardGate.granted},${jsonEncode(msg)})');
    } finally {
      _rewardBusy = false;
    }
  }

  Future<void> _buy() async {
    final r = await money.buy();
    await pushApp(msg: switch (r) {
      PurchaseOutcome.purchased => '広告を消しました。ありがとうございます',
      PurchaseOutcome.pending => '保護者の承認を待っています。承認されると広告が消えます',
      PurchaseOutcome.canceled => null,
      PurchaseOutcome.unavailable => 'ストアに接続できませんでした',
      PurchaseOutcome.failed => '購入できませんでした',
    });
  }

  Future<void> _restore() async {
    final r = await money.restore();
    await pushApp(msg: r == PurchaseOutcome.purchased ? '購入を復元しました' : '復元できる購入が見つかりませんでした');
  }

  /// 広告を消したか・価格をゲーム本体に伝える（購入が後から届いたときにも呼ぶ）。
  Future<void> pushApp({String? msg}) async {
    final s = await appState();
    if (msg != null) s['msg'] = msg;
    await runJs('window.hikariSetApp&&hikariSetApp(${jsonEncode(s)})');
  }

  Future<Map<String, Object?>> appState() async {
    String? price;
    var canBuy = false;
    try {
      price = await money.price.timeout(const Duration(seconds: 3));
      canBuy = await money.canBuy.timeout(const Duration(seconds: 3));
    } catch (_) {}
    return {'adFree': money.adFree, 'price': price, 'canBuy': canBuy};
  }
}
