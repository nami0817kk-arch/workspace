import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/logic/contract_engine.dart';
import 'package:soccer_manager/logic/economy_scale.dart';
import 'package:soccer_manager/models/contract_negotiation.dart';
import 'package:soccer_manager/models/league_theme.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 年俸に国・部の水準を掛ける前(wageLevelVersion なし = 版1)のセーブを
/// 読み込んだときの換算(2026-11-22)。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('版1のセーブは、読み込みで一度だけ選手のいるクラブの国・部の係数を掛ける', () async {
    final game = GameState();
    await game.startNewGame('旧FC', theme: LeagueTheme.france);
    final s = game.save!;
    const old = 1000;
    // 版1の頃は、どこも係数1で作られていた。全員を同じ週俸にそろえる。
    for (final t in [
      ...s.allTeams,
      for (final l in s.foreignLeagues.values) ...l.teams,
    ]) {
      for (final p in t.players) {
        p.wage = old;
      }
    }
    for (final p in s.freeAgents) {
      p.wage = old;
    }
    final user = game.userTeam;
    final userPlayer = user.players.first;
    s.pendingContractNegotiation = ContractNegotiation(
      playerId: userPlayer.id,
      initialWage: old,
      offeredWage: old,
      counterWage: 1200,
    );
    final bill = ContractEngine.weeklyWageBill(user);
    s.wageBudget = bill + 500;
    final budget = s.budget;
    final tier1 = s.otherDivisionLeagues[0]!.teams.first;
    final tier1Player = tier1.players.first;
    final spain = s.foreignLeagues[LeagueTheme.spain.name]!.teams.first;
    final spainPlayer = spain.players.first;
    final freeAgentId = s.freeAgents.isEmpty ? null : s.freeAgents.first.id;

    final json = jsonDecode(game.exportSaveJson()!) as Map<String, dynamic>;
    json.remove('wageLevelVersion');
    expect(SaveGame.fromJson(json).wageLevelVersion, 1);

    final loaded = GameState();
    expect(await loaded.importSaveJson(jsonEncode(json)), isTrue);
    final ls = loaded.save!;
    expect(ls.wageLevelVersion, SaveGame.currentWageLevelVersion);

    // 自クラブはフランスの3部、1部のクラブはフランスの1部、他国はその国の1部。
    final home = wageCountryFactor(LeagueTheme.france, ls.currentDivisionTier);
    expect(home, 0.6);
    final lUser = loaded.userTeam;
    expect(
      lUser.players.firstWhere((p) => p.id == userPlayer.id).wage,
      (old * home).round(),
    );
    final lTier1 = ls.otherDivisionLeagues[0]!.teams.firstWhere(
      (t) => t.id == tier1.id,
    );
    expect(
      lTier1.players.firstWhere((p) => p.id == tier1Player.id).wage,
      (old * wageCountryFactor(LeagueTheme.france, 1)).round(),
    );
    final lSpain = ls.foreignLeagues[LeagueTheme.spain.name]!.teams.firstWhere(
      (t) => t.id == spain.id,
    );
    expect(
      lSpain.players.firstWhere((p) => p.id == spainPlayer.id).wage,
      (old * wageCountryFactor(LeagueTheme.spain, 1)).round(),
    );
    if (freeAgentId != null) {
      final fa = ls.freeAgents.where((p) => p.id == freeAgentId).firstOrNull;
      if (fa != null) expect(fa.wage, (old * home).round());
    }

    // 交渉中の週俸も自クラブの係数でそろえる。
    final n = ls.pendingContractNegotiation!;
    expect(n.initialWage, (old * home).round());
    expect(n.counterWage, (1200 * home).round());

    // 資金はそのまま。給与の枠は余裕(枠 − 人件費)を保つ。
    expect(ls.budget, budget);
    expect(ls.wageBudget - ContractEngine.weeklyWageBill(lUser), 500);
    expect(ls.wageBudget, greaterThan(0));

    // もう一度保存して読み込んでも、二重には掛からない。
    final again = GameState();
    expect(await again.importSaveJson(loaded.exportSaveJson()!), isTrue);
    final s2 = again.save!;
    expect(s2.wageLevelVersion, SaveGame.currentWageLevelVersion);
    expect(
      again.userTeam.players.firstWhere((p) => p.id == userPlayer.id).wage,
      (old * home).round(),
    );
    expect(
      s2.foreignLeagues[LeagueTheme.spain.name]!.teams
          .firstWhere((t) => t.id == spain.id)
          .players
          .firstWhere((p) => p.id == spainPlayer.id)
          .wage,
      (old * wageCountryFactor(LeagueTheme.spain, 1)).round(),
    );
    expect(s2.wageBudget, ls.wageBudget);
    expect(s2.budget, budget);
  });

  test('版2のセーブ(新しいゲーム)は、読み込んでも週俸が変わらない', () async {
    final game = GameState();
    await game.startNewGame('新FC', theme: LeagueTheme.italy);
    final wages = {for (final p in game.userTeam.players) p.id: p.wage};
    final loaded = GameState();
    expect(await loaded.importSaveJson(game.exportSaveJson()!), isTrue);
    for (final p in loaded.userTeam.players) {
      expect(p.wage, wages[p.id], reason: p.id);
    }
  });
}
