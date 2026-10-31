/// 「購入を復元」の結果。
///
/// StoreKit 2 は復元の対象が無いと**空のリストを1回流すだけ**なので、
/// 以前は 20秒待ってから「ストアに繋がりませんでした」と出していた。
/// 買っていない人が押すと、壊れているように見える。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_career/monetize/ad_service.dart';
import 'package:soccer_career/monetize/monetization.dart';
import 'package:soccer_career/monetize/purchase_service.dart';
import 'package:soccer_career/ui/screens/support_screen.dart';

/// ストアの差し替え。復元を押したときに何を流すかだけを決める。
class _FakeIap implements InAppPurchase {
  _FakeIap(this.onRestore);

  /// 復元の呼び出しの中身。ストリームに流すものと、呼び出しが返る時機を決める。
  final Future<void> Function(_FakeIap iap) onRestore;

  final StreamController<List<PurchaseDetails>> _stream =
      StreamController<List<PurchaseDetails>>.broadcast();
  final List<PurchaseDetails> completed = [];

  void emit(List<PurchaseDetails> purchases) => _stream.add(purchases);

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _stream.stream;

  @override
  Future<void> restorePurchases({String? applicationUserName}) =>
      onRestore(this);

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async =>
      completed.add(purchase);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PurchaseDetails _restored(String productId) => PurchaseDetails(
  purchaseID: 'tx-1',
  productID: productId,
  verificationData: PurchaseVerificationData(
    localVerificationData: '{}',
    serverVerificationData: '',
    source: 'app_store',
  ),
  transactionDate: '0',
  status: PurchaseStatus.restored,
);

const _grace = Duration(milliseconds: 50);
const _limit = Duration(seconds: 2);

Future<(StorePurchaseService, List<Product>)> _service(
  Future<void> Function(_FakeIap iap) onRestore, {
  Future<void> Function()? saving,
}) async {
  final delivered = <Product>[];
  final service = StorePurchaseService(
    iap: _FakeIap(onRestore),
    restoreGrace: _grace,
    restoreLimit: _limit,
  );
  await service.initialize(
    onDelivered: (p) async {
      await saving?.call();
      delivered.add(p);
    },
    onRevoked: (_) async {},
  );
  return (service, delivered);
}

class _NoAds implements AdService {
  @override
  Future<void> initialize() async {}
  @override
  bool get isInterstitialReady => false;
  @override
  Future<bool> showInterstitial() async => false;
  @override
  void dispose() {}
}

class _Store implements PurchaseService {
  _Store(this.outcome);
  final PurchaseOutcome outcome;

  @override
  Future<void> initialize({
    required Future<void> Function(Product product) onDelivered,
    required Future<void> Function(Product product) onRevoked,
  }) async {}
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<String?> priceOf(Product product) async => '￥400';
  @override
  Future<PurchaseOutcome> buy(Product product) async => outcome;
  @override
  Future<PurchaseOutcome> restore() async => outcome;
  @override
  void dispose() {}
}

void main() {
  group('購入を復元', () {
    test('対象が無ければ、空のリストが流れるだけでも「対象なし」をすぐ返す', () async {
      final (service, delivered) = await _service((iap) async {
        // StoreKit 2: 対象が無いと空のリストを1回流すだけ。
        iap.emit(const []);
      });
      final watch = Stopwatch()..start();
      final outcome = await service.restore();
      expect(outcome, PurchaseOutcome.nothingToRestore);
      expect(delivered, isEmpty);
      // 20秒の上限まで待たせない（短く待つだけ）。
      expect(watch.elapsed, lessThan(_limit));
    });

    test('何も流れてこなくても「対象なし」で、繋がらないとは言わない', () async {
      final (service, _) = await _service((iap) async {});
      expect(await service.restore(), PurchaseOutcome.nothingToRestore);
    });

    test('購入があれば受け取って「復元した」を返す', () async {
      final (service, delivered) = await _service((iap) async {
        iap.emit([_restored(Product.noAds.id)]);
      });
      expect(await service.restore(), PurchaseOutcome.purchased);
      expect(delivered, [Product.noAds]);
    });

    test('呼び出しが返った後に届いても、待つ時間のうちなら受け取る', () async {
      late _FakeIap fake;
      final (service, delivered) = await _service((iap) async {
        fake = iap;
      });
      final pending = service.restore();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      fake.emit([_restored(Product.noAds.id)]);
      expect(await pending, PurchaseOutcome.purchased);
      expect(delivered, [Product.noAds]);
    });

    test('受け取りの保存が待つ時間を越えても、「対象なし」とは言わない', () async {
      final (service, delivered) = await _service(
        (iap) async => iap.emit([_restored(Product.noAds.id)]),
        saving: () => Future<void>.delayed(_grace * 4),
      );
      expect(await service.restore(), PurchaseOutcome.purchased);
      expect(delivered, [Product.noAds]);
    });

    test('復元の呼び出しが返ってこなければ「繋がらない」', () async {
      final (service, _) = await _service(
        (iap) => Completer<void>().future, // 永久に返らない
      );
      expect(await service.restore(), PurchaseOutcome.unavailable);
    });

    test('復元の呼び出しが失敗したら「失敗」', () async {
      final (service, _) = await _service(
        (iap) async => throw Exception('store'),
      );
      expect(await service.restore(), PurchaseOutcome.failed);
    });

    testWidgets('対象が無いときは「復元できる購入はありませんでした」と出す', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final money = Monetization(
        ads: _NoAds(),
        purchases: _Store(PurchaseOutcome.nothingToRestore),
      );
      await tester.runAsync(money.initialize);
      await tester.pumpWidget(
        MaterialApp(home: SupportScreen(monetization: money)),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('購入を復元'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('購入を復元'));
      await tester.pumpAndSettle();
      expect(find.text('復元できる購入はありませんでした。'), findsOneWidget);
      expect(find.text('ストアに繋がりませんでした。'), findsNothing);
    });
  });
}
