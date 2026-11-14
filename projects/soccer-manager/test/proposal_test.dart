import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/logic/proposal_engine.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Tr.language = AppLanguage.japanese;
  });
  tearDown(() => Tr.language = AppLanguage.system);

  test('契約が残り1年以下の主力に、契約更新の提案が出る', () async {
    final gs = GameState();
    await gs.startNewGame('テストFC');
    final best = gs.userTeam.players
        .reduce((a, b) => a.overall >= b.overall ? a : b);
    best.contractYearsRemaining = 1;
    gs.debugRefreshProposals();
    expect(
        gs.save!.proposals
            .any((p) => p.kind == ProposalKind.renew && p.playerId == best.id),
        isTrue);
  });

  test('提案は上限までで、却下した提案は出し直されない', () async {
    final gs = GameState();
    await gs.startNewGame('テストFC');
    for (final p in gs.userTeam.players) {
      p.contractYearsRemaining = 1;
    }
    gs.debugRefreshProposals();
    expect(gs.save!.proposals.length, lessThanOrEqualTo(ProposalEngine.maxPending));
    final first = gs.save!.proposals.first;
    await gs.declineProposal(first.id);
    gs.debugRefreshProposals();
    expect(gs.save!.proposals.any((p) => p.id == first.id), isFalse);
  });

  test('承認すると契約が更新され、提案が消える', () async {
    final gs = GameState();
    await gs.startNewGame('テストFC');
    gs.save!.budget = 1000000;
    final best = gs.userTeam.players
        .reduce((a, b) => a.overall >= b.overall ? a : b);
    best.contractYearsRemaining = 1;
    gs.debugRefreshProposals();
    final prop = gs.save!.proposals
        .firstWhere((p) => p.kind == ProposalKind.renew && p.playerId == best.id);
    expect(await gs.approveProposal(prop.id), isTrue);
    expect(best.contractYearsRemaining, greaterThan(1));
    expect(gs.save!.proposals.any((p) => p.id == prop.id), isFalse);
  });

  test('保存して読み戻せ、無い旧セーブは空', () async {
    final gs = GameState();
    await gs.startNewGame('テストFC');
    gs.save!.proposals.add(const ManagerProposal(
        kind: ProposalKind.promote, playerId: 'p', playerName: 'X'));
    gs.save!.declinedProposalIds.add('renew:q');
    final json = gs.save!.toJson();
    final back = SaveGame.fromJson(json);
    expect(back.proposals.single.playerName, 'X');
    expect(back.declinedProposalIds, ['renew:q']);
    json
      ..remove('proposals')
      ..remove('declinedProposalIds');
    final old = SaveGame.fromJson(json);
    expect(old.proposals, isEmpty);
    expect(old.declinedProposalIds, isEmpty);
  });
}
