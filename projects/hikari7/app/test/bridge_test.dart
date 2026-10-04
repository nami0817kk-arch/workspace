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
  int prepared = 0;
  int rewardedShown = 0;
  Completer<RewardResult>? playing;
  RewardResult next = RewardResult.earned;

  @override
  Future<void> initialize() async {}
  @override
  bool get isRewardedAdReady => rewardedReady;
  @override
  bool get isInterstitialReady => interstitialReady;
  Completer<bool>? loading;
  @override
  Future<bool> waitForRewarded(Duration max) async => loading != null ? loading!.future : rewardedReady;
  @override
  void ensureLoaded() {}
  @override
  Future<RewardResult> showRewardedAd({void Function()? onShown}) {
    rewardedShown++;
    onShown?.call();
    if (playing != null) return playing!.future;
    return Future.value(next);
  }

  @override
  void prepareInterstitial() => prepared++;
  @override
  Future<bool> waitForInterstitial(Duration max) async => interstitialReady;

  @override
  Future<bool> showInterstitialAd({void Function()? onShown}) async {
    if (!interstitialReady) return false;
    onShown?.call();
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
  bool priceFails = false;

  @override
  set onDelivered(Future<void> Function(String productId)? cb) => delivered = cb;
  @override
  set onRevoked(Future<void> Function(String productId)? cb) {}
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> isAvailable() async => true;
  Map<String, bool?> packEntitlement = {};
  @override
  Future<String?> priceLabel([String productId = PurchaseService.removeAdsId]) async {
    if (priceFails && productId == PurchaseService.removeAdsId) throw StateError('x');
    return productId == PurchaseService.removeAdsId ? '¥370' : '¥320';
  }
  @override
  Future<PurchaseOutcome> buy(String productId) async {
    if (buyResult == PurchaseOutcome.purchased && deliverBeforeReturn) await delivered?.call(productId);
    return buyResult;
  }

  @override
  Future<PurchaseOutcome> restore() async => PurchaseOutcome.unavailable;
  @override
  Future<bool?> hasEntitlement([String productId = PurchaseService.removeAdsId]) async =>
      productId == PurchaseService.removeAdsId ? entitlement : packEntitlement[productId];
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

  test('動画の返事には、頼みと同じ番号を付け、表示が始まったら知らせる', () async {
    final (b, _, _, _, js) = await setup();
    await b.handle('{"type":"reward","id":7}');
    expect(js, contains('window.hikariAdShowing&&hikariAdShowing(7)'));
    expect(js.last, startsWith('hikariAdResult(true,'));
    expect(js.last, endsWith(',7)'));
  });

  test('「やめる」が押された動画は出さず、特典の返事も渡さない', () async {
    final (b, _, ads, _, js) = await setup();
    ads.rewardedReady = false;
    ads.loading = Completer<bool>();
    // 読み込みを待っている間に「やめる」が届く
    final f = b.handle('{"type":"reward","id":3}');
    await Future<void>.delayed(Duration.zero);
    await b.handle('{"type":"rewardCancel","id":3}');
    ads.loading!.complete(true);
    await f;
    expect(ads.rewardedShown, 0);
    expect(js.last, startsWith('hikariAdResult(false,'));
  });

  test('動画の再生中に次の頼みが来たら、黙って捨てずに「使えなかった」と返す', () async {
    final (b, _, ads, _, js) = await setup();
    ads.playing = Completer<RewardResult>();
    final f = b.handle('{"type":"reward","id":1}');
    await Future<void>.delayed(Duration.zero);
    await b.handle('{"type":"reward","id":2}');
    expect(js.last, startsWith('hikariAdResult(false,'));
    expect(js.last, endsWith(',2)'));
    ads.playing!.complete(RewardResult.earned);
    await f;
    expect(js.last, startsWith('hikariAdResult(true,'));
    expect(js.last, endsWith(',1)'));
  });

  test('全画面広告は、出しても出さなくても終わったらゲームに返し、出すときは表示の始まりも知らせる', () async {
    final (b, _, ads, _, js) = await setup();
    await b.handle('{"type":"between","rnd":2}');
    expect(js, contains("window.hikariAdShowing&&hikariAdShowing('inter')"));
    expect(js.last, 'window.hikariBetweenDone&&hikariBetweenDone()');
    js.clear();
    ads.interstitialReady = false;
    await b.handle('{"type":"between","rnd":3}');
    expect(js, ['window.hikariBetweenDone&&hikariBetweenDone()']);
  });

  test('全画面広告は、ゲームが頼んだときだけ読み込む。広告を消した人には読まない', () async {
    final (b, money, ads, store, _) = await setup();
    expect(ads.prepared, 0);
    await b.handle('{"type":"prepInter"}');
    expect(ads.prepared, 1);
    await store.delivered!(PurchaseService.removeAdsId);
    expect(money.adFree, isTrue);
    await b.handle('{"type":"prepInter"}');
    expect(ads.prepared, 1);
  });

  test('購入の結果が「成立」でも、通知が届かなければ持っている扱いにしない（入口は通知だけ）', () async {
    final (_, money, _, store, _) = await setup();
    store.deliverBeforeReturn = false;
    expect(await money.buy(PurchaseService.storyPackId), PurchaseOutcome.purchased);
    expect(money.owns(PurchaseService.storyPackId), isFalse);
  });

  test('値段の1つが取れなくても、ほかの値段とストアの状態は渡す', () async {
    final (b, _, _, store, js) = await setup();
    store.priceFails = true;
    await b.pushApp();
    final m = jsonDecode(js.last.substring(js.last.indexOf('(') + 1, js.last.lastIndexOf(')'))) as Map;
    expect(m['price'], isNull);
    expect(m['storeOk'], isTrue);
    expect(m['prices'], {'story': '¥320', 'audition': '¥320'});
  });

  test('追加パックの承認待ちと、結果が届かないときは、それぞれの文で知らせる', () async {
    final (b, _, _, store, js) = await setup();
    store.buyResult = PurchaseOutcome.pending;
    await b.handle('{"type":"buy","id":"hikari7_story_pack"}');
    expect(js.last, contains('追加パックが入ります'));
    store.buyResult = PurchaseOutcome.timedOut;
    await b.handle('{"type":"buy","id":"hikari7_story_pack"}');
    expect(js.last, contains('まだ届いていません'));
  });

  test('ショップを開いたら、最新の値段と持ち物を送り直す', () async {
    final (b, _, _, _, js) = await setup();
    await b.handle('{"type":"refresh"}');
    expect(js.last, startsWith('window.hikariSetApp&&hikariSetApp('));
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

  test('追加パックは、待っている人がいなくても届けば持っている扱いになり、広告は消えない', () async {
    final (b, money, _, store, js) = await setup();
    await store.delivered!(PurchaseService.storyPackId);
    expect(money.owns(PurchaseService.storyPackId), isTrue);
    expect(money.owns(PurchaseService.auditionPackId), isFalse);
    expect(money.adFree, isFalse);
    await b.pushApp();
    expect(js.last, contains('"owned":{"story":true,"audition":false}'));
  });

  test('追加パックはゲームから商品IDを指定して買え、知らない商品IDは広告を消すとして扱う', () async {
    final (b, money, _, _, _) = await setup();
    await b.handle('{"type":"buy","id":"hikari7_audition_pack"}');
    expect(money.owns(PurchaseService.auditionPackId), isTrue);
    expect(money.adFree, isFalse);
    await b.handle('{"type":"buy","id":"other"}');
    expect(money.adFree, isTrue);
  });

  test('再インストール後は、端末の購入記録から追加パックも戻す', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await SharedPreferences.getInstance();
    final store = FakeStore()..packEntitlement = {PurchaseService.storyPackId: true};
    final money = Monetization(p, ads: FakeAds(), store: store);
    await money.start();
    expect(money.owns(PurchaseService.storyPackId), isTrue);
    expect(money.adFree, isFalse);
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
    await b.handle('{"type":"open","url":"https://hikari7.pages.dev/privacy.html"}');
    await b.handle('{"type":"open","url":"https://example.com/"}');
    await b.handle('{"type":"open","url":"http://hikari7.pages.dev/"}');
    expect(opened.map((u) => u.toString()), ['https://hikari7.pages.dev/privacy.html']);
  });

  test('レビューのお願いと画面の明るさは、決めた形のときだけ伝える', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await SharedPreferences.getInstance();
    var reviews = 0;
    final themes = <bool>[];
    final b = GameBridge(
      money: Monetization(p, ads: FakeAds(), store: FakeStore()),
      store: WebStore(p),
      runJs: (_) async {},
      openUrl: (_) async {},
      showLicenses: () {},
      review: () async => reviews++,
      theme: themes.add,
    );
    await b.handle('{"type":"review"}');
    await b.handle('{"type":"theme","dark":true}');
    await b.handle('{"type":"theme","dark":"yes"}');
    await b.handle('{"type":"theme","dark":false}');
    expect(reviews, 1);
    expect(themes, [true, false]);
  });

  test('アプリに入れるゲーム本体は、裏に回るときの保存の口を持っている', () {
    final html = File('assets/web/index.html').readAsStringSync();
    expect(html.contains('window.hikariPause='), isTrue);
  });

  test('BGM と声は、決めた名前・形のものだけ鳴らす', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await SharedPreferences.getInstance();
    final bgms = <String>[];
    final voices = <String>[];
    final b = GameBridge(
      money: Monetization(p, ads: FakeAds(), store: FakeStore()),
      store: WebStore(p),
      runJs: (_) async {},
      openUrl: (_) async {},
      showLicenses: () {},
      bgm: (k, v) => bgms.add('$k@$v'),
      voice: voices.add,
    );
    await b.handle('{"type":"bgm","k":"stage","vol":0.5}');
    await b.handle('{"type":"bgm","k":null,"vol":0}');
    await b.handle('{"type":"bgm","k":"../../etc","vol":0.5}');
    await b.handle('{"type":"bgm","k":"title","vol":7}');
    await b.handle('{"type":"voice","f":"f2/0a1b2c3d"}');
    await b.handle('{"type":"voice","f":"x9/0a1b2c3d"}');
    await b.handle('{"type":"voice","f":"m1/../../secret"}');
    expect(bgms, ['stage@0.5', 'null@0.0', 'title@1.0']);
    expect(voices, ['f2/0a1b2c3d']);
  });

  test('組み立てた本体に、声のある台詞の一覧と BGM の曲がそろっている', () {
    final html = File('assets/web/index.html').readAsStringSync();
    expect(html.contains('var VOICE_KEYS={'), isTrue, reason: 'tool/make_voice.py の index.json を埋め込めていない');
    for (final k in GameBridge.bgmKeys) {
      expect(File('assets/audio/bgm/$k.mp3').existsSync(), isTrue, reason: k);
    }
  });

  test('振動は決めた種類だけ伝える', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await SharedPreferences.getInstance();
    final got = <String>[];
    final b = GameBridge(
      money: Monetization(p, ads: FakeAds(), store: FakeStore()),
      store: WebStore(p),
      runJs: (_) async {},
      openUrl: (_) async {},
      showLicenses: () {},
      haptic: got.add,
    );
    await b.handle('{"type":"haptic","k":"success"}');
    await b.handle('{"type":"haptic","k":"light"}');
    await b.handle('{"type":"haptic","k":"explode"}');
    await b.handle('{"type":"haptic"}');
    expect(got, ['success', 'light']);
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
