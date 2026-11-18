import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/logic/signing_proposal_engine.dart';
import 'package:soccer_manager/state/game_state.dart';
import 'support/legacy_market.dart';

/// 補強は、監督が挙げた候補をオーナーが買う/見送るで決める形。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<GameState> newGame() async {
    final game = GameState();
    await game.startNewGame('提案FC');
    return game;
  }

  test('候補は最大3人で、市場にいる選手だけ', () async {
    final game = await newGame();
    final market = legacyMarket(game);
    final proposals = SigningProposalEngine.propose(
      game.userTeam,
      market,
      budget: 1000000,
    );
    expect(proposals.length, lessThanOrEqualTo(SigningProposalEngine.count));
    final ids = market.map((p) => p.id).toSet();
    for (final pr in proposals) {
      expect(ids, contains(pr.player.id));
      expect(pr.reason, isNotEmpty);
    }
  });

  test('見送った選手は、次の候補に出ない', () async {
    final game = await newGame();
    final market = legacyMarket(game);
    final first = SigningProposalEngine.propose(
      game.userTeam,
      market,
      budget: 1000000,
    );
    expect(first, isNotEmpty);
    final passed = {first.first.player.id};
    final next = SigningProposalEngine.propose(
      game.userTeam,
      market,
      budget: 1000000,
      passed: passed,
    );
    expect(next.any((pr) => passed.contains(pr.player.id)), isFalse);
  });

  test('資金を大きく超える選手は挙げない', () async {
    final game = await newGame();
    final proposals = SigningProposalEngine.propose(
      game.userTeam,
      legacyMarket(game),
      budget: 0,
    );
    for (final pr in proposals) {
      expect(pr.player.marketValue, lessThanOrEqualTo(0));
    }
  });

  test('市場が空なら候補は無い', () async {
    final game = await newGame();
    expect(
      SigningProposalEngine.propose(game.userTeam, [], budget: 1000000),
      isEmpty,
    );
  });
}
