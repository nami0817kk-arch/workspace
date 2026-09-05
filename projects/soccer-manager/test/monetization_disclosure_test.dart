import 'package:flutter_test/flutter_test.dart';

import 'package:soccer_manager/monetization/purchase_service.dart';
import 'package:soccer_manager/monetization/reward_offer.dart';

/// 課金要素の性質を固定する。
///
/// 「無料で最後まで遊べる」「買っても勝率は変わらない」は、ストア掲載文と
/// アプリ内の説明の両方で言っていること。実装がそこからずれると、
/// **書いてあることと違う**という一番まずい形になる。
void main() {
  group('広告は任意で、進行を妨げない', () {
    test('無料でも毎日受け取れる回数がある', () {
      expect(RewardOffer.dailyLimitFree, greaterThan(0),
          reason: '無料の受け取り回数が0だと、実質的に課金必須になる');
    });

    test('サポーターの回数は無料より多いが、桁違いではない', () {
      expect(RewardOffer.dailyLimitSupporter,
          greaterThan(RewardOffer.dailyLimitFree));
      expect(RewardOffer.dailyLimitSupporter,
          lessThanOrEqualTo(RewardOffer.dailyLimitFree * 2),
          reason: '差が大きすぎると「買わないと不利」に傾く');
    });
  });

  group('特典は資金だけで、強さには触らない', () {
    test('受け取れるのは資金であり、ディビジョンに応じて変わる', () {
      // 成長率や勝率に触る特典を作ると、無料と有料で強さが変わる。
      final byTier = {
        for (int t = 1; t <= 5; t++) t: RewardOffer.fundsFor(t),
      };
      for (final v in byTier.values) {
        expect(v, greaterThan(0));
      }
      expect(byTier[1], greaterThan(byTier[5]!),
          reason: '上のディビジョンほど額が大きくないと、下部リーグで効きすぎる');
    });

    test('1回の額が、そのディビジョンの経営を壊す規模ではない', () {
      // 5部の週次収入は数百万円の規模。1回で数千万円配ると経営が消える。
      expect(RewardOffer.fundsFor(5), lessThan(1000));
      expect(RewardOffer.fundsFor(1), lessThanOrEqualTo(2000));
    });
  });

  test('商品は買い切り1種類だけ', () {
    // 種類が増えると「何を買えばいいのか」が分からなくなる。
    expect(PurchaseService.supporterProductId, 'soccer_manager_supporter');
  });
}
