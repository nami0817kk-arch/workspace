import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/logic/contract_style.dart';
import 'package:soccer_manager/models/ledger.dart';
import 'package:soccer_manager/models/match_result.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/state/game_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('出来高: 週給1割減、得点ごとに払う', () async {
    final gs = GameState();
    await gs.startNewGame('出来高FC');
    final p = gs.userTeam.players.firstWhere((p) => !p.isLoan)
      ..wage = 100
      ..happiness = 60;
    expect(await gs.changeContractStyle(p.id, ContractStyle.goalBonus), isTrue);
    expect(p.wage, 90);
    expect(p.goalBonus, 50);
    expect(gs.contractStyleOf(p), ContractStyle.goalBonus);
    expect(gs.canChangeContractStyle(p), isFalse, reason: '組み替えは1度');

    final s = gs.save!;
    final before =
        s.ledgerFor(s.league.season).of(LedgerCategory.appearanceFees);
    gs.debugPayGoalBonuses(MatchResult(
      matchday: 1,
      homeTeamId: gs.userTeam.id,
      awayTeamId: 'x',
      homeGoals: 2,
      awayGoals: 0,
      events: [
        for (var i = 0; i < 2; i++)
          MatchEvent(
              minute: 10 + i,
              teamId: gs.userTeam.id,
              scorerId: p.id,
              scorerName: p.name),
      ],
    ));
    expect(
        s.ledgerFor(s.league.season).of(LedgerCategory.appearanceFees),
        before - 100);
    expect(Player.fromJson(p.toJson()).goalBonus, 50);
  });

  test('段階昇給: 週給8%減、季が変わるたびに5%上がる', () async {
    final gs = GameState();
    await gs.startNewGame('昇給FC');
    final p = gs.userTeam.players.firstWhere((p) => !p.isLoan)
      ..wage = 100
      ..happiness = 60;
    expect(await gs.changeContractStyle(p.id, ContractStyle.stepped), isTrue);
    expect(p.wage, 92);
    gs.debugApplySteppedRaises();
    expect(p.wage, 97);
    expect(Player.fromJson(p.toJson()).raisePct, 5);
  });
}
