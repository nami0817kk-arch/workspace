import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/monetization/ad_service.dart';
import 'package:soccer_manager/monetization/funds_pack.dart';
import 'package:soccer_manager/monetization/monetization_controller.dart';
import 'package:soccer_manager/monetization/purchase_service.dart';
import 'package:soccer_manager/monetization/reward_offer.dart';
import 'package:soccer_manager/state/game_state.dart';

class _FakePurchases implements PurchaseService {
  /// 受け取り口。本物は待っているかどうかに関係なく呼ぶ。
  @override
  set onDelivered(Future<void> Function(String productId)? callback) =>
      onDeliveredCallback = callback;

  Future<void> Function(String productId)? onDeliveredCallback;

  _FakePurchases({this.outcome = PurchaseOutcome.purchased});

  PurchaseOutcome outcome;
  final List<FundsPack> bought = [];
  int supporterBuys = 0;

  @override
  Future<void> initialize() async {}
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<String?> priceLabel() async => '¥480';
  @override
  Future<String?> priceLabelFor(FundsPack pack) async =>
      switch (pack) {
        FundsPack.small => '¥160',
        FundsPack.medium => '¥600',
        FundsPack.large => '¥1,600',
      };
  @override
  Future<PurchaseOutcome> buySupporter() async {
    supporterBuys++;
    return outcome;
  }

  @override
  Future<PurchaseOutcome> buyFundsPack(FundsPack pack) async {
    if (outcome == PurchaseOutcome.purchased) bought.add(pack);
    return outcome;
  }

  @override
  Future<PurchaseOutcome> restorePurchases() async => outcome;
  @override
  void dispose() {}
}

Future<MonetizationController> _build(_FakePurchases purchases) async {
  final controller = MonetizationController(
    adService: NoOpAdService(),
    purchases: purchases,
  );
  await controller.initialize();
  return controller;
}

void main() {
  setUp(() {
    Tr.language = AppLanguage.japanese;
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() => Tr.language = AppLanguage.system);

  group('資金パック', () {
    test('額はディビジョンに比例し、特典の決められた回数分になる', () {
      // 固定額にすると、5部では経営判断が消し飛び、1部では誤差になる。
      for (var tier = 1; tier <= 5; tier++) {
        for (final pack in FundsPack.values) {
          expect(pack.fundsFor(tier),
              RewardOffer.fundsFor(tier) * pack.rewardEquivalent);
        }
      }
    });

    test('大きいパックほど多く、下部リーグほど少ない', () {
      expect(FundsPack.small.fundsFor(1),
          lessThan(FundsPack.medium.fundsFor(1)));
      expect(FundsPack.medium.fundsFor(1),
          lessThan(FundsPack.large.fundsFor(1)));
      for (final pack in FundsPack.values) {
        expect(pack.fundsFor(5), lessThan(pack.fundsFor(1)));
      }
    });

    test('商品IDが重複しておらず、IDから引き直せる', () {
      // ストアからの通知は商品IDでしか届かない。重複していると
      // 別のパックの額を渡してしまう。
      expect(FundsPack.productIds.length, FundsPack.values.length);
      for (final pack in FundsPack.values) {
        expect(FundsPack.byProductId(pack.productId), pack);
      }
      expect(FundsPack.byProductId('unknown'), isNull);
      // サポーターと取り違えない。
      expect(FundsPack.byProductId(PurchaseService.supporterProductId), isNull);
    });

    test('扱う商品の一覧に、サポーターと資金パックが全部入っている', () {
      expect(PurchaseService.allProductIds,
          containsAll(<String>{PurchaseService.supporterProductId,
            ...FundsPack.productIds}));
      expect(PurchaseService.allProductIds.length,
          FundsPack.values.length + 1);
    });

    test('回数の制限がなく、何度でも買える', () async {
      // 上限を付けると広告の代わりに買うだけの商品になり、サポーターとの
      // 違いが消える。ここは意図して制限していない。
      final purchases = _FakePurchases();
      final money = await _build(purchases);
      for (var i = 0; i < 10; i++) {
        expect(await money.buyFundsPack(FundsPack.small),
            PurchaseOutcome.purchased);
      }
      expect(purchases.bought.length, 10);
      // 広告の特典の残り回数には影響しない。別の仕組み。
      expect(money.claimedToday, 0);
    });

    test('購入すると、その額だけ資金が増えてニュースに残る', () async {
      final gameState = GameState();
      await gameState.startNewGame('テストFC');
      final before = gameState.save!.budget;
      final newsBefore = gameState.save!.newsLog.length;

      final amount = gameState.claimPurchasedFunds(FundsPack.medium);

      expect(amount, gameState.purchasedFundsAmount(FundsPack.medium));
      expect(gameState.save!.budget, before + amount);
      // 資金が増えた理由が追えないと、収支が読めなくなる。
      expect(gameState.save!.newsLog.length, newsBefore + 1);
      expect(gameState.save!.newsLog.first.text, contains('資金'));
    });

    test('購入が成立しなければ、資金は動かない', () async {
      final purchases = _FakePurchases(outcome: PurchaseOutcome.canceled);
      final money = await _build(purchases);
      expect(await money.buyFundsPack(FundsPack.large),
          PurchaseOutcome.canceled);
      expect(purchases.bought, isEmpty);
    });
  });

  group('掲載情報との整合', () {
    test('商品IDが、実装と申請チェックリストで一致している', () {
      // チェックリストは「この文字列をストアに登録する」と指示している。
      // 実装だけ変えて文書が古いままだと、購入が動かない商品を登録する
      // ことになり、気付くのは審査の直前になる。
      final listing = File('STORE_LISTING.md').readAsStringSync();
      expect(listing, contains(PurchaseService.supporterProductId));
      for (final pack in FundsPack.values) {
        expect(listing, contains(pack.productId),
            reason: '${pack.productId} が STORE_LISTING.md に無い');
      }
    });

    test('「お金が関わるのは2つだけ」という説明が残っていない', () {
      // 資金を売るようになったので、この書き方は嘘になる。
      final section =
          File('lib/widgets/supporter_section.dart').readAsStringSync();
      expect(section, isNot(contains('お金が関わるのは次の2つだけ')));
      expect(section, isNot(contains('Only two things')));
      // 買えば有利になることを、設定画面で隠さない。
      expect(section, contains('有利になる商品です'));
    });
  });
}
