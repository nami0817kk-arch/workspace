import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../monetization/monetization.dart';
import '../monetization/purchase_service.dart';

/// ゲーム本体（WebView の中の JS）の保存先。端末の SharedPreferences に「web:」を付けて置く。
///
/// WebView の localStorage は消えることがあるので使わない。ゲームは起動のときに
/// [snapshot] を受け取り、書くたびに [set] を呼ぶ（JS 側の TStore）。
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

/// ページの `<head>` の直後に、起動のときの値（保存データ・持っている課金アイテム）を埋め込む。
/// `</script>` で閉じられないよう、`</` は `<\/` にしてから入れる。
String injectBoot(String html, Map<String, Object?> boot) {
  final json = jsonEncode(boot).replaceAll('</', r'<\/');
  const head = '<head>';
  final i = html.indexOf(head);
  final tag = '<script>window.__TSURU_APP=$json;</script>';
  if (i < 0) return tag + html;
  return html.substring(0, i + head.length) + tag + html.substring(i + head.length);
}

/// ゲーム本体から届く頼みごとを受けて、広告・課金・保存・外部リンクにつなぐ。
///
/// 届く形は JSON 1つ: `{"type": "reward"|"store"|"buy"|"restore"|"open"|"licenses"|"haptic"|"review"|"theme"|"bgm"|"notifAsk"|"notifCap", ...}`。
/// 返事は JS の関数を呼んで返す（`tsuruAdResult` / `tsuruSetApp`）。全画面広告は出さない（2026-10-03 の決まり）。
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
    this.bgm,
    this.notifAsk,
    this.notifCap,
  });

  final Monetization money;
  final WebStore store;
  final Future<void> Function(String js) runJs;
  final Future<void> Function(Uri url) openUrl;
  final void Function() showLicenses;

  /// 振動（`light` / `success` / `heavy`）。ゲームの設定で切ってあれば、そもそも届かない
  final void Function(String kind)? haptic;

  /// レビューのお願い（出すかどうか・回数は iOS が決める）
  final Future<void> Function()? review;

  /// 画面の明るさ（上の帯の文字色を合わせる）
  final void Function(bool dark)? theme;

  /// BGM（場面の曲の名前と音量 0〜1。名前が null なら止める）
  final void Function(String? key, double vol)? bgm;

  /// 通知の許可を聞く（初めて留守から戻ったときにゲームが頼む）
  final Future<void> Function()? notifAsk;

  /// 留守の上限（時間）。裏に回るときの通知の予約に使う
  final void Function(double hours)? notifCap;

  /// 鳴らしてよい BGM（tool/make_bgm.py の TRACKS と同じ）
  static const bgmKeys = {'surface', 'mine', 'deep'};

  bool _rewardBusy = false;

  /// 開いてよい外部ページ（プライバシーポリシーと問い合わせ先）。それ以外は開かない。
  static const allowedHosts = {'tsuruhashi.dailyquarry.com'};

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
      case 'buy':
        final id = PurchaseService.idOf('${m['id']}');
        if (id != null) await _buy(id);
      case 'restore':
        await _restore();
      case 'open':
        final u = Uri.tryParse('${m['url']}');
        if (u != null && u.scheme == 'https' && allowedHosts.contains(u.host)) await openUrl(u);
      case 'licenses':
        showLicenses();
      case 'haptic':
        final k = m['k'];
        if (k is String && const {'light', 'success', 'heavy'}.contains(k)) haptic?.call(k);
      case 'review':
        await review?.call();
      case 'theme':
        final d = m['dark'];
        if (d is bool) theme?.call(d);
      case 'bgm':
        final k = m['k'];
        final v = m['vol'];
        if (k == null || (k is String && bgmKeys.contains(k))) {
          bgm?.call(k as String?, v is num ? v.toDouble().clamp(0.0, 1.0) : 0.33);
        }
      case 'notifAsk':
        await notifAsk?.call();
      case 'notifCap':
        final h = m['h'];
        if (h is num && h > 0 && h <= 48) notifCap?.call(h.toDouble());
    }
  }

  /// 動画を見せて、見終えたかを返す。**ゲーム側は返事を受けてから特典を渡す**
  /// （返事は画面がどこにあっても届く。ゲーム本体の待ち手は消えない）。
  Future<void> _reward() async {
    if (_rewardBusy) return;
    _rewardBusy = true;
    try {
      final g = await money.beforeReward(onWaiting: () => unawaited(runJs('window.tsuruAdWaiting&&tsuruAdWaiting()')));
      final msg = switch (g) {
        RewardGate.granted => null,
        RewardGate.declined => '動画を最後まで見ると使えます',
        RewardGate.unavailable => '動画を読み込めませんでした。少し待ってからもう一度お試しください',
        RewardGate.showFailed => '動画を表示できませんでした。画面を全体表示にしてお試しください',
      };
      await runJs('window.tsuruAdResult&&tsuruAdResult(${g == RewardGate.granted},${jsonEncode(msg)})');
    } finally {
      _rewardBusy = false;
    }
  }

  Future<void> _buy(String id) async {
    final r = await money.buy(id);
    await pushApp(msg: switch (r) {
      // 特製弁当はゲーム本体が「届きました」を出すので、ここでは買い切りのときだけ言う
      PurchaseOutcome.purchased => PurchaseService.permanent.contains(id) ? 'お買い上げありがとうございます。効果はすぐに付きます' : null,
      PurchaseOutcome.pending => '保護者の承認を待っています。承認されると届きます',
      PurchaseOutcome.canceled => null,
      PurchaseOutcome.unavailable => 'ストアに接続できませんでした',
      PurchaseOutcome.failed => '購入できませんでした',
    });
  }

  Future<void> _restore() async {
    final r = await money.restore();
    await pushApp(msg: r == PurchaseOutcome.purchased ? '購入を復元しました' : '復元できる購入が見つかりませんでした');
  }

  /// 持っている買い切り・届いた弁当の合計・価格をゲーム本体に伝える（購入が後から届いたときにも呼ぶ）。
  Future<void> pushApp({String? msg}) async {
    final s = await appState();
    if (msg != null) s['msg'] = msg;
    await runJs('window.tsuruSetApp&&tsuruSetApp(${jsonEncode(s)})');
  }

  Future<Map<String, Object?>> appState() async {
    var prices = const <String, String>{};
    var canBuy = false;
    try {
      prices = await money.prices.timeout(const Duration(seconds: 3));
      canBuy = await money.canBuy.timeout(const Duration(seconds: 3));
    } catch (_) {}
    return {...bootState(money), 'prices': prices, 'canBuy': canBuy};
  }

  /// 起動のときにも埋め込む、待たずに分かる値。
  static Map<String, Object?> bootState(Monetization money) => {
    'owned': money.owned,
    'got': {'bento': money.bentoTotal},
  };
}
