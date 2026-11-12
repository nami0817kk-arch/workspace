import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youth_academy/monetization/ad_service.dart';
import 'package:youth_academy/monetization/bridge.dart';
import 'package:youth_academy/monetization/entitlements.dart';
import 'package:youth_academy/monetization/purchase_service.dart';

/// 差し替えの広告。再生を Completer で止められる。
class FakeAds implements AdService {
  int interstitials = 0;
  bool rewardedReady = true;
  Completer<RewardResult>? rewardGate;

  @override
  Future<void> initialize() async {}
  @override
  bool get isRewardedAdReady => rewardedReady;
  @override
  bool get isInterstitialReady => true;
  @override
  Future<bool> waitForRewarded(Duration max) async => rewardedReady;
  @override
  void ensureLoaded() {}
  @override
  Future<RewardResult> showRewardedAd() => (rewardGate ??= Completer<RewardResult>()).future;
  @override
  Future<bool> showInterstitialAd() async {
    interstitials++;
    return true;
  }

  @override
  void dispose() {}
}

/// 差し替えの課金。買う操作の戻りより先に「届いた」通知を流す（待ち手が居ない届き方も試せる）。
class FakeStore implements PurchaseService {
  Future<void> Function(String, String?)? delivered;
  Future<void> Function(String)? revoked;
  PurchaseOutcome next = PurchaseOutcome.purchased;
  int n = 0;

  @override
  set onDelivered(Future<void> Function(String productId, String? purchaseId)? callback) => delivered = callback;
  @override
  set onRevoked(Future<void> Function(String productId)? callback) => revoked = callback;
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<Map<String, String>> prices() async => {productRemoveAds: '¥610'};
  @override
  Future<PurchaseOutcome> buy(String productId) async {
    if (next == PurchaseOutcome.purchased) await delivered?.call(productId, 'tx${n++}');
    return next;
  }

  @override
  Future<PurchaseOutcome> restore() async {
    await delivered?.call(productRemoveAds, 'restored');
    return PurchaseOutcome.purchased;
  }

  @override
  void dispose() {}
}

void main() {
  late SharedPreferences prefs;
  late FakeAds ads;
  late FakeStore store;
  late List<Map<String, dynamic>> sent;
  late MonetizationBridge bridge;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    ads = FakeAds();
    store = FakeStore();
    sent = [];
    bridge = MonetizationBridge(prefs: prefs, ads: ads, purchases: store, send: (j) => sent.add(jsonDecode(j) as Map<String, dynamic>));
  });

  Map<String, dynamic> lastEnt() => (sent.lastWhere((m) => m['ev'] == 'ent'))['v'] as Map<String, dynamic>;

  test('最初は何も買っていない（セーブ枠の追加0・チケット0）', () {
    final e = Entitlements.load(prefs);
    expect([e.noAds, e.eye, e.slots, e.tickets], [false, false, 0, 0]);
  });

  test('商品ごとの特典：広告を消す・見抜く目・セーブ枠+1・チケット+1/+3', () async {
    final e = Entitlements();
    await e.grant(prefs, productRemoveAds, purchaseId: 'a');
    await e.grant(prefs, productKeenEye, purchaseId: 'b');
    await e.grant(prefs, productSaveSlot, purchaseId: 'c');
    await e.grant(prefs, productTicket1, purchaseId: 'd');
    await e.grant(prefs, productTicket3, purchaseId: 'e');
    expect([e.noAds, e.eye, e.slots, e.tickets], [true, true, 1, 4]);
    expect(Entitlements.load(prefs).tickets, 4, reason: '端末に保存される');
  });

  test('セーブ枠は最大5枠（追加4）で止まる', () async {
    final e = Entitlements();
    for (var i = 0; i < 9; i++) {
      await e.grant(prefs, productSaveSlot, purchaseId: 'x$i');
    }
    expect(e.slots, 4);
  });

  test('同じ購入の再送では二度渡さない（落ちたあとの再送で増えすぎない）', () async {
    final e = Entitlements();
    expect(await e.grant(prefs, productTicket1, purchaseId: 'same'), isTrue);
    expect(await e.grant(prefs, productTicket1, purchaseId: 'same'), isFalse);
    expect(e.tickets, 1);
  });

  test('知らない商品IDは何も渡さない', () async {
    final e = Entitlements();
    expect(await e.grant(prefs, 'other', purchaseId: 'z'), isFalse);
  });

  test('返金された非消費型は権利を戻す（消費型の枠・チケットは触らない）', () async {
    final e = Entitlements();
    await e.grant(prefs, productRemoveAds, purchaseId: 'a');
    await e.grant(prefs, productTicket1, purchaseId: 'b');
    await e.revoke(prefs, productRemoveAds);
    expect(e.noAds, isFalse);
    expect(e.tickets, 1);
  });

  test('橋：買うと権利に書いてからページへ知らせる（買う操作の戻りに頼らない）', () async {
    expect(await bridge.handle('{"cmd":"buy","id":"youth_remove_ads"}'), isTrue);
    expect(sent.any((m) => m['ev'] == 'purchase' && m['outcome'] == 'purchased'), isTrue);
    expect(lastEnt()['noAds'], isTrue);
    expect(Entitlements.load(prefs).noAds, isTrue, reason: '再起動しても残る');
  });

  test('橋：待っている人が居ないときに届いた購入も受け取る（家族の承認・起動時の再送）', () async {
    await store.delivered!(productTicket3, 'late-1');
    expect(lastEnt()['tickets'], 3);
    expect(Entitlements.load(prefs).tickets, 3);
  });

  test('橋：取りやめ・保護者の承認待ちでは何も渡らない', () async {
    store.next = PurchaseOutcome.canceled;
    await bridge.handle('{"cmd":"buy","id":"youth_keen_eye"}');
    store.next = PurchaseOutcome.pending;
    await bridge.handle('{"cmd":"buy","id":"youth_keen_eye"}');
    expect(Entitlements.load(prefs).eye, isFalse);
  });

  test('橋：返金が届いたら広告が戻る', () async {
    await bridge.handle('{"cmd":"buy","id":"youth_remove_ads"}');
    await store.revoked!(productRemoveAds);
    expect(lastEnt()['noAds'], isFalse);
  });

  test('橋：チケットを使うと1枚減り、0枚では減らない', () async {
    await bridge.handle('{"cmd":"buy","id":"youth_ticket_1"}');
    await bridge.handle('{"cmd":"useTicket"}');
    expect(lastEnt()['tickets'], 0);
    await bridge.handle('{"cmd":"useTicket"}');
    expect(lastEnt()['tickets'], 0);
  });

  test('橋：起動の挨拶で権利と価格が届く', () async {
    await bridge.handle('{"cmd":"hello","ids":[]}');
    await Future<void>.delayed(Duration.zero);
    expect(sent.any((m) => m['ev'] == 'ent'), isTrue);
    expect(sent.any((m) => m['ev'] == 'prices' && (m['map'] as Map)['youth_remove_ads'] == '¥610'), isTrue);
  });

  test('橋：全画面広告は、広告を消した人には出さない', () async {
    await bridge.handle('{"cmd":"ad","kind":"interstitial","tag":0}');
    expect(ads.interstitials, 1);
    await bridge.handle('{"cmd":"buy","id":"youth_remove_ads"}');
    await bridge.handle('{"cmd":"ad","kind":"interstitial","tag":0}');
    expect(ads.interstitials, 1);
  });

  test('橋：ご褒美の動画は見終えたあとに結果が届く（画面を離れても受け取れる）', () async {
    final done = bridge.handle('{"cmd":"ad","kind":"rewarded","tag":7}');
    await Future<void>.delayed(Duration.zero);
    expect(sent.any((m) => m['ev'] == 'adDone'), isFalse, reason: '再生中は結果を出さない');
    ads.rewardGate!.complete(RewardResult.earned);
    await done;
    expect(sent.lastWhere((m) => m['ev'] == 'adDone'), {'ev': 'adDone', 'tag': 7, 'result': 'earned'});
  });

  test('橋：動画が読み込めていなければ unavailable', () async {
    ads.rewardedReady = false;
    await bridge.handle('{"cmd":"ad","kind":"rewarded","tag":1}');
    expect(sent.last['result'], 'unavailable');
  });

  test('橋：保存の依頼（k と v）は橋では扱わない', () async {
    expect(await bridge.handle('{"k":"slot","v":"0"}'), isFalse);
    expect(await bridge.handle('壊れた文字'), isFalse);
  });

  test('広告ユニットIDが既定のテスト用のまま（本物は --dart-define で渡す）', () {
    expect(AdMobAdService.isUsingTestUnitId, isTrue);
  });
}
