import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/models/incoming_offer.dart';
import 'package:soccer_manager/state/game_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('自クラブの選手を売っても国籍は変わらない', () async {
    final gs = GameState();
    await gs.startNewGame('国籍FC');
    final s = gs.save!..budget = 99999999;
    final buyer = s.league.teams.firstWhere((t) => t.id != s.userTeamId);
    var checked = 0;
    for (final p in [...gs.userTeam.players.where((p) => !p.isLoan)].take(6)) {
      final before = gs.nationalityOf(p);
      s.incomingOffers.add(IncomingOffer(
          id: 'n${p.id}',
          playerId: p.id,
          playerName: p.name,
          buyerClubName: buyer.name,
          amount: 100));
      if (!await gs.acceptIncomingOffer('n${p.id}')) continue;
      expect(gs.nationalityOf(p), before, reason: p.id);
      checked++;
    }
    expect(checked, greaterThan(0));
  });
}
