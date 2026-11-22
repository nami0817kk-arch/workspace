import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tounoishi/game/bridge.dart';
import 'package:tounoishi/main.dart' show gameAsset, pauseJs;
import 'package:tounoishi/monetization/ad_service.dart';
import 'package:tounoishi/monetization/monetization.dart';
import 'package:tounoishi/monetization/purchase_service.dart';

/// 表示を外から操作できる差し替え広告（本物と同じく、閉じた知らせは後から来る形にできる）。
class FakeAds implements AdService {
  bool ready = true;
  int shown = 0;
  int prepared = 0;
  int disposed = 0;
  Completer<bool>? playing;

  @override
  Future<void> initialize() async {}
  @override
  bool get isInterstitialReady => ready;
  @override
  void prepareInterstitial() => prepared++;
  @override
  void ensureLoaded() {}
  @override
  Future<bool> waitForInterstitial(Duration max) async => ready;
  @override
  Future<bool> showInterstitialAd({void Function()? onShown}) {
    if (!ready) return Future.value(false);
    shown++;
    onShown?.call();
    return playing?.future ?? Future.value(true);
  }

  @override
  void dispose() => disposed++;
}

/// 結果を返す前に通知で届ける差し替えストア（届いた購入を取りこぼさないかを見る）。
class FakeStore implements PurchaseService {
  Future<void> Function(String)? delivered;
  Future<void> Function(String)? revoked;
  bool? entitlement;
  PurchaseOutcome buyResult = PurchaseOutcome.purchased;
  bool deliverBeforeReturn = true;
  bool priceFails = false;

  @override
  set onDelivered(Future<void> Function(String productId)? cb) => delivered = cb;
  @override
  set onRevoked(Future<void> Function(String productId)? cb) => revoked = cb;
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<String?> priceLabel() async {
    if (priceFails) throw StateError('x');
    return '¥370';
  }

  @override
  Future<PurchaseOutcome> buy() async {
    if (buyResult == PurchaseOutcome.purchased && deliverBeforeReturn) {
      await delivered?.call(PurchaseService.removeAdsId);
    }
    return buyResult;
  }

  @override
  Future<PurchaseOutcome> restore() async => PurchaseOutcome.unavailable;
  @override
  Future<bool?> hasEntitlement() async => entitlement;
  @override
  void dispose() {}
}

/// completePurchase を数える差し替えの InAppPurchase（購入の受け取りの順番を見る）。
class FakeIap implements InAppPurchase {
  final completed = <String>[];
  @override
  Future<void> completePurchase(PurchaseDetails purchase) async => completed.add(purchase.productID);
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

PurchaseDetails purchase(PurchaseStatus status, {String id = PurchaseService.removeAdsId, String json = '{}'}) =>
    PurchaseDetails(
      productID: id,
      verificationData: PurchaseVerificationData(localVerificationData: json, serverVerificationData: '', source: 'app_store'),
      transactionDate: '0',
      status: status,
    )..pendingCompletePurchase = true;

Future<(GameBridge, Monetization, FakeAds, FakeStore, List<String>)> setup({Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final p = await SharedPreferences.getInstance();
  final ads = FakeAds();
  final store = FakeStore();
  final money = Monetization(p, ads: ads, store: store);
  await money.start();
  final js = <String>[];
  final bridge = GameBridge(money: money, runJs: (s) async => js.add(s));
  return (bridge, money, ads, store, js);
}

const done = 'window.touInterDone&&touInterDone()';
const showing = 'window.touAdShowing&&touAdShowing()';

void main() {
  group('全画面広告', () {
    test('ゲームが頼んだら出し、表示の始まりと終わりを知らせる', () async {
      final (b, _, ads, _, js) = await setup();
      await b.handle('{"type":"inter","at":"lose"}');
      expect(ads.shown, 1);
      expect(js, [showing, done]);
    });

    test('閉じるまで「終わった」を返さない（広告の裏で結果画面・次の階を始めない）', () async {
      final (b, _, ads, _, js) = await setup();
      ads.playing = Completer<bool>();
      final f = b.handle('{"type":"inter","at":"grow"}');
      await Future<void>.delayed(Duration.zero);
      expect(js, [showing]);
      ads.playing!.complete(true);
      await f;
      expect(js.last, done);
    });

    test('在庫が無ければ出さずに、すぐ「終わった」を返す（進行を止めない）', () async {
      final (b, _, ads, _, js) = await setup();
      ads.ready = false;
      await b.handle('{"type":"inter","at":"lose"}');
      expect(ads.shown, 0);
      expect(js, [done]);
    });

    test('出している最中に次の頼みが来たら、重ねて出さずにすぐ返す', () async {
      final (b, _, ads, _, js) = await setup();
      ads.playing = Completer<bool>();
      final f = b.handle('{"type":"inter","at":"grow"}');
      await Future<void>.delayed(Duration.zero);
      await b.handle('{"type":"inter","at":"grow"}');
      expect(ads.shown, 1);
      expect(js.last, done);
      ads.playing!.complete(true);
      await f;
      expect(js.where((s) => s == done), hasLength(2));
    });

    test('広告を消した人には出さない（それでも「終わった」は返す）', () async {
      final (b, money, ads, _, js) = await setup();
      await money.buy();
      expect(money.adFree, isTrue);
      await b.handle('{"type":"inter","at":"lose"}');
      expect(ads.shown, 0);
      expect(js.last, done);
    });

    test('ゲームが頼んだときだけ読み込む。広告を消した人には読まない', () async {
      final (b, _, ads, store, _) = await setup();
      expect(ads.prepared, 0, reason: '起動時に先読みしない（docs/app-pitfalls.md 3番）');
      await b.handle('{"type":"prepInter"}');
      expect(ads.prepared, 1);
      await store.delivered!(PurchaseService.removeAdsId);
      await b.handle('{"type":"prepInter"}');
      expect(ads.prepared, 1);
    });

    test('広告の期限: 読み込み直後・55分の手前は出せる、55分を過ぎたら出さない', () {
      final t = DateTime(2026, 11, 22, 12);
      expect(adLifetime < const Duration(hours: 1), isTrue);
      expect(adIsFresh(t, t), isTrue);
      expect(adIsFresh(t, t.add(const Duration(minutes: 54, seconds: 59))), isTrue);
      expect(adIsFresh(t, t.add(const Duration(minutes: 55))), isFalse);
      expect(adIsFresh(t, t.add(const Duration(hours: 2))), isFalse);
      expect(NoOpAdService().isInterstitialReady, isFalse, reason: '読み込んでいなければ出せない');
    });

    test('広告ユニットIDの既定は Google のテスト用ID（本物は CI で渡す）', () {
      expect(AdMobAdService.isUsingTestUnitId, isTrue);
    });
  });

  group('広告SDKの使い方（原文を見て確かめる。docs/app-pitfalls.md 3・9番）', () {
    final src = File('lib/monetization/ad_service.dart').readAsStringSync();

    test('「await InterstitialAd.load」で待たない。読み込みの返事は Completer で待ち合わせる', () {
      expect(src.contains('await InterstitialAd.load('), isFalse, reason: 'これを await しても広告は届かない');
      expect(src.contains('Completer<void>? _changed'), isTrue, reason: '読み込みの完了を待ち合わせる口が無い');
      expect(src.contains('onAdLoaded: loaded') && src.contains('onAdFailedToLoad:'), isTrue);
    });

    test('読み込んだ広告は1時間より手前（55分）で捨てる', () {
      expect(src, contains('_maxAge = Duration(minutes: 55)'));
    });

    test('show を await しただけで終わりにせず、閉じた知らせ（Completer）まで待つ', () {
      expect(src, contains('final closed = Completer<bool>()'));
      expect(src, contains('onAdDismissedFullScreenContent'));
      expect(src, contains('onAdFailedToShowFullScreenContent'));
      expect(src, contains('return closed.future;'));
    });

    test('全年齢向け(G)までに絞り、動画広告（リワード）は入れない', () {
      expect(src, contains('MaxAdContentRating.g'));
      expect(src.contains('RewardedAd'), isFalse);
    });
  });

  group('広告を消す（課金）', () {
    test('購入が通知だけで届いても（待っている人がいなくても）広告を消し、再起動後も残る', () async {
      final (_, money, ads, store, _) = await setup();
      await store.delivered!(PurchaseService.removeAdsId);
      expect(money.adFree, isTrue);
      expect(ads.disposed, 1);
      final p = await SharedPreferences.getInstance();
      final again = Monetization(p, ads: FakeAds(), store: FakeStore());
      await again.start();
      expect(again.adFree, isTrue);
    });

    test('購入の結果が「成立」でも、通知が届かなければ広告なしにしない（入口は通知だけ）', () async {
      final (_, money, _, store, _) = await setup();
      store.deliverBeforeReturn = false;
      expect(await money.buy(), PurchaseOutcome.purchased);
      expect(money.adFree, isFalse);
    });

    test('同じ購入が二度届いても、二度は渡らない', () async {
      final (_, money, ads, store, _) = await setup();
      var changes = 0;
      money.addListener(() => changes++);
      await store.delivered!(PurchaseService.removeAdsId);
      await store.delivered!(PurchaseService.removeAdsId);
      expect(money.adFree, isTrue);
      expect(ads.disposed, 1);
      expect(changes, 2, reason: '値は1回変わるだけ（2回目の通知は同じ値を書くだけ）');
    });

    test('知らない商品IDの通知では広告を消さない', () async {
      final (_, money, _, store, _) = await setup();
      await store.delivered!('other');
      expect(money.adFree, isFalse);
    });

    test('再インストール後は、端末の購入記録から広告なしに戻す', () async {
      SharedPreferences.setMockInitialValues({});
      final p = await SharedPreferences.getInstance();
      final money = Monetization(p, ads: FakeAds(), store: FakeStore()..entitlement = true);
      await money.start();
      expect(money.adFree, isTrue);
    });

    test('返金されたら広告を戻す。権利が残っていれば戻さない', () async {
      final (_, money, _, store, _) = await setup();
      await store.delivered!(PurchaseService.removeAdsId);
      store.entitlement = true;
      await store.revoked!(PurchaseService.removeAdsId);
      expect(money.adFree, isTrue);
      store.entitlement = false;
      await store.revoked!(PurchaseService.removeAdsId);
      expect(money.adFree, isFalse);
    });

    test('ストアの通知は、受け取りが終わってから completePurchase を返す', () async {
      final iap = FakeIap();
      final s = StorePurchaseService(iap: iap);
      final got = <String>[];
      s.onDelivered = (id) async {
        expect(iap.completed, isEmpty, reason: '受け取る前に完了を返すと、ストアは二度と送ってこない');
        got.add(id);
      };
      await s.handleUpdates([purchase(PurchaseStatus.purchased)]);
      expect(got, [PurchaseService.removeAdsId]);
      expect(iap.completed, [PurchaseService.removeAdsId]);
    });

    test('受け取りに失敗した購入は completePurchase を返さない（次の起動で届き直す）', () async {
      final iap = FakeIap();
      final s = StorePurchaseService(iap: iap);
      s.onDelivered = (_) async => throw StateError('保存できなかった');
      await s.handleUpdates([purchase(PurchaseStatus.purchased)]);
      expect(iap.completed, isEmpty);
    });

    test('返金済みの取引は「購入」として渡さず、広告を戻す', () async {
      final iap = FakeIap();
      final s = StorePurchaseService(iap: iap);
      final got = <String>[];
      final revoked = <String>[];
      s.onDelivered = (id) async => got.add(id);
      s.onRevoked = (id) async => revoked.add(id);
      await s.handleUpdates([purchase(PurchaseStatus.restored, json: '{"revocationDate":1}')]);
      expect(got, isEmpty);
      expect(revoked, [PurchaseService.removeAdsId]);
    });

    test('値段と広告なしかをゲームに送る。値段が取れなくてもストアの状態は送る', () async {
      final (b, _, _, store, js) = await setup();
      await b.handle('{"type":"refresh"}');
      expect(js.last, startsWith('window.touSetApp&&touSetApp('));
      expect(js.last, contains('"price":"¥370"'));
      expect(js.last, contains('"adFree":false'));
      store.priceFails = true;
      await b.pushApp();
      final m = jsonDecode(js.last.substring(js.last.indexOf('(') + 1, js.last.lastIndexOf(')'))) as Map;
      expect(m['price'], isNull);
      expect(m['storeOk'], isTrue);
    });

    test('買ったら「広告なし」をゲームに送る。承認待ち・結果待ちはそれぞれの文で知らせる', () async {
      final (b, _, _, store, js) = await setup();
      store.buyResult = PurchaseOutcome.pending;
      await b.handle('{"type":"buy"}');
      expect(js.last, contains('保護者の承認'));
      store.buyResult = PurchaseOutcome.timedOut;
      await b.handle('{"type":"buy"}');
      expect(js.last, contains('まだ届いていません'));
      store.buyResult = PurchaseOutcome.purchased;
      await b.handle('{"type":"buy"}');
      expect(js.last, contains('"adFree":true'));
      expect(js.last, contains('広告を消しました'));
    });

    test('復元: 戻ったら「復元しました」、無ければ「見つかりません」', () async {
      final (b, _, _, store, js) = await setup();
      await b.handle('{"type":"restore"}');
      expect(js.last, contains('見つかりませんでした'));
      store.entitlement = true;
      await b.handle('{"type":"restore"}');
      expect(js.last, contains('購入を復元しました'));
      expect(js.last, contains('"adFree":true'));
    });

    test('商品IDは App Store Connect のものと同じ', () {
      expect(PurchaseService.removeAdsId, 'com.namiki.tounoishi.removeads');
      expect(PurchaseService.allIds, {PurchaseService.removeAdsId});
    });
  });

  group('設定とゲーム本体の約束', () {
    test('Info.plist は AdMob のテスト用アプリIDと SKAdNetwork を持ち、ATT は出さない', () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      expect(
        RegExp(r'<key>GADApplicationIdentifier</key>\s*<string>ca-app-pub-3940256099942544~1458002511</string>').hasMatch(plist),
        isTrue,
      );
      expect(plist, contains('<key>SKAdNetworkItems</key>'));
      expect('cstr6suwn9.skadnetwork'.allMatches(plist), hasLength(1));
      expect(plist.contains('NSUserTrackingUsageDescription'), isFalse);
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec.contains('app_tracking_transparency'), isFalse);
    });

    test('ゲーム本体が広告・課金の窓口を持ち、負けた時と塔が伸びる時に頼んでいる', () {
      final html = File(gameAsset).readAsStringSync();
      for (final name in [
        'window.TouApp.postMessage',
        'window.touSetApp=',
        'window.touInterDone=',
        'window.touAdShowing=',
        "type:'inter'",
        "type:'prepInter'",
        "type:'buy'",
        "type:'restore'",
        "appInter('lose',showResult)",
        "appInter('grow',",
        'id="tshop"',
        '広告を消す',
        '購入を復元',
        '広告なし',
      ]) {
        expect(html.contains(name), isTrue, reason: name);
      }
      // アプリの外（ブラウザ）では何もしない
      expect(html, contains('function inApp(){try{return !!window.TouApp;}'));
      // 保存の窓口は残っている
      expect(html, contains('window.TouStore'));
      expect(html, contains('window.__boot'));
      expect(html, contains('window.__saveNow'));
    });
  });

  group('スマホの遊びやすさ（0.4.0）', () {
    test('掘った時の振動の頼みを受けて、強さを渡す', () async {
      final (_, money, _, _, _) = await setup();
      final kinds = <String>[];
      final b = GameBridge(money: money, runJs: (s) async {}, haptic: kinds.add);
      await b.handle('{"type":"haptic","kind":"light"}');
      await b.handle('{"type":"haptic","kind":"medium"}');
      await b.handle('{"type":"haptic"}');
      await b.handle('{"type":"haptic","kind":"ありえない"}');
      expect(kinds, ['light', 'medium', 'light', 'light']);
    });

    test('ゲームが振動を頼み、裏に回る時の停止の口を持っている', () {
      final html = File(gameAsset).readAsStringSync();
      // ゲーム側とアプリ側の名前がずれると、黙って振動しない・止まらない
      expect(html, contains("appPost({type:'haptic'"));
      expect(html, contains('window.__pause=function'));
      expect(pauseJs, contains('window.__pause'));
      // hidden の部品が表示されたままにならない（アプリの HTML には Artifact の既定の CSS が無い）
      expect(html, contains('[hidden]{display:none!important}'));
      // 一覧・遊び方は下から出るシートの中にある
      for (final id in ['id="sheet"', 'id="blist"', 'id="bhelp"', 'id="zin"', 'id="heroes"', 'id="spane-help"']) {
        expect(html, contains(id), reason: id);
      }
    });
  });
}
