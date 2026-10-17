import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tsuruhashi/game/bridge.dart';
import 'package:tsuruhashi/monetization/ad_service.dart';
import 'package:tsuruhashi/monetization/monetization.dart';
import 'package:tsuruhashi/monetization/purchase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 再生を外から操作できる差し替え広告。
class FakeAds implements AdService {
  bool rewardedReady = true;
  Completer<RewardResult>? playing;
  RewardResult next = RewardResult.earned;

  @override
  Future<void> initialize() async {}
  @override
  bool get isRewardedAdReady => rewardedReady;
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
  void dispose() {}
}

/// 結果を返す前に通知で届ける差し替えストア（届いた購入を取りこぼさないかを見る）。
class FakeStore implements PurchaseService {
  Future<void> Function(String, String?)? delivered;
  Future<void> Function(String)? revoked;
  final entitlement = <String, bool?>{};
  PurchaseOutcome buyResult = PurchaseOutcome.purchased;
  bool deliverBeforeReturn = true;
  int _tx = 0;

  @override
  set onDelivered(Future<void> Function(String productId, String? purchaseId)? cb) => delivered = cb;
  @override
  set onRevoked(Future<void> Function(String productId)? cb) => revoked = cb;
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<Map<String, String>> priceLabels() async => {for (final id in PurchaseService.all) id: '¥160'};
  @override
  Future<PurchaseOutcome> buy(String productId) async {
    if (buyResult == PurchaseOutcome.purchased && deliverBeforeReturn) await delivered?.call(productId, 'tx${++_tx}');
    return buyResult;
  }

  @override
  Future<PurchaseOutcome> restore() async => PurchaseOutcome.unavailable;
  @override
  Future<bool?> hasEntitlement(String productId) async => entitlement[productId];
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
    expect(out.indexOf('<script>window.__TSURU_APP='), '<html><head>'.length);
    expect(out.contains('</script><script>alert'), isFalse);
  });

  test('保存はゲームが書いた値をそのまま残し、起動のときに全部返す', () async {
    final (b, _, _, _, _) = await setup();
    await b.handle(jsonEncode({'type': 'store', 'k': 'tsuruhashi_v2', 'v': '{"depth":3}'}));
    await b.handle(jsonEncode({'type': 'store', 'k': 'tsuruhashi_v2_bak', 'v': 'x'}));
    await b.handle(jsonEncode({'type': 'store', 'k': 'tsuruhashi_v2_bak', 'v': null}));
    expect(b.store.snapshot(), {'tsuruhashi_v2': '{"depth":3}'});
  });

  test('動画を見終えたら特典を渡す返事、途中で閉じたら渡さない返事', () async {
    final (b, _, ads, _, js) = await setup();
    await b.handle('{"type":"reward"}');
    expect(js.last, startsWith('window.tsuruAdResult&&tsuruAdResult(true,'));
    ads.next = RewardResult.closedEarly;
    await b.handle('{"type":"reward"}');
    expect(js.last, startsWith('window.tsuruAdResult&&tsuruAdResult(false,'));
  });

  test('動画を読み込めていないときはタダで渡さない', () async {
    final (b, _, ads, _, js) = await setup();
    ads.rewardedReady = false;
    await b.handle('{"type":"reward"}');
    expect(js.last, startsWith('window.tsuruAdResult&&tsuruAdResult(false,'));
  });

  test('動画の再生中に返事を待っていても、見終えた返事は必ず届く', () async {
    final (b, _, ads, _, js) = await setup();
    ads.playing = Completer<RewardResult>();
    final f = b.handle('{"type":"reward"}');
    await Future<void>.delayed(Duration.zero);
    expect(js.where((s) => s.contains('tsuruAdResult(')), isEmpty);
    ads.playing!.complete(RewardResult.earned);
    await f;
    expect(js.last, startsWith('window.tsuruAdResult&&tsuruAdResult(true,'));
  });

  test('全画面広告の頼みは受け付けない（つるはし採掘は動画広告だけ）', () async {
    final (b, _, _, _, js) = await setup();
    await b.handle('{"type":"between","rnd":3}');
    expect(js, isEmpty);
  });

  test('課金アイテムを買っても、動画の特典はタダにならない（広告を消すは売らない）', () async {
    final (b, money, ads, _, js) = await setup();
    await money.buy('tsuruhashi_canteen');
    ads.rewardedReady = false;
    await b.handle('{"type":"reward"}');
    expect(js.last, startsWith('window.tsuruAdResult&&tsuruAdResult(false,'));
  });

  test('ゲームからの「買う」は決めた商品だけストアへ出す', () async {
    final (b, money, _, _, _) = await setup();
    await b.handle('{"type":"buy","id":"canteen"}');
    await b.handle('{"type":"buy","id":"remove_ads"}');
    await b.handle('{"type":"buy"}');
    expect(money.owned, ['canteen']);
  });

  test('買い切りが通知だけで届いても（待っている人がいなくても）持っていることになる', () async {
    final (_, money, _, store, _) = await setup();
    await store.delivered!('tsuruhashi_cart', 't1');
    expect(money.owned, ['cart']);
  });

  test('特製弁当は届いた数だけ足し、同じ取引が二度届いても二度渡さない', () async {
    final (b, money, _, store, js) = await setup();
    await store.delivered!('tsuruhashi_bento3', 'a');
    await store.delivered!('tsuruhashi_bento3', 'a');
    await store.delivered!('tsuruhashi_bento10', 'b');
    expect(money.bentoTotal, 13);
    await b.pushApp();
    expect(js.last, contains('"got":{"bento":13}'));
  });

  test('特製弁当は買う操作の戻り値では渡さない（通知で届いた分だけ）', () async {
    final (_, money, _, store, _) = await setup();
    store.deliverBeforeReturn = false;
    await money.buy('tsuruhashi_bento3');
    expect(money.bentoTotal, 0);
  });

  test('届いた弁当の合計は再起動しても残る', () async {
    final (_, _, _, store, _) = await setup();
    await store.delivered!('tsuruhashi_bento10', 'x');
    final p = await SharedPreferences.getInstance();
    final again = Monetization(p, ads: FakeAds(), store: FakeStore());
    await again.start();
    expect(again.bentoTotal, 10);
  });

  test('再インストール後は、端末の購入記録から買い切りを戻し、返金されたら外す', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await SharedPreferences.getInstance();
    final store = FakeStore()..entitlement['tsuruhashi_canteen'] = true;
    final money = Monetization(p, ads: FakeAds(), store: store);
    await money.start();
    expect(money.owned, ['canteen']);
    store.entitlement['tsuruhashi_canteen'] = false;
    await store.revoked!('tsuruhashi_canteen');
    expect(money.owned, isEmpty);
  });

  test('起動のときに埋め込む値は、待たずに分かる購入の記録', () async {
    final (_, money, _, store, _) = await setup();
    await store.delivered!('tsuruhashi_cart', 'k');
    await store.delivered!('tsuruhashi_bento3', 'm');
    expect(GameBridge.bootState(money), {
      'owned': ['cart'],
      'got': {'bento': 3},
    });
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
    await b.handle('{"type":"open","url":"https://tsuruhashi.dailyquarry.com/privacy.html"}');
    await b.handle('{"type":"open","url":"https://example.com/"}');
    await b.handle('{"type":"open","url":"http://tsuruhashi.dailyquarry.com/"}');
    expect(opened.map((u) => u.toString()), ['https://tsuruhashi.dailyquarry.com/privacy.html']);
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
    expect(html.contains('window.tsuruPause ='), isTrue);
    expect(html.contains('window.tsuruResume ='), isTrue);
  });

  test('BGM は決めた名前のものだけ鳴らし、通知の上限は決めた範囲だけ受け取る', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await SharedPreferences.getInstance();
    final bgms = <String>[];
    final caps = <double>[];
    var asked = 0;
    final b = GameBridge(
      money: Monetization(p, ads: FakeAds(), store: FakeStore()),
      store: WebStore(p),
      runJs: (_) async {},
      openUrl: (_) async {},
      showLicenses: () {},
      bgm: (k, v) => bgms.add('$k@$v'),
      notifAsk: () async => asked++,
      notifCap: caps.add,
    );
    await b.handle('{"type":"bgm","k":"deep","vol":0.5}');
    await b.handle('{"type":"bgm","k":null,"vol":0}');
    await b.handle('{"type":"bgm","k":"../../etc","vol":0.5}');
    await b.handle('{"type":"bgm","k":"surface","vol":7}');
    await b.handle('{"type":"notifAsk"}');
    await b.handle('{"type":"notifCap","h":12}');
    await b.handle('{"type":"notifCap","h":999}');
    await b.handle('{"type":"notifCap","h":"8"}');
    expect(bgms, ['deep@0.5', 'null@0.0', 'surface@1.0']);
    expect(asked, 1);
    expect(caps, [12.0]);
  });

  test('組み立てた本体のそばに、BGM の曲がそろっている', () {
    for (final k in GameBridge.bgmKeys) {
      expect(File('assets/audio/bgm/$k.mp3').existsSync(), isTrue, reason: '$k（python tool/build_app_web.py を先に回す）');
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
    await b.handle('{"type":"haptic","k":"heavy"}');
    await b.handle('{"type":"haptic","k":"explode"}');
    await b.handle('{"type":"haptic"}');
    expect(got, ['success', 'heavy']);
  });

  test('アプリに入れるゲーム本体は、外へ何も読みに行かず、つなぎの関数を持っている', () {
    final f = File('assets/web/index.html');
    expect(f.existsSync(), isTrue, reason: 'python tool/build_app_web.py を先に回す');
    final html = f.readAsStringSync();
    expect(RegExp(r'<(link|script|img)[^>]+(href|src)="https?://').hasMatch(html), isFalse);
    for (final name in ['window.__TSURU_APP', 'TsuruApp.postMessage', 'window.tsuruAdResult', 'window.tsuruSetApp', 'TStore']) {
      expect(html.contains(name), isTrue, reason: name);
    }
  });
}
