// 本物の購入処理(StorePurchaseService)を、偽の App Store(InAppPurchasePlatform)につないで試す(2026-11-05)。
// monetization_test の FakeStore は「決まり」を見るための偽物で、ストアとのやりとりそのものは通らない。
// ここでは docs/app-pitfalls.md 1番(払ったのに届かない)を、本物のコードで見張る:
// - 待っている人がいなくても届いた購入を受け取る
// - 受け取りが終わるまで完了通知(completePurchase)を返さない
// - 返金された取引を「買えた」と扱わない
// - StoreKit 2 と同じく、buyNonConsumable はすぐ戻り、結果は後から通知で届く
// (projects/baseball-manager/test/store_purchase_test.dart を1商品に絞って写したもの)
import 'dart:async';

import 'package:basketball_career/monetization/purchase_service.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';

/// 偽の App Store。購入の通知は [send] で好きなときに流す。
class FakeStoreKit extends InAppPurchasePlatform {
  final _stream = StreamController<List<PurchaseDetails>>.broadcast();
  bool available = true;
  Set<String> known = {PurchaseService.removeAdsId};
  final List<String> buyCalls = [];
  final List<PurchaseDetails> completed = [];
  int restoreCalls = 0;
  int queryCalls = 0;

  /// 復元を頼まれたときに流す取引。
  List<PurchaseDetails> Function()? onRestore;
  Object? buyThrows;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _stream.stream;

  void send(List<PurchaseDetails> p) => _stream.add(p);
  void fail(Object e) => _stream.addError(e);

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) async {
    queryCalls++;
    return ProductDetailsResponse(
      productDetails: [
        for (final id in ids.where(known.contains))
          ProductDetails(
              id: id, title: id, description: '', price: '¥370', rawPrice: 370, currencyCode: 'JPY'),
      ],
      notFoundIDs: [...ids.where((i) => !known.contains(i))],
    );
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    buyCalls.add(purchaseParam.productDetails.id);
    if (buyThrows != null) throw buyThrows!;
    // 本物(StoreKit 2)と同じく、ここでは何も通知せずに戻る。結果はテストが send で流す
    return true;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async => completed.add(purchase);

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {
    restoreCalls++;
    final r = onRestore?.call();
    if (r != null && r.isNotEmpty) Future(() => send(r));
  }
}

PurchaseDetails tx(String id, PurchaseStatus status, {bool revoked = false, bool pending = true}) =>
    PurchaseDetails(
      purchaseID: 'tx-$id-${status.name}',
      productID: id,
      verificationData: PurchaseVerificationData(
        localVerificationData:
            revoked ? '{"productId":"$id","revocationDate":1730000000000}' : '{"productId":"$id"}',
        serverVerificationData: '',
        source: 'app_store',
      ),
      transactionDate: '0',
      status: status,
    )..pendingCompletePurchase = pending;

const ads = PurchaseService.removeAdsId;

/// 通知の処理(非同期)が流れ終わるのを待つ。
Future<void> settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeStoreKit kit;
  late StorePurchaseService s;
  late List<String> delivered;
  late List<String> revoked;

  setUp(() async {
    // InAppPurchase.instance が Android/iOS の本物を登録しないよう、どちらでもない環境にしておく
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    kit = FakeStoreKit();
    InAppPurchasePlatform.instance = kit;
    delivered = [];
    revoked = [];
    s = StorePurchaseService();
    s.onDelivered = (id) async {
      delivered.add(id);
    };
    s.onRevoked = (id) async {
      revoked.add(id);
    };
    await s.initialize();
  });

  tearDown(() {
    s.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  group('払ったのに届かない、を起こさない(docs/app-pitfalls.md 1番)', () {
    test('待っている人がいなくても届いた購入を受け取り、そのあとで完了を返す', () async {
      kit.send([tx(ads, PurchaseStatus.purchased)]); // 起動時の再送・家族の承認・別の端末
      await settle();
      expect(delivered, [ads]);
      expect(kit.completed.map((p) => p.productID), [ads]);
    });

    test('受け取りに失敗したら完了を返さない(次の起動でストアがもう一度送ってくる)', () async {
      s.onDelivered = (id) async => throw StateError('保存できなかった');
      kit.send([tx(ads, PurchaseStatus.purchased)]);
      await settle();
      expect(kit.completed, isEmpty);
      s.onDelivered = (id) async {
        delivered.add(id);
      };
      kit.send([tx(ads, PurchaseStatus.purchased)]);
      await settle();
      expect(delivered, [ads]);
      expect(kit.completed, hasLength(1));
    });

    test('受け取りが終わる前に完了を返さない(保存の途中で完了しない)', () async {
      final gate = Completer<void>();
      s.onDelivered = (id) async {
        await gate.future;
        delivered.add(id);
      };
      kit.send([tx(ads, PurchaseStatus.purchased)]);
      await settle();
      expect(kit.completed, isEmpty);
      gate.complete();
      await settle();
      expect(delivered, [ads]);
      expect(kit.completed, hasLength(1));
    });

    test('StoreKit 2 の形: 購入はすぐ戻り、結果は後から通知で届く。それで「買えた」になる', () async {
      final r = s.buyRemoveAds();
      await settle();
      expect(kit.buyCalls, [ads]);
      kit.send([tx(ads, PurchaseStatus.purchased)]);
      expect(await r, PurchaseOutcome.purchased);
      expect(delivered, [ads]);
      expect(kit.completed, hasLength(1));
    });

    test('復元で戻した購入も受け取り、完了を返す', () async {
      kit.onRestore = () => [tx(ads, PurchaseStatus.restored)];
      expect(await s.restore(), PurchaseOutcome.purchased);
      await settle();
      expect(delivered, [ads]);
      expect(kit.completed, hasLength(1));
    });

    test('完了待ちでない取引には完了を返さない(二重に返さない)', () async {
      kit.send([tx(ads, PurchaseStatus.purchased, pending: false)]);
      await settle();
      expect(delivered, [ads]);
      expect(kit.completed, isEmpty);
    });

    test('自分の商品でない取引は受け取らない', () async {
      kit.send([tx('other_app_item', PurchaseStatus.purchased)]);
      await settle();
      expect(delivered, isEmpty);
    });
  });

  group('購入の結果', () {
    test('2度押ししても、買いに行くのは1回で、同じ結果が返る', () async {
      final a = s.buyRemoveAds();
      final b = s.buyRemoveAds();
      await settle();
      expect(kit.buyCalls, [ads]);
      kit.send([tx(ads, PurchaseStatus.purchased)]);
      expect(await a, PurchaseOutcome.purchased);
      expect(await b, PurchaseOutcome.purchased);
      expect(delivered, [ads]);
    });

    test('取りやめは「取りやめ」。何も渡さない', () async {
      final r = s.buyRemoveAds();
      await settle();
      kit.send([tx(ads, PurchaseStatus.canceled, pending: false)]);
      expect(await r, PurchaseOutcome.canceled);
      expect(delivered, isEmpty);
    });

    test('StoreKit が取りやめを例外で返しても「失敗」と出さない', () async {
      kit.buyThrows = _PlatformExceptionLike('storekit2_purchase_cancelled userCancelled');
      expect(await s.buyRemoveAds(), PurchaseOutcome.canceled);
      kit.buyThrows = StateError('network');
      expect(await s.buyRemoveAds(), PurchaseOutcome.failed);
      expect(delivered, isEmpty);
    });

    test('ストアのエラーは「失敗」。何も渡さず、取引は片付ける', () async {
      final r = s.buyRemoveAds();
      await settle();
      kit.send([tx(ads, PurchaseStatus.error)]);
      expect(await r, PurchaseOutcome.failed);
      expect(delivered, isEmpty);
      expect(kit.completed, hasLength(1));
    });

    test('保護者の承認待ちは「承認待ち」。承認されたら、待つ人がいなくても届く', () async {
      final r = s.buyRemoveAds();
      await settle();
      kit.send([tx(ads, PurchaseStatus.pending, pending: false)]);
      expect(await r, PurchaseOutcome.pending);
      expect(delivered, isEmpty);
      kit.send([tx(ads, PurchaseStatus.purchased)]); // 数時間後に承認
      await settle();
      expect(delivered, [ads]);
      expect(kit.completed, hasLength(1));
    });

    test('商品が見つからなければ買いに行かない', () async {
      kit.known = {};
      expect(await s.buyRemoveAds(), PurchaseOutcome.unavailable);
      expect(kit.buyCalls, isEmpty);
    });

    test('通知が5分来なければ「承認待ち」で戻る(取りやめと決めつけない)。後から届けば受け取る', () {
      fakeAsync((async) {
        PurchaseOutcome? got;
        s.buyRemoveAds().then((r) => got = r);
        async.flushMicrotasks();
        async.elapse(const Duration(minutes: 5, seconds: 1));
        expect(got, PurchaseOutcome.pending);
        kit.send([tx(ads, PurchaseStatus.purchased)]);
        async.flushMicrotasks();
        expect(delivered, [ads]);
      });
    });

    test('通知の流れが壊れたら、待っている購入は「失敗」で戻る(固まらない)', () async {
      final r = s.buyRemoveAds();
      await settle();
      kit.fail(StateError('stream broke'));
      expect(await r, PurchaseOutcome.failed);
    });

    test('価格はストアの表示のまま出す。取れなければ null', () async {
      expect(await s.priceLabel(), '¥370');
      kit.known = {};
      expect(await StorePurchaseService().priceLabel(), isNull);
    });
  });

  group('返金・取り消し', () {
    test('返金済みの取引は「買えた」と扱わず、広告を戻して取引を片付ける', () async {
      final r = s.buyRemoveAds();
      await settle();
      kit.send([tx(ads, PurchaseStatus.purchased, revoked: true)]);
      await settle();
      expect(delivered, isEmpty);
      expect(revoked, [ads]);
      expect(kit.completed, hasLength(1));
      var done = false;
      unawaited(r.then((_) => done = true));
      await settle();
      expect(done, isFalse);
    });

    test('広告を戻せなかったら完了を返さない(次の起動でもう一度届く)', () async {
      s.onRevoked = (id) async => throw StateError('保存できなかった');
      kit.send([tx(ads, PurchaseStatus.restored, revoked: true)]);
      await settle();
      expect(kit.completed, isEmpty);
    });

    test('取引の中身が読めなければ返金とは見なさない(払った人から広告なしを取らない)', () {
      expect(StorePurchaseService.isRevoked(tx(ads, PurchaseStatus.purchased)), isFalse);
      final broken = PurchaseDetails(
        productID: ads,
        verificationData:
            PurchaseVerificationData(localVerificationData: '壊れた', serverVerificationData: '', source: ''),
        transactionDate: '0',
        status: PurchaseStatus.purchased,
      );
      expect(StorePurchaseService.isRevoked(broken), isFalse);
      expect(StorePurchaseService.isRevoked(tx(ads, PurchaseStatus.purchased, revoked: true)), isTrue);
    });
  });

  group('復元', () {
    test('戻すものが無ければ5秒で「見つからない」。何も渡さない', () {
      fakeAsync((async) {
        PurchaseOutcome? got;
        s.restore().then((r) => got = r);
        async.elapse(const Duration(seconds: 4));
        expect(got, isNull); // 審査の担当が買った直後でも見落とさないよう、すぐには諦めない
        async.elapse(const Duration(seconds: 2));
        expect(got, PurchaseOutcome.unavailable);
        expect(delivered, isEmpty);
      });
    });

    test('2度押ししても、復元を頼むのは1回', () async {
      kit.onRestore = () => [tx(ads, PurchaseStatus.restored)];
      final a = s.restore();
      final b = s.restore();
      expect(await a, PurchaseOutcome.purchased);
      expect(await b, PurchaseOutcome.purchased);
      expect(kit.restoreCalls, 1);
    });

    test('復元の「見つからない」が、待っている購入の結果にならない', () async {
      PurchaseOutcome? bought;
      unawaited(s.buyRemoveAds().then((r) => bought = r));
      await settle();
      expect(await s.restore(), PurchaseOutcome.unavailable); // 実時間で5秒待つ
      expect(bought, isNull);
      kit.send([tx(ads, PurchaseStatus.purchased)]);
      await settle();
      expect(bought, PurchaseOutcome.purchased);
    });
  });
}

/// StoreKit の例外の代わり(文字列に userCancelled を含む)。
class _PlatformExceptionLike implements Exception {
  _PlatformExceptionLike(this.message);
  final String message;
  @override
  String toString() => message;
}
