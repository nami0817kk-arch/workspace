import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hikari7/game/bridge.dart';
import 'package:hikari7/monetization/ad_service.dart';
import 'package:hikari7/monetization/monetization.dart';
import 'package:hikari7/monetization/purchase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 再生を外から操作できる差し替え広告。
class FakeAds implements AdService {
  bool rewardedReady = true;
  bool interstitialReady = true;
  int interstitials = 0;
  Completer<RewardResult>? playing;
  RewardResult next = RewardResult.earned;

  @override
  Future<void> initialize() async {}
  @override
  bool get isRewardedAdReady => rewardedReady;
  @override
  bool get isInterstitialReady => interstitialReady;
  @override
  Future<bool> waitForRewarded(Duration max) async => rewardedReady;
  @override
  void ensureLoaded() {}
  @override
  Future<RewardResult> showRewardedAd() {
    if (playing != null) return playing!.future;
    return Future.value(next);
  }

  @override
  Future<bool> showInterstitialAd() async {
    if (!interstitialReady) return false;
    interstitials++;
    return true;
  }

  @override
  void dispose() {}
}

/// 結果を返す前に通知で届ける差し替えストア（届いた購入を取りこぼさないかを見る）。
class FakeStore implements PurchaseService {
  Future<void> Function(String)? delivered;
  bool? entitlement;
  PurchaseOutcome buyResult = PurchaseOutcome.purchased;
  bool deliverBeforeReturn = true;

  @override
  set onDelivered(Future<void> Function(String productId)? cb) => delivered = cb;
  @override
  set onRevoked(Future<void> Function(String productId)? cb) {}
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<String?> priceLabel() async => '¥370';
  @override
  Future<PurchaseOutcome> buyRemoveAds() async {
    if (buyResult == PurchaseOutcome.purchased && deliverBeforeReturn) await delivered?.call(PurchaseService.removeAdsId);
    return buyResult;
  }

  @override
  Future<PurchaseOutcome> restore() async => PurchaseOutcome.unavailable;
  @override
  Future<bool?> hasEntitlement() async => entitlement;
  @override
  void dispose() {}
}

Future<(GameBridge, Monetization, FakeAds, FakeStore, List<String>)> setup({Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final p = await SharedPreferences.getInstance();
  final ads = FakeAds();
  final store = FakeStore();
  final money = Monetization(p, ads: ads, store: store);
  await money.start();
  final js = <String>[];
  final bridge = GameBridge(
    money: money,
    store: WebStore(p),
    runJs: (s) async => js.add(s),
    openUrl: (_) async {},
    showLicenses: () {},
  );
  return (bridge, money, ads, store, js);
}

void main() {
  test('起動の値は <head> の直後に入り、</script> で閉じられない', () {
    final out = injectBoot('<html><head><title>x</title></head></html>', {
      'store': {'k': '</script><script>alert(1)</script>'},
    });
    expect(out.indexOf('<script>window.__HIKARI_APP='), '<html><head>'.length);
    expect(out.contains('</script><script>alert'), isFalse);
  });

  test('保存はゲームが書いた値をそのまま残し、起動のときに全部返す', () async {
    final (b, _, _, _, _) = await setup();
    await b.handle(jsonEncode({'type': 'store', 'k': 'hikari7_proto_v8', 'v': '{"rnd":3}'}));
    await b.handle(jsonEncode({'type': 'store', 'k': 'hikari7_diff', 'v': 'hard'}));
    await b.handle(jsonEncode({'type': 'store', 'k': 'hikari7_diff', 'v': null}));
    expect(b.store.snapshot(), {'hikari7_proto_v8': '{"rnd":3}'});
  });

  test('動画を見終えたら特典を渡す返事、途中で閉じたら渡さない返事', () async {
    final (b, _, ads, _, js) = await setup();
    await b.handle('{"type":"reward"}');
    expect(js.last, startsWith('hikariAdResult(true,'));
    ads.next = RewardResult.closedEarly;
    await b.handle('{"type":"reward"}');
    expect(js.last, startsWith('hikariAdResult(false,'));
  });

  test('動画を読み込めていないときはタダで渡さない', () async {
    final (b, _, ads, _, js) = await setup();
    ads.rewardedReady = false;
    await b.handle('{"type":"reward"}');
    expect(js.last, startsWith('hikariAdResult(false,'));
  });

  test('動画の再生中に返事を待っていても、見終えた返事は必ず届く', () async {
    final (b, _, ads, _, js) = await setup();
    ads.playing = Completer<RewardResult>();
    final f = b.handle('{"type":"reward"}');
    await Future<void>.delayed(Duration.zero);
    expect(js.where((s) => s.startsWith('hikariAdResult')), isEmpty);
    ads.playing!.complete(RewardResult.earned);
    await f;
    expect(js.last, startsWith('hikariAdResult(true,'));
  });

  test('全画面広告は第2審査を終えた後から。第1審査の後と、広告を消した人には出さない', () async {
    final (b, money, ads, _, _) = await setup();
    await b.handle('{"type":"between","rnd":1}');
    expect(ads.interstitials, 0);
    await b.handle('{"type":"between","rnd":2}');
    expect(ads.interstitials, 1);
    await money.buy();
    await b.handle('{"type":"between","rnd":3}');
    expect(ads.interstitials, 1);
  });

  test('広告を消したら、動画なしで特典を渡す', () async {
    final (b, money, ads, _, js) = await setup();
    await money.buy();
    ads.rewardedReady = false;
    await b.handle('{"type":"reward"}');
    expect(js.last, startsWith('hikariAdResult(true,'));
  });

  test('購入が通知だけで届いても（待っている人がいなくても）広告を消す', () async {
    final (_, money, _, store, _) = await setup();
    await store.delivered!(PurchaseService.removeAdsId);
    expect(money.adFree, isTrue);
  });

  test('再インストール後は、端末の購入記録から広告なしに戻す', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await SharedPreferences.getInstance();
    final money = Monetization(p, ads: FakeAds(), store: FakeStore()..entitlement = true);
    await money.start();
    expect(money.adFree, isTrue);
  });

  test('外のページは決めた所だけ開く', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await SharedPreferences.getInstance();
    final opened = <Uri>[];
    final b = GameBridge(
      money: Monetization(p, ads: FakeAds(), store: FakeStore()),
      store: WebStore(p),
      runJs: (_) async {},
      openUrl: (u) async => opened.add(u),
      showLicenses: () {},
    );
    await b.handle('{"type":"open","url":"https://hikari7.dailyquarry.com/privacy.html"}');
    await b.handle('{"type":"open","url":"https://example.com/"}');
    await b.handle('{"type":"open","url":"http://hikari7.dailyquarry.com/"}');
    expect(opened.map((u) => u.toString()), ['https://hikari7.dailyquarry.com/privacy.html']);
  });

  test('アプリに入れるゲーム本体は、外へ何も読みに行かず、つなぎの関数を持っている', () {
    final f = File('assets/web/index.html');
    expect(f.existsSync(), isTrue, reason: 'python tool/build_app_web.py を先に回す');
    final html = f.readAsStringSync();
    expect(RegExp(r'<(link|script|img)[^>]+(href|src)="https?://').hasMatch(html), isFalse);
    for (final name in ['window.__HIKARI_APP', 'HikariApp.postMessage', 'hikariAdResult', 'hikariSetApp', 'HStore']) {
      expect(html.contains(name), isTrue, reason: name);
    }
    expect(html.contains('localStorage.getItem(') && !html.contains('try{return localStorage.getItem(k)'), isFalse);
    expect(html.contains('テスト版</div>'), isFalse, reason: 'テスト版の札はアプリに入れない');
  });
}
