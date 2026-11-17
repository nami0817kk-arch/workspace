import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youth_academy/monetization/ad_service.dart';
import 'package:youth_academy/monetization/bridge.dart';
import 'package:youth_academy/monetization/entitlements.dart';
import 'package:youth_academy/monetization/purchase_service.dart';

/// 差し替えの広告。再生を Completer で止められる。
class FakeAds implements AdService {
  int interstitials = 0;
  int prepared = 0;
  bool rewardedReady = true;
  Completer<RewardResult>? rewardGate;
  Completer<void>? initGate;
  bool initialized = false;

  @override
  Future<void> initialize() async {
    if (initGate != null) await initGate!.future;
    initialized = true;
  }

  @override
  bool get isRewardedAdReady => rewardedReady;
  @override
  bool get isInterstitialReady => true;
  @override
  Future<bool> waitForRewarded(Duration max) async => rewardedReady;
  @override
  void ensureLoaded() {}
  @override
  void prepareInterstitial() => prepared++;
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

/// 差し替えの課金（橋の検査用）。買う操作の戻りより先に「届いた」通知を流す（待ち手が居ない届き方も試せる）。
class FakeStore implements PurchaseService {
  Future<void> Function(String, String?)? delivered;
  Future<void> Function(String)? revoked;
  PurchaseOutcome next = PurchaseOutcome.purchased;
  int n = 0;
  int buys = 0;
  final List<String> order = [];
  Map<String, bool?> entitlement = {};

  @override
  set onDelivered(Future<void> Function(String productId, String? purchaseId)? callback) => delivered = callback;
  @override
  set onRevoked(Future<void> Function(String productId)? callback) => revoked = callback;
  @override
  Future<void> initialize() async => order.add('purchases');
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<Map<String, String>> prices() async => {productRemoveAds: '¥610'};
  @override
  Future<PurchaseOutcome> buy(String productId) async {
    buys++;
    if (next == PurchaseOutcome.purchased) await delivered?.call(productId, 'tx${n++}');
    return next;
  }

  @override
  Future<PurchaseOutcome> restore() async {
    await delivered?.call(productRemoveAds, 'restored');
    return PurchaseOutcome.purchased;
  }

  @override
  Future<bool?> hasEntitlement(String productId) async => entitlement[productId];

  @override
  void dispose() {}
}

/// 差し替えの App Store（本物の受け取り処理 StorePurchaseService の検査用）。
/// 購入の結果は、買う操作の戻りとは別に、通知の流れ（purchaseStream）で後から届く。
class FakeApi implements StoreApi {
  final ctrl = StreamController<List<PurchaseDetails>>.broadcast();
  final List<String> completed = [];
  final List<String> bought = [];
  List<StoreTransaction>? records = [];

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => ctrl.stream;
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<List<ProductDetails>> queryProducts(Set<String> ids) async => [
    for (final id in ids) ProductDetails(id: id, title: id, description: '', price: '¥250', rawPrice: 250, currencyCode: 'JPY'),
  ];
  @override
  Future<bool> buy(ProductDetails product, {required bool consumable}) async {
    bought.add(product.id);
    return true;
  }

  @override
  Future<void> completePurchase(PurchaseDetails p) async => completed.add('${p.productID}:${p.purchaseID}');
  @override
  Future<void> restorePurchases() async {}
  @override
  Future<List<StoreTransaction>?> transactions() async => records;

  void push(List<PurchaseDetails> l) => ctrl.add(l);
}

PurchaseDetails pd(String id, String tx, {PurchaseStatus status = PurchaseStatus.purchased, String json = ''}) => PurchaseDetails(
  purchaseID: tx,
  productID: id,
  verificationData: PurchaseVerificationData(localVerificationData: json, serverVerificationData: '', source: 'app_store'),
  transactionDate: '0',
  status: status,
)..pendingCompletePurchase = true;

/// 通知の処理が進むまで少し回す
Future<void> settle([int n = 5]) async {
  for (var i = 0; i < n; i++) {
    await Future<void>.delayed(Duration.zero);
  }
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

  test('受け取りの控えは ya_ の外に置き、前の名前（ya_ent_seen）の控えも引き継ぐ', () async {
    SharedPreferences.setMockInitialValues({'ya_ent_seen': <String>['youth_ticket_1:t1']});
    final p = await SharedPreferences.getInstance();
    final e = Entitlements();
    expect(await e.grant(p, 'youth_ticket_1', purchaseId: 't1'), isFalse);
    expect(await e.grant(p, 'youth_ticket_1', purchaseId: 't2'), isTrue);
    expect(p.containsKey('ya_ent_seen'), isFalse);
    expect(p.getStringList('ent_seen'), containsAll(<String>['youth_ticket_1:t1', 'youth_ticket_1:t2']));
    expect(p.getKeys().where((k) => k.startsWith('ya_')).every((k) => p.get(k) is String), isTrue);
  });

  test('最初は何も買っていない（セーブ枠の追加0・チケット0）', () {
    final e = Entitlements.load(prefs);
    expect([e.noAds, e.eye, e.slots, e.tickets, e.used], [false, false, 0, 0, 0]);
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

  test('同じ購入が続けて届いても（控えを書き終える前でも）二度渡さない', () async {
    final e = Entitlements();
    final r = await Future.wait([e.grant(prefs, productTicket3, purchaseId: 'dup'), e.grant(prefs, productTicket3, purchaseId: 'dup')]);
    expect(r.where((x) => x).length, 1);
    expect(e.tickets, 3);
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

  test('チケットを使うと通し番号が進み、迎え終えた番号は控えに残る（使った枚数より大きい番号は受け付けない）', () async {
    final e = Entitlements(tickets: 2);
    expect(await e.useTicket(prefs), 1);
    expect(await e.useTicket(prefs), 2);
    expect(await e.useTicket(prefs), isNull);
    await e.markSpent(prefs, [1, 2, 9]);
    expect(e.spent, [1, 2]);
    final back = Entitlements.load(prefs);
    expect([back.used, back.tickets, back.spent], [2, 0, [1, 2]]);
  });

  group('本物の受け取り処理（StorePurchaseService）', () {
    late FakeApi api;
    late StorePurchaseService svc;
    late List<String> got;
    late List<String> revokedIds;

    setUp(() async {
      api = FakeApi();
      svc = StorePurchaseService(api: api, restoreWait: const Duration(milliseconds: 80));
      got = [];
      revokedIds = [];
      svc.onDelivered = (id, tx) async => got.add('$id:$tx');
      svc.onRevoked = (id) async => revokedIds.add(id);
      await svc.initialize();
    });

    test('受け取れたら完了通知を返し、買っている商品の結果になる', () async {
      final f = svc.buy(productTicket1);
      await settle();
      expect(api.bought, [productTicket1]);
      api.push([pd(productTicket1, 't1')]);
      expect(await f, PurchaseOutcome.purchased);
      await svc.idle;
      expect(got, ['$productTicket1:t1']);
      expect(api.completed, ['$productTicket1:t1']);
    });

    test('受け取りに失敗したら完了通知を返さず、結果は「受け取れなかった」', () async {
      svc.onDelivered = (id, tx) async => throw StateError('書けない');
      final f = svc.buy(productTicket1);
      await settle();
      api.push([pd(productTicket1, 't1')]);
      expect(await f, PurchaseOutcome.undelivered);
      await svc.idle;
      expect(api.completed, isEmpty, reason: '次の起動でもう一度届くように');
    });

    test('別の商品の取引が届いても、いま買っている商品の結果にしない', () async {
      final f = svc.buy(productKeenEye);
      await settle();
      var done = false;
      unawaited(f.then((_) => done = true));
      api.push([pd(productTicket3, 'other')]); // 起動時の再送・家族の承認など
      await svc.idle;
      await settle();
      expect(done, isFalse);
      expect(got, ['$productTicket3:other'], reason: '別の商品も受け取りはする');
      expect(api.completed, ['$productTicket3:other']);
      api.push([pd(productKeenEye, 'mine')]);
      expect(await f, PurchaseOutcome.purchased);
    });

    test('同じ取引が続けて届いても、受け取りは1本ずつ順に進み二重にならない', () async {
      final e = Entitlements();
      var running = 0;
      var overlap = false;
      svc.onDelivered = (id, tx) async {
        running++;
        if (running > 1) overlap = true;
        await Future<void>.delayed(const Duration(milliseconds: 5));
        await e.grant(prefs, id, purchaseId: tx);
        running--;
      };
      api.push([pd(productTicket3, 'same')]);
      api.push([pd(productTicket3, 'same')]);
      await settle();
      await svc.idle;
      await svc.idle;
      expect(overlap, isFalse);
      expect(e.tickets, 3);
      expect(api.completed.length, 2, reason: '二度目も片付ける（渡しはしない）');
    });

    test('返金された取引は権利を戻して片付ける（購入の結果にはしない）', () async {
      api.push([pd(productRemoveAds, 'r1', json: '{"revocationDate":123}')]);
      await settle();
      await svc.idle;
      expect(revokedIds, [productRemoveAds]);
      expect(got, isEmpty);
      expect(api.completed, ['$productRemoveAds:r1']);
    });

    test('保護者の承認待ちは「承認待ち」で返し、何も渡さない', () async {
      final f = svc.buy(productRemoveAds);
      await settle();
      api.push([pd(productRemoveAds, 'p', status: PurchaseStatus.pending)]);
      expect(await f, PurchaseOutcome.pending);
      expect(got, isEmpty);
    });

    test('ほかの商品を買っている最中は、重ねて買いに行かない', () async {
      final f = svc.buy(productTicket1);
      await settle();
      expect(await svc.buy(productTicket3), PurchaseOutcome.busy);
      api.push([pd(productTicket1, 't')]);
      expect(await f, PurchaseOutcome.purchased);
    });

    test('復元：買い切りの記録が無ければすぐ「見つからない」、あれば届くまで待ち、来なければ「確認中」', () async {
      api.records = [];
      expect(await svc.restore(), PurchaseOutcome.unavailable);
      api.records = [const StoreTransaction(productRemoveAds)];
      final f = svc.restore();
      await settle();
      api.push([pd(productRemoveAds, 'old', status: PurchaseStatus.restored)]);
      expect(await f, PurchaseOutcome.purchased);
      api.records = null; // 記録が読めない
      expect(await svc.restore(), PurchaseOutcome.pending);
    });

    test('端末の記録：有効な取引が1つでもあれば権利あり、全部返金なら無し、記録が無ければ分からない', () async {
      api.records = [const StoreTransaction(productRemoveAds, revoked: true), const StoreTransaction(productRemoveAds)];
      expect(await svc.hasEntitlement(productRemoveAds), isTrue);
      api.records = [const StoreTransaction(productRemoveAds, revoked: true)];
      expect(await svc.hasEntitlement(productRemoveAds), isFalse);
      expect(await svc.hasEntitlement(productKeenEye), isNull);
      api.records = null;
      expect(await svc.hasEntitlement(productRemoveAds), isNull);
    });
  });

  test('橋：買うと権利に書いてからページへ知らせる（買う操作の戻りに頼らない）', () async {
    expect(await bridge.handle('{"cmd":"buy","id":"youth_remove_ads"}'), isTrue);
    expect(sent.any((m) => m['ev'] == 'purchase' && m['outcome'] == 'purchased'), isTrue);
    expect(lastEnt()['noAds'], isTrue);
    expect(Entitlements.load(prefs).noAds, isTrue, reason: '再起動しても残る');
  });

  test('橋：上限に達した商品は買いに行かない（お金だけ取られない）', () async {
    for (var i = 0; i < 4; i++) {
      await store.delivered!(productSaveSlot, 's$i');
    }
    await bridge.handle('{"cmd":"buy","id":"youth_save_slot"}');
    expect(store.buys, 0);
    expect(sent.last, {'ev': 'purchase', 'id': productSaveSlot, 'outcome': 'limit'});
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

  test('橋：返金が届いたら広告が戻る。ほかに有効な取引が残っていれば戻さない', () async {
    await bridge.handle('{"cmd":"buy","id":"youth_remove_ads"}');
    store.entitlement[productRemoveAds] = true; // 買い直した分など
    await store.revoked!(productRemoveAds);
    expect(lastEnt()['noAds'], isTrue);
    store.entitlement[productRemoveAds] = false;
    await store.revoked!(productRemoveAds);
    expect(lastEnt()['noAds'], isFalse);
  });

  test('橋：起動時に端末の記録と照らし合わせる（入れ直しで戻る・閉じている間の返金で外れる）', () async {
    store.entitlement[productKeenEye] = true;
    await bridge.start();
    expect(lastEnt()['eye'], isTrue);
    store.entitlement[productKeenEye] = false;
    await bridge.reconcile();
    expect(Entitlements.load(prefs).eye, isFalse);
  });

  test('橋：購入の受け取りを先に始め、広告の準備は待たない', () async {
    ads.initGate = Completer<void>();
    await bridge.start().timeout(const Duration(seconds: 2));
    expect(store.order, ['purchases']);
    expect(ads.initialized, isFalse, reason: '広告の準備が終わる前に start は戻る');
    ads.initGate!.complete();
  });

  test('橋：チケットを使うと1枚減り、0枚では減らない。迎え終えた番号を控える', () async {
    await bridge.handle('{"cmd":"buy","id":"youth_ticket_1"}');
    await bridge.handle('{"cmd":"useTicket"}');
    expect([lastEnt()['tickets'], lastEnt()['used']], [0, 1]);
    await bridge.handle('{"cmd":"useTicket"}');
    expect([lastEnt()['tickets'], lastEnt()['used']], [0, 1]);
    await bridge.handle('{"cmd":"ticketSpent","serials":[1]}');
    expect(lastEnt()['spent'], [1]);
  });

  test('橋：起動の挨拶・ショップを開いたときに権利と価格が届く', () async {
    await bridge.handle('{"cmd":"hello","ids":[]}');
    await settle();
    expect(sent.any((m) => m['ev'] == 'ent'), isTrue);
    expect(sent.any((m) => m['ev'] == 'prices' && (m['map'] as Map)['youth_remove_ads'] == '¥610'), isTrue);
    sent.clear();
    await bridge.handle('{"cmd":"prices"}');
    await settle();
    expect(sent.any((m) => m['ev'] == 'prices'), isTrue);
  });

  test('橋：全画面広告は、広告を消した人には出さず、読み込みもしない', () async {
    await bridge.handle('{"cmd":"adPrep"}');
    await bridge.handle('{"cmd":"ad","kind":"interstitial","tag":0}');
    expect([ads.prepared, ads.interstitials], [1, 1]);
    await bridge.handle('{"cmd":"buy","id":"youth_remove_ads"}');
    await bridge.handle('{"cmd":"adPrep"}');
    await bridge.handle('{"cmd":"ad","kind":"interstitial","tag":0}');
    expect([ads.prepared, ads.interstitials], [1, 1]);
  });

  test('橋：ご褒美の動画は見終えたあとに結果が届く（画面を離れても受け取れる）', () async {
    final done = bridge.handle('{"cmd":"ad","kind":"rewarded","tag":7,"reward":{"k":"rest"}}');
    await settle();
    expect(sent.any((m) => m['ev'] == 'adDone'), isFalse, reason: '再生中は結果を出さない');
    ads.rewardGate!.complete(RewardResult.earned);
    await done;
    expect(sent.lastWhere((m) => m['ev'] == 'adDone'), {'ev': 'adDone', 'tag': 7, 'result': 'earned', 'reward': {'k': 'rest'}});
  });

  test('橋：見終えたご褒美は、ページが受け取りを知らせるまで控え、読み直し後の挨拶で渡す', () async {
    final done = bridge.handle('{"cmd":"ad","kind":"rewarded","tag":9,"reward":{"k":"boost","cid":"c1"}}');
    await settle();
    ads.rewardGate!.complete(RewardResult.earned);
    await done;
    sent.clear();
    // ページが読み直された（adDone を受け取れなかった）
    await bridge.handle('{"cmd":"hello","ids":[]}');
    final un = sent.firstWhere((m) => m['ev'] == 'adUnclaimed')['list'] as List;
    expect(un.length, 1);
    expect((un.first as Map)['reward'], {'k': 'boost', 'cid': 'c1'});
    await bridge.handle('{"cmd":"adClaimed","tag":9}');
    sent.clear();
    await bridge.handle('{"cmd":"hello","ids":[]}');
    expect(sent.any((m) => m['ev'] == 'adUnclaimed'), isFalse, reason: '受け取ったら消える');
  });

  test('橋：途中で閉じた動画は控えない', () async {
    final done = bridge.handle('{"cmd":"ad","kind":"rewarded","tag":3}');
    await settle();
    ads.rewardGate!.complete(RewardResult.closedEarly);
    await done;
    expect(prefs.getString(MonetizationBridge.unclaimedKey), isNull);
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

  test('広告の期限：読み込み直後・手前は出せる、超過・未読み込みは出せない（1時間より手前で捨てる）', () {
    final now = DateTime(2026, 11, 17, 12);
    expect(AdMobAdService.isFresh(now, now), isTrue);
    expect(AdMobAdService.isFresh(now.subtract(const Duration(minutes: 54)), now), isTrue);
    expect(AdMobAdService.isFresh(now.subtract(const Duration(minutes: 56)), now), isFalse);
    expect(AdMobAdService.isFresh(null, now), isFalse);
    expect(AdMobAdService.maxAge < const Duration(hours: 1), isTrue);
  });

  group('見終わり待ち（show はすぐ返り、報酬と閉じる通知は後から来る）', () {
    ShowWatch w() => ShowWatch(grace: const Duration(milliseconds: 40), startTimeout: const Duration(milliseconds: 200));

    test('報酬のあとに閉じる → 受け取る', () async {
      final s = w();
      final f = s.run(() async {});
      await settle();
      s.onShowed();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      s.onEarned();
      s.onDismissed();
      expect(await f, RewardResult.earned);
    });

    test('閉じたあとに報酬が遅れて届く → 受け取る', () async {
      final s = w();
      final f = s.run(() async {});
      await settle();
      s.onShowed();
      s.onDismissed();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      s.onEarned();
      expect(await f, RewardResult.earned);
    });

    test('show が戻った時点ではまだ結果を出さない', () async {
      final s = w();
      var done = false;
      unawaited(s.run(() async {}).then((_) => done = true));
      await settle();
      s.onShowed();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(done, isFalse, reason: '表示が始まった後は、閉じられるまで待つ');
      s.onDismissed();
    });

    test('報酬なしで閉じる → 途中で閉じた／表示に失敗 → 失敗／始まらない → 失敗', () async {
      final a = w();
      final fa = a.run(() async {});
      await settle();
      a.onDismissed();
      expect(await fa, RewardResult.closedEarly);
      final b = w();
      final fb = b.run(() async {});
      await settle();
      b.onFailed();
      expect(await fb, RewardResult.showFailed);
      expect(await w().run(() async {}), RewardResult.showFailed);
    });
  });

  test('広告ユニットIDが既定のテスト用のまま（本物は --dart-define で渡す）', () {
    expect(AdMobAdService.isUsingTestUnitId, isTrue);
  });
}
