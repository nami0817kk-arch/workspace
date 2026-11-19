import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('自クラブより弱いクラブと提携でき、その選手は2割引になる', () async {
    final gs = GameState();
    await gs.startNewGame('系列FC');
    final s = gs.save!..budget = 99999999;
    final candidates = gs.affiliateCandidates();
    expect(candidates, isNotEmpty);
    for (final t in candidates) {
      expect(t.overallRating, lessThan(gs.userTeam.overallRating));
      expect(t.id, isNot(s.rivalTeamId));
    }
    final club = candidates.first;
    final p = club.players.first;
    final before = gs.askingPriceFor(p);
    final money = s.budget;
    expect(await gs.setAffiliateClub(club.id), isTrue);
    expect(s.budget, lessThan(money), reason: '最初の年会費');
    expect(gs.affiliateClub!.id, club.id);
    expect(gs.askingPriceFor(p), (before * 0.8).round());

    expect(SaveGame.fromJson(s.toJson()).affiliateClubId, club.id);
    expect(await gs.endAffiliate(), isTrue);
    expect(gs.affiliateClub, isNull);
  });

  test('自クラブより強いクラブとは提携できない', () async {
    final gs = GameState();
    await gs.startNewGame('格上FC');
    gs.save!.budget = 99999999;
    final stronger = gs.save!.foreignLeagues.values
        .expand((l) => l.teams)
        .firstWhere((t) => t.overallRating > gs.userTeam.overallRating);
    expect(await gs.setAffiliateClub(stronger.id), isFalse);
  });
}
