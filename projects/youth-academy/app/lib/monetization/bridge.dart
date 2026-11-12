import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'ad_service.dart';
import 'entitlements.dart';
import 'purchase_service.dart';

/// ページ（WebView の中の遊び）と、広告・課金をつなぐ橋。
///
/// ページ → こちら：`YouthApp.postMessage('{"cmd":"buy","id":"..."}')`
///   cmd: hello（起動の挨拶）／ buy ／ restore ／ useTicket ／ ad（kind: interstitial か rewarded、tag）
/// こちら → ページ：`YAnative.onMsg('{"ev":"ent","v":{...}}')`
///   ev: ent（権利）／ prices ／ purchase ／ restore ／ adDone（tag, result）
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

  void _emit(Map<String, Object?> m) => send(jsonEncode(m));
  void sendEnt() => _emit({'ev': 'ent', 'v': ent.toJson()});

  Future<void> start() async {
    await ads.initialize();
    await purchases.initialize();
  }

  // 届いた購入。ページが待っているかどうかに関係なく、権利に書いてからページへ知らせる
  Future<void> _delivered(String productId, String? purchaseId) async {
    await ent.grant(prefs, productId, purchaseId: purchaseId);
    sendEnt();
  }

  Future<void> _revoked(String productId) async {
    await ent.revoke(prefs, productId);
    sendEnt();
  }

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
        unawaited(purchases.prices().then((m) => _emit({'ev': 'prices', 'map': m})));
      case 'buy':
        final id = d['id'];
        if (id is! String) return true;
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
      case 'ad':
        final tag = d['tag'] is num ? (d['tag'] as num).toInt() : 0;
        if (d['kind'] == 'rewarded') {
          _emit({'ev': 'adDone', 'tag': tag, 'result': await showRewarded()});
        } else if (d['kind'] == 'interstitial') {
          // 広告を消した人には出さない（ページ側でも止めているが、こちらでも確かめる）
          if (!ent.noAds) await ads.showInterstitialAd();
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
