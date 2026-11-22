import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/logic/transfer_terms_engine.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';
import 'support/legacy_market.dart';

import 'support/sell_via_offer.dart';

/// 移籍の現実的な条件: 代理人手数料と売却条項。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('TransferTermsEngine', () {
    // 実際の代理人手数料は1割前後なので、5%から10%に上げた(2026-11-22)。
    test('代理人手数料は移籍金の10%で、0以下なら0', () {
      expect(TransferTermsEngine.agentFee(1000), 100);
      expect(TransferTermsEngine.agentFee(0), 0);
      expect(TransferTermsEngine.agentFee(-10), 0);
    });

    test('満額に近ければ条項なし、大きく値切るほど重くなる', () {
      int p(int offer) =>
          TransferTermsEngine.sellOnPercent(offer: offer, marketValue: 1000);
      expect(p(1000), 0);
      expect(p(950), 0);
      expect(p(900), 5);
      expect(p(800), 5);
      expect(p(700), 10);
      expect(TransferTermsEngine.sellOnPercent(offer: 10, marketValue: 0), 0);
    });

    test('売却条項の支払いは売却額に対する割合', () {
      expect(
          TransferTermsEngine.sellOnPayment(salePrice: 2000, percent: 10), 200);
      expect(TransferTermsEngine.sellOnPayment(salePrice: 2000, percent: 0), 0);
      expect(TransferTermsEngine.sellOnPayment(salePrice: 0, percent: 10), 0);
    });
  });

  group('買うとき', () {
    test('一括で買うと、移籍金のほかに代理人手数料が引かれる', () async {
      final game = GameState();
      await game.startNewGame('手数料FC');
      final target = legacyMarket(game).first;
      final fee = TransferTermsEngine.agentFee(target.marketValue);
      game.save!.budget = target.marketValue + fee + 7;
      game.save!.wageBudget = 999999;

      expect(await game.buyPlayer(target.id), isTrue);
      expect(game.save!.budget, 7);
    });

    test('手数料を含めて足りなければ買えない', () async {
      final game = GameState();
      await game.startNewGame('手数料FC');
      final target = legacyMarket(game).first;
      game.save!.budget = target.marketValue; // 手数料の分が足りない
      game.save!.wageBudget = 999999;

      expect(await game.buyPlayer(target.id), isFalse);
      expect(game.save!.budget, target.marketValue);
    });

    test('分割払いでも、頭金のほかに代理人手数料が引かれる', () async {
      final game = GameState();
      await game.startNewGame('手数料FC');
      final target = legacyMarket(game).first;
      final down = (target.marketValue * 0.3).round();
      final fee = TransferTermsEngine.agentFee(target.marketValue);
      game.save!.budget = 100000;
      game.save!.wageBudget = 999999;

      expect(await game.buyPlayerOnInstallments(target.id), isTrue);
      expect(game.save!.budget, 100000 - down - fee);
    });

    test('値切って買うと売却条項が付き、満額なら付かない', () async {
      final game = GameState();
      await game.startNewGame('条項FC');
      game.save!.budget = 1000000;
      game.save!.wageBudget = 999999;
      final market = legacyMarket(game);
      final full = market[0];
      final cheap = market[1];

      // 満額は必ず成立し、条項は付かない。相場は契約の残り年数で市場価値の
      // 1.1倍まで上がる(TransferValue)ので、それを超える額で出す。
      final r1 =
          await game.makeTransferOffer(full.id, (full.marketValue * 1.2).round());
      expect(r1.accepted, isTrue);
      expect(game.save!.sellOnClauses.containsKey(full.id), isFalse);

      // 値切りは乱数なので、成立するまで同じ額で試す(週をまたがずに
      // 試せるよう、拒否の記録は消す)。
      var accepted = false;
      final offer = (cheap.marketValue * 0.9).round();
      for (var i = 0; i < 200 && !accepted; i++) {
        game.transferOffersRejectedThisWeek.clear();
        accepted = (await game.makeTransferOffer(cheap.id, offer)).accepted;
      }
      expect(accepted, isTrue);
      expect(game.save!.sellOnClauses[cheap.id], 5);
    });
  });

  group('売るとき', () {
    test('売却条項が付いた選手を売ると、売却額の割合を元のクラブへ払う', () async {
      final game = GameState();
      await game.startNewGame('条項FC');
      game.save!.budget = 100000;
      final player = game.userTeam.players.firstWhere((p) => !p.isLoan);
      game.save!.sellOnClauses[player.id] = 10;
      final before = game.save!.budget;

      final o = await sellViaOffer(game, player.id);
      expect(o, isNotNull);
      final net = o!.amount;
      final pay = TransferTermsEngine.sellOnPayment(salePrice: net, percent: 10);
      // 他の国のクラブへ売ったときだけ、連帯貢献金も引かれる。
      final solidarity = game.solidarityFor(player, net);
      expect(
          game.save!.budget,
          anyOf(equals(before + net - pay),
              equals(before + net - pay - solidarity)));
      expect(game.save!.sellOnClauses.containsKey(player.id), isFalse,
          reason: '払ったら条項は消える');
    });

    test('条項が無い選手を売っても、余計な支払いは無い', () async {
      final game = GameState();
      await game.startNewGame('条項FC');
      game.save!.budget = 100000;
      final player = game.userTeam.players.firstWhere((p) => !p.isLoan);
      final before = game.save!.budget;

      final o = await sellViaOffer(game, player.id);
      expect(o, isNotNull);
      final net = o!.amount;
      final solidarity = game.solidarityFor(player, net);
      expect(game.save!.budget,
          anyOf(equals(before + net), equals(before + net - solidarity)));
    });
  });

  test('売却条項は保存して読み戻せ、無い旧セーブは空', () async {
    final game = GameState();
    await game.startNewGame('条項FC');
    game.save!.sellOnClauses['p1'] = 5;

    final restored = SaveGame.fromJson(game.save!.toJson());
    expect(restored.sellOnClauses['p1'], 5);

    final old =
        SaveGame.fromJson(game.save!.toJson()..remove('sellOnClauses'));
    expect(old.sellOnClauses, isEmpty);
  });
}
