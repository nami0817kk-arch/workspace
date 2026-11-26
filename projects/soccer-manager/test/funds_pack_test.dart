import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/monetization/funds_pack.dart';
import 'package:soccer_manager/monetization/purchase_service.dart';
import 'package:soccer_manager/monetization/reward_offer.dart';
import 'package:soccer_manager/state/game_state.dart';

void main() {
  setUp(() {
    Tr.language = AppLanguage.japanese;
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

    test('もう売らない。買う口は課金の管理から外してある', () {
      // 2026-11-26 に方針として確定。受け取りの口(_grant)だけ残す。
      final controller = File('lib/monetization/monetization_controller.dart')
          .readAsStringSync();
      expect(controller, isNot(contains('buyFundsPack')));
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

    test('資金の購入は画面から外れ、設定画面の説明は「広告を消す」だけになっている', () {
      // 1.2.0 のオーナー型では、買えば赤字を消せる商品は置かない。
      // 説明と画面のどちらかだけが残ると、書いてあることと違う形になる。
      final section =
          File('lib/widgets/supporter_section.dart').readAsStringSync();
      expect(section, contains('広告を消す（買い切り）'));
      expect(section, isNot(contains('資金パック')));
      expect(section, isNot(contains('有利になる商品です')));
      final finance =
          File('lib/screens/finance_screen.dart').readAsStringSync();
      expect(finance, isNot(contains('FundsPackCard')));
      // 買う画面の部品そのものも消した(2026-11-23)。どこからも使われず、
      // 残すと誰かが置き直す余地になる。
      expect(File('lib/widgets/funds_pack_card.dart').existsSync(), isFalse);
    });
  });
}
