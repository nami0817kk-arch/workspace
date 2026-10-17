import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mojitsumi/game/bridge.dart';
import 'package:mojitsumi/monetization/ad_service.dart';
import 'package:mojitsumi/monetization/monetization.dart';
import 'package:mojitsumi/monetization/purchase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 再生を外から操作できる差し替え広告。
class FakeAds implements AdService {
  bool rewardedReady = true;
  bool interstitialReady = true;
  int interstitials = 0;
  int prepared = 0;
  int rewardedShown = 0;
  Completer<RewardResult>? playing;
  Completer<bool>? loading;
  RewardResult next = RewardResult.earned;

  @override
  Future<void> initialize() async {}
  @override
  bool get isRewardedAdReady => rewardedReady;
  @override
  bool get isInterstitialReady => interstitialReady;
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
  @override
  Future<String?> priceLabel([String productId = PurchaseService.removeAdsId]) async {
    if (priceFails) throw StateError('x');
    return '¥370';
  }

  @override
  Future<PurchaseOutcome> buy(String productId) async {
    if (buyResult == PurchaseOutcome.purchased && deliverBeforeReturn) await delivered?.call(productId);
    return buyResult;
  }

  @override
  Future<PurchaseOutcome> restore() async => PurchaseOutcome.unavailable;
  @override
  Future<bool?> hasEntitlement([String productId = PurchaseService.removeAdsId]) async => entitlement;
  @override
  void dispose() {}
}

Future<(GameBridge, Monetization, FakeAds, FakeStore, List<String>)> setup({
  Map<String, Object> prefs = const {},
  void Function(String)? haptic,
  Future<void> Function(String)? share,
  Future<void> Function(Uri)? openUrl,
}) async {
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
    openUrl: openUrl ?? (_) async {},
    showLicenses: () {},
    haptic: haptic,
    share: share,
  );
  return (bridge, money, ads, store, js);
}

Map<String, Object?> lastApp(List<String> js) {
  final s = js.lastWhere((x) => x.contains('tenbinSetApp('));
  return (jsonDecode(s.substring(s.indexOf('tenbinSetApp(') + 13, s.lastIndexOf(')'))) as Map).cast<String, Object?>();
}

void main() {
  test('起動の値は <head> の直後に入り、</script> で閉じられない', () {
    final out = injectBoot('<html><head><title>x</title></head></html>', {
      'store': {'k': '</script><script>alert(1)</script>'},
    });
    expect(out.indexOf('<script>window.__TENBIN_APP='), '<html><head>'.length);
    expect(out.contains('</script><script>alert'), isFalse);
  });

  test('保存はゲームが書いた値をそのまま残し、起動のときに全部返す', () async {
    final (b, _, _, _, _) = await setup();
    await b.handle(jsonEncode({'type': 'store', 'k': 'tenbin-kana-dict', 'v': '{"ねこ":1}'}));
    await b.handle(jsonEncode({'type': 'store', 'k': 'tenbin-kana-plat', 'v': '"flat"'}));
    await b.handle(jsonEncode({'type': 'store', 'k': 'tenbin-kana-plat', 'v': null}));
    await b.handle(jsonEncode({'type': 'store', 'k': 'x', 'v': 3}));
    expect(b.store.snapshot(), {'tenbin-kana-dict': '{"ねこ":1}'});
  });

  test('動画を見終えたら granted、途中で閉じたら declined を、頼みと同じ番号で返す', () async {
    final (b, _, ads, _, js) = await setup();
    await b.handle('{"type":"reward","id":4}');
    expect(js.last, "tenbinAdResult('granted',4)");
    ads.next = RewardResult.closedEarly;
    await b.handle('{"type":"reward","id":5}');
    expect(js.last, "tenbinAdResult('declined',5)");
  });

  test('動画を読み込めていないときはタダで渡さない', () async {
    final (b, _, ads, _, js) = await setup();
    ads.rewardedReady = false;
    await b.handle('{"type":"reward","id":1}');
    expect(js, contains('window.tenbinAdWaiting&&tenbinAdWaiting()'));
    expect(js.last, "tenbinAdResult('unavailable',1)");
  });

  test('動画の再生中に返事を待っていても、見終えた返事は必ず届く', () async {
    final (b, _, ads, _, js) = await setup();
    ads.playing = Completer<RewardResult>();
    final f = b.handle('{"type":"reward","id":1}');
    await Future<void>.delayed(Duration.zero);
    expect(js.where((s) => s.startsWith('tenbinAdResult')), isEmpty);
    ads.playing!.complete(RewardResult.earned);
    await f;
    expect(js.last, "tenbinAdResult('granted',1)");
  });

  test('「やめる」が押された動画は出さない', () async {
    final (b, _, ads, _, js) = await setup();
    ads.rewardedReady = false;
    ads.loading = Completer<bool>();
    final f = b.handle('{"type":"reward","id":3}');
    await Future<void>.delayed(Duration.zero);
    await b.handle('{"type":"rewardCancel","id":3}');
    ads.loading!.complete(true);
    await f;
    expect(ads.rewardedShown, 0);
    expect(js.last, "tenbinAdResult('declined',3)");
  });

  test('動画の再生中に次の頼みが来たら、黙って捨てずに「使えなかった」と返す', () async {
    final (b, _, ads, _, js) = await setup();
    ads.playing = Completer<RewardResult>();
    final f = b.handle('{"type":"reward","id":1}');
    await Future<void>.delayed(Duration.zero);
    await b.handle('{"type":"reward","id":2}');
    expect(js.last, "tenbinAdResult('unavailable',2)");
    ads.playing!.complete(RewardResult.earned);
    await f;
    expect(js.last, "tenbinAdResult('granted',1)");
  });

  test('全画面広告は頼まれたら出して、出したかどうかを返す。広告を消した人には出さない', () async {
    final (b, money, ads, _, js) = await setup();
    await b.handle('{"type":"between"}');
    expect(ads.interstitials, 1);
    expect(js.last, 'window.tenbinBetweenDone&&tenbinBetweenDone(true)');
    ads.interstitialReady = false;
    await b.handle('{"type":"between"}');
    expect(js.last, 'window.tenbinBetweenDone&&tenbinBetweenDone(false)');
    ads.interstitialReady = true;
    await money.buy();
    await b.handle('{"type":"between"}');
    expect(ads.interstitials, 1);
    expect(js.last, 'window.tenbinBetweenDone&&tenbinBetweenDone(false)');
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

  test('買ったら広告を消し、値段と状態をゲームに送る', () async {
    final (b, money, _, _, js) = await setup();
    await b.pushApp();
    expect(lastApp(js), {'adFree': false, 'price': '¥370', 'canBuy': true});
    await b.handle('{"type":"buy"}');
    expect(money.adFree, isTrue);
    expect(lastApp(js)['adFree'], isTrue);
    expect(lastApp(js)['msg'], '広告を消しました。ありがとうございます');
    expect(lastApp(js)['canBuy'], isFalse);
  });

  test('購入の結果が「成立」でも、通知が届かなければ広告なしにしない（入口は通知だけ）', () async {
    final (_, money, _, store, _) = await setup();
    store.deliverBeforeReturn = false;
    expect(await money.buy(), PurchaseOutcome.purchased);
    expect(money.adFree, isFalse);
  });

  test('購入が通知だけで届いても（待っている人がいなくても）広告を消す', () async {
    final (_, money, _, store, _) = await setup();
    await store.delivered!(PurchaseService.removeAdsId);
    expect(money.adFree, isTrue);
  });

  test('再インストール後は、端末の購入記録から広告なしに戻す', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await SharedPreferences.getInstance();
    final store = FakeStore()..entitlement = true;
    final money = Monetization(p, ads: FakeAds(), store: store);
    await money.start();
    expect(money.adFree, isTrue);
  });

  test('値段が取れなくても、ほかの状態は渡す', () async {
    final (b, _, _, store, js) = await setup();
    store.priceFails = true;
    await b.pushApp();
    expect(lastApp(js)['price'], isNull);
    expect(lastApp(js)['adFree'], isFalse);
  });

  test('復元できなかったら、そう知らせる', () async {
    final (b, _, _, _, js) = await setup();
    await b.handle('{"type":"restore"}');
    expect(lastApp(js)['msg'], '復元できる購入が見つかりませんでした');
  });

  test('外のページは決めた所だけ開く', () async {
    final opened = <Uri>[];
    final (b, _, _, _, _) = await setup(openUrl: (u) async => opened.add(u));
    await b.handle('{"type":"open","url":"https://mojitsumi.pages.dev/privacy.html"}');
    await b.handle('{"type":"open","url":"http://mojitsumi.pages.dev/privacy.html"}');
    await b.handle('{"type":"open","url":"https://example.com/"}');
    expect(opened, [Uri.parse('https://mojitsumi.pages.dev/privacy.html')]);
  });

  test('振動とシェアは決めた形のときだけ伝える', () async {
    final got = <String>[];
    final shared = <String>[];
    final (b, _, _, _, _) = await setup(haptic: got.add, share: (t) async => shared.add(t));
    await b.handle('{"type":"haptic","k":"success"}');
    await b.handle('{"type":"haptic","k":"explode"}');
    await b.handle('{"type":"share","text":"もじつみ で 430点"}');
    await b.handle('{"type":"share","text":""}');
    await b.handle('{"type":"share","text":7}');
    await b.handle('not json');
    expect(got, ['success']);
    expect(shared, ['もじつみ で 430点']);
  });

  test('アプリに入れるゲーム本体は、外へ何も読みに行かず、つなぎの関数を持っている', () {
    final f = File('assets/web/index.html');
    expect(f.existsSync(), isTrue, reason: 'python ../tool/build_app_web.py を先に回す');
    final html = f.readAsStringSync();
    expect(RegExp(r'<(link|script|img)[^>]+(href|src)="https?://').hasMatch(html), isFalse);
    expect(html.contains('fonts.googleapis.com'), isFalse);
    for (final name in [
      'window.__TENBIN_APP',
      'TenbinApp.postMessage',
      'tenbinAdResult',
      'tenbinAdWaiting',
      'tenbinBetweenDone',
      'tenbinSetApp',
      'window.tenbinPause',
      'TenbinMoney',
      'TenbinCore',
    ]) {
      expect(html.contains(name), isTrue, reason: name);
    }
  });
}
