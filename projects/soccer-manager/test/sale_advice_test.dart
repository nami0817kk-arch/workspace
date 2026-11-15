import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/logic/next_action_advisor.dart';
import 'package:soccer_manager/logic/sale_advice_engine.dart';
import 'package:soccer_manager/models/incoming_offer.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 売却のオファーは、監督の見立てを見て承認か断るかを決める形。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  IncomingOffer offerFor(String playerId, int amount) => IncomingOffer(
        id: 'o1',
        playerId: playerId,
        playerName: '選手',
        buyerClubName: '買い手FC',
        amount: amount,
      );

  test('市場価値を大きく上回る額は、売り時と見立てる', () async {
    final game = GameState();
    await game.startNewGame('売却FC');
    final p = game.userTeam.players.first;
    final advice = SaleAdviceEngine.advise(
        offerFor(p.id, (p.marketValue * 1.5).ceil() + 1), p, game.userTeam);
    expect(advice.verdict, SaleVerdict.sell);
    expect(advice.comment, isNotEmpty);
  });

  test('先発級に市場価値未満の額なら、断るべきと見立てる', () async {
    final game = GameState();
    await game.startNewGame('売却FC');
    final best = [...game.userTeam.players]
      ..sort((a, b) => b.overall.compareTo(a.overall));
    final p = best.first;
    final advice = SaleAdviceEngine.advise(
        offerFor(p.id, (p.marketValue * 0.5).floor()), p, game.userTeam);
    expect(advice.verdict, SaleVerdict.keep);
  });

  test('選手が見つからなければ、中立の見立て', () async {
    final game = GameState();
    await game.startNewGame('売却FC');
    final advice =
        SaleAdviceEngine.advise(offerFor('none', 100), null, game.userTeam);
    expect(advice.verdict, SaleVerdict.either);
  });

  test('オファーが届いていると、今週の決断に出る', () async {
    final game = GameState();
    await game.startNewGame('売却FC');
    game.save!.budget = 5000;
    game.save!.incomingOffers = [offerFor(game.userTeam.players.first.id, 100)];
    final actions = NextActionAdvisor.all(game.save!, game.userTeam)
        .where((a) => a.message.contains('オファー') || a.message.contains('offer'));
    expect(actions, isNotEmpty);
  });
}
