import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/models/incoming_offer.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 移籍の形(買取義務付きローン・買い戻し条項)の検査。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('買取義務付きローンは、満了すると完全移籍に切り替わって残る', () async {
    final gs = GameState();
    await gs.startNewGame('形FC');
    final s = gs.save!..budget = 99999999;
    s.wageBudget = 99999999;
    Player? p;
    for (final c in gs.transferTargets) {
      if (await gs.signLoanPlayer(c.id, withObligation: true)) {
        p = c;
        break;
      }
    }
    expect(p, isNotNull, reason: '借りられる選手がいない');
    expect(p!.loanObligation, isTrue);
    expect(p.loanBuyOptionFee, isNotNull);
    final fee = p.loanBuyOptionFee!;
    final before = s.budget;
    gs.debugAdvanceTodayTo(p.loanEndDate!.add(const Duration(days: 1)));
    gs.debugSettleLoansByDate();
    expect(gs.userTeam.players.contains(p), isTrue, reason: '満了しても残る');
    expect(p.isLoan, isFalse);
    expect(before - s.budget, greaterThanOrEqualTo(fee));
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('買い戻し条項付きで売ると売値が1割下がり、1.5倍で買い戻せる', () async {
    final gs = GameState();
    await gs.startNewGame('形FC');
    final s = gs.save!..budget = 99999999;
    s.wageBudget = 99999999;
    final p = gs.userTeam.players.firstWhere((p) => !p.isLoan);
    final buyer = s.league.teams.firstWhere((t) => t.id != s.userTeamId);
    s.incomingOffers.add(IncomingOffer(
        id: 'bb',
        playerId: p.id,
        playerName: p.name,
        buyerClubName: buyer.name,
        amount: 1000));
    expect(await gs.acceptIncomingOfferWithBuyBack('bb'), isTrue);
    expect(gs.userTeam.players.contains(p), isFalse);
    expect(s.buyBacks[p.id]![0], 1350, reason: '900 × 1.5');
    expect(gs.buyBackCandidates.map((x) => x.id), contains(p.id));
    if (gs.isTransferWindowOpen) {
      expect(await gs.exerciseBuyBack(p.id), isTrue);
      expect(gs.userTeam.players.any((x) => x.id == p.id), isTrue);
      expect(s.buyBacks.containsKey(p.id), isFalse);
    }
  });

  test('保存して読み戻せる', () async {
    final gs = GameState();
    await gs.startNewGame('形FC');
    gs.save!.buyBacks['p1'] = [500, 2028];
    final p = gs.userTeam.players.first..loanObligation = true;
    expect(SaveGame.fromJson(gs.save!.toJson()).buyBacks['p1'], [500, 2028]);
    expect(Player.fromJson(p.toJson()).loanObligation, isTrue);
  });
}
