import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'ad_service.dart';
import 'entitlements.dart';
import 'purchase_service.dart';

/// ページ（WebView の中の遊び）と、広告・課金をつなぐ橋。
///
/// ページ → こちら：`YouthApp.postMessage('{"cmd":"buy","id":"..."}')`
///   cmd: hello（起動の挨拶）／ prices（価格の取り直し）／ buy ／ restore ／ useTicket ／ ticketSpent（serials）
///        ／ ad（kind: interstitial か rewarded、tag、reward）／ adPrep（全画面を出す番になった）／ adClaimed（tag）
/// こちら → ページ：`YAnative.onMsg('{"ev":"ent","v":{...}}')`
///   ev: ent（権利）／ prices ／ purchase ／ restore ／ adDone（tag, result, reward）／ adUnclaimed（list）
///
/// 権利を書き込むのはここだけ（ページは読むだけ）。購入は [PurchaseService.onDelivered] で受け取る。
class MonetizationBridge {
  MonetizationBridge({required this.prefs, required this.ads, required this.purchases, required this.send}) {
    ent = Entitlements.load(prefs);
    purchases.onDelivered = _delivered;
    purchases.onRevoked = _revoked;
  }

  final SharedPreferences prefs;
  final AdService ads;
  final PurchaseService purchases;

  /// ページへ送る（JSON 文字列）。ページが開く前は捨ててよい（開いたあと hello で改めて送る）。
  final void Function(String json) send;
  late Entitlements ent;

  /// 見終えたのに、ページがまだ受け取っていないご褒美の控え（ページが読み直されても渡すため）。`ya_` の外に置く。
  static const unclaimedKey = 'ad_unclaimed';

  /// 届いた購入の数。照合の最中に購入が届いたら、古い記録での判定を捨てるために使う。
  int _deliveries = 0;

  void _emit(Map<String, Object?> m) => send(jsonEncode(m));
  void sendEnt() => _emit({'ev': 'ent', 'v': ent.toJson()});

  /// 起動時の準備。購入の受け取りを先に始め（起動時の再送を取りこぼさない）、端末の購入記録と照らし合わせる。
  /// 広告の準備は待たない（広告の SDK が遅くても、購入の受け取りと画面を止めない）。
  Future<void> start() async {
    try {
      await purchases.initialize();
    } catch (_) {}
    try {
      await reconcile().timeout(const Duration(seconds: 3));
    } catch (_) {}
    sendEnt();
    unawaited(_initAds());
  }

  Future<void> _initAds() async {
    try {
      await ads.initialize();
    } catch (_) {}
  }

  /// 端末の購入記録と照らし合わせる（買い切りの2つだけ）。閉じている間に返金された分を戻し、
  /// 入れ直したあとは「購入を復元」を押さなくても戻す。記録が読めなければ何もしない。
  Future<void> reconcile() async {
    for (final id in nonConsumableIds) {
      final seen = _deliveries;
      final e = await purchases.hasEntitlement(id);
      final owned = id == productRemoveAds ? ent.noAds : ent.eye;
      if (e == true && !owned) await ent.grant(prefs, id);
      if (e == false && owned && seen == _deliveries) await ent.revoke(prefs, id);
    }
  }

  // 届いた購入。ページが待っているかどうかに関係なく、権利に書いてからページへ知らせる
  Future<void> _delivered(String productId, String? purchaseId) async {
    _deliveries++;
    await ent.grant(prefs, productId, purchaseId: purchaseId);
    sendEnt();
  }

  Future<void> _revoked(String productId) async {
    // 家族から共有された分や買い直した分など、ほかに有効な取引が残っていれば戻さない
    final seen = _deliveries;
    if (await purchases.hasEntitlement(productId) == true || seen != _deliveries) return;
    await ent.revoke(prefs, productId);
    sendEnt();
  }

  /// 上限に達していて、買っても増えない商品か（お金だけ取られないように）。
  bool atLimit(String id) => switch (id) {
    productSaveSlot => ent.slots >= Entitlements.maxSlots,
    productTicket1 => ent.tickets + 1 > Entitlements.maxTickets,
    productTicket3 => ent.tickets + 3 > Entitlements.maxTickets,
    productRemoveAds => ent.noAds,
    productKeenEye => ent.eye,
    _ => false,
  };

  List<Map<String, Object?>> _unclaimed() {
    try {
      final s = prefs.getString(unclaimedKey);
      final l = s == null ? null : jsonDecode(s);
      if (l is! List) return [];
      final now = DateTime.now().millisecondsSinceEpoch;
      // 1週間より古いものは捨てる
      return l.whereType<Map>().map((m) => m.cast<String, Object?>()).where((m) => m['at'] is num && now - (m['at'] as num) < 7 * 86400000).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveUnclaimed(List<Map<String, Object?>> l) async {
    await prefs.setString(unclaimedKey, jsonEncode(l.length > 10 ? l.sublist(l.length - 10) : l));
  }

  void _sendPrices() => unawaited(purchases.prices().then((m) => _emit({'ev': 'prices', 'map': m})).catchError((Object _) {}));

  /// ページからの依頼。解釈できなければ false（保存の依頼など、別の用途の文字列かもしれない）。
  Future<bool> handle(String message) async {
    Object? d;
    try {
      d = jsonDecode(message.trim());
    } catch (_) {
      return false;
    }
    if (d is! Map || d['cmd'] is! String) return false;
    switch (d['cmd'] as String) {
      case 'hello':
        sendEnt();
        _sendPrices();
        // 見終えたのに受け取れていないご褒美（読み直しの前に見終えた分）
        final un = _unclaimed();
        if (un.isNotEmpty) _emit({'ev': 'adUnclaimed', 'list': un});
      case 'prices':
        _sendPrices();
      case 'buy':
        final id = d['id'];
        if (id is! String) return true;
        if (atLimit(id)) {
          _emit({'ev': 'purchase', 'id': id, 'outcome': 'limit'});
          return true;
        }
        final r = await purchases.buy(id);
        _emit({'ev': 'purchase', 'id': id, 'outcome': r.name});
        sendEnt();
      case 'restore':
        final r = await purchases.restore();
        _emit({'ev': 'restore', 'outcome': r.name});
        sendEnt();
      case 'useTicket':
        await ent.useTicket(prefs);
        sendEnt();
      case 'ticketSpent':
        final l = d['serials'];
        if (l is List) await ent.markSpent(prefs, l.whereType<num>().map((x) => x.toInt()));
        sendEnt();
      case 'ad':
        final tag = d['tag'] is num ? (d['tag'] as num).toInt() : 0;
        if (d['kind'] == 'rewarded') {
          final reward = d['reward'];
          final result = await showRewarded();
          if (result == RewardResult.earned.name) {
            // ページが受け取りを知らせるまで控えておく（見ている間にページが読み直されても渡せるように）
            final un = _unclaimed()..add({'tag': tag, 'reward': reward, 'at': DateTime.now().millisecondsSinceEpoch});
            try {
              await _saveUnclaimed(un);
            } catch (_) {}
          }
          _emit({'ev': 'adDone', 'tag': tag, 'result': result, 'reward': reward});
        } else if (d['kind'] == 'interstitial') {
          // 広告を消した人には出さない（ページ側でも止めているが、こちらでも確かめる）
          if (!ent.noAds) await ads.showInterstitialAd();
        }
      case 'adPrep':
        // 全画面を出す番になった。広告を消した人の分は読み込みもしない
        if (!ent.noAds) ads.prepareInterstitial();
      case 'adClaimed':
        final tag = d['tag'] is num ? (d['tag'] as num).toInt() : null;
        if (tag != null) {
          final un = _unclaimed()..removeWhere((m) => m['tag'] is num && (m['tag'] as num).toInt() == tag);
          await _saveUnclaimed(un);
        }
      default:
        return false;
    }
    return true;
  }

  /// 動画を見せて結果を返す（earned / closedEarly / unavailable / showFailed）。
  Future<String> showRewarded() async {
    if (!ads.isRewardedAdReady) {
      ads.ensureLoaded();
      if (!await ads.waitForRewarded(const Duration(seconds: 8))) return RewardResult.unavailable.name;
    }
    return (await ads.showRewardedAd()).name;
  }
}
