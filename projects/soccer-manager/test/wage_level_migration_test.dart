import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/logic/contract_engine.dart';
import 'package:soccer_manager/logic/economy_scale.dart';
import 'package:soccer_manager/logic/free_agent_engine.dart';
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
    expect(home, 0.5);
    // 版3で、週俸は「今の能力×年齢の経験×国・部の係数」で作り直す。
    final lUser = loaded.userTeam;
    final lUserPlayer = lUser.players.firstWhere((p) => p.id == userPlayer.id);
    expect(lUserPlayer.wage, lUserPlayer.fairWeeklyWage(home));
    final lTier1 = ls.otherDivisionLeagues[0]!.teams.firstWhere(
      (t) => t.id == tier1.id,
    );
    final lTier1Player =
        lTier1.players.firstWhere((p) => p.id == tier1Player.id);
    expect(
      lTier1Player.wage,
      lTier1Player.fairWeeklyWage(wageCountryFactor(LeagueTheme.france, 1)),
    );
    final lSpain = ls.foreignLeagues[LeagueTheme.spain.name]!.teams.firstWhere(
      (t) => t.id == spain.id,
    );
    final lSpainPlayer =
        lSpain.players.firstWhere((p) => p.id == spainPlayer.id);
    expect(
      lSpainPlayer.wage,
      lSpainPlayer.fairWeeklyWage(wageCountryFactor(LeagueTheme.spain, 1)),
    );
    if (freeAgentId != null) {
      final fa = ls.freeAgents.where((p) => p.id == freeAgentId).firstOrNull;
      // 所属なしの選手は、移行のあとで求める額(評判・時期を掛けたもの)に
      // そろえ直す(第4段 #1412)。能力だけの額のままにはならない。
      if (fa != null) {
        expect(fa.wage, FreeAgentEngine.askingWeekly(fa, ls.today!));
      }
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
      lUserPlayer.wage,
    );
    expect(
      s2.foreignLeagues[LeagueTheme.spain.name]!.teams
          .firstWhere((t) => t.id == spain.id)
          .players
          .firstWhere((p) => p.id == spainPlayer.id)
          .wage,
      lSpainPlayer.wage,
    );
    expect(s2.wageBudget, ls.wageBudget);
    expect(s2.budget, budget);
  });

  test('版2のセーブは、週俸を今の能力×年齢の式で作り直し、給与の枠の余裕は保つ', () async {
    final game = GameState();
    await game.startNewGame('中FC', theme: LeagueTheme.england);
    final s = game.save!;
    final user = game.userTeam;
    // 版2の頃の式では、ベテランは安く若手は高かった。
    for (final p in user.players) {
      p.wage = p.age >= 30 ? 50 : 900;
    }
    s.wageBudget = ContractEngine.weeklyWageBill(user) + 300;
    final json = jsonDecode(game.exportSaveJson()!) as Map<String, dynamic>;
    json['wageLevelVersion'] = 2;

    final loaded = GameState();
    expect(await loaded.importSaveJson(jsonEncode(json)), isTrue);
    final ls = loaded.save!;
    expect(ls.wageLevelVersion, SaveGame.currentWageLevelVersion);
    final home = wageCountryFactor(LeagueTheme.england, ls.currentDivisionTier);
    for (final p in loaded.userTeam.players) {
      if (p.isLoanedOut || p.loanBaseWage != null) continue;
      expect(p.wage, p.fairWeeklyWage(home), reason: p.id);
    }
    expect(
      ls.wageBudget - ContractEngine.weeklyWageBill(loaded.userTeam),
      300,
    );
  });

  // 2026-11-23: 国・部の水準を、部が下がるほど同じか低い形に直した(版4)。
  // 版3のセーブ(フランスの3部は水準0.6)は、新しい水準(0.5)で作り直す。
  test('版3のセーブは、週俸を新しい国・部の水準で一度だけ作り直す', () async {
    final game = GameState();
    await game.startNewGame('仏FC', theme: LeagueTheme.france);
    final s = game.save!;
    final user = game.userTeam;
    // 版3の頃のフランスの3部の水準(0.6)で作られていた週俸。
    for (final p in user.players) {
      if (p.isLoanedOut || p.loanBaseWage != null) continue;
      p.wage = p.fairWeeklyWage(0.6);
    }
    final tier2 = s.otherDivisionLeagues[1]!.teams.first;
    for (final p in tier2.players) {
      if (p.isLoanedOut || p.loanBaseWage != null) continue;
      p.wage = p.fairWeeklyWage(0.55);
    }
    s.wageBudget = ContractEngine.weeklyWageBill(user) + 300;
    final budget = s.budget;
    final json = jsonDecode(game.exportSaveJson()!) as Map<String, dynamic>;
    json['wageLevelVersion'] = 3;

    final loaded = GameState();
    expect(await loaded.importSaveJson(jsonEncode(json)), isTrue);
    final ls = loaded.save!;
    expect(ls.wageLevelVersion, 4);
    final home = wageCountryFactor(LeagueTheme.france, ls.currentDivisionTier);
    for (final p in loaded.userTeam.players) {
      if (p.isLoanedOut || p.loanBaseWage != null) continue;
      expect(p.wage, p.fairWeeklyWage(home), reason: p.id);
    }
    final lTier2 =
        ls.otherDivisionLeagues[1]!.teams.firstWhere((t) => t.id == tier2.id);
    for (final p in lTier2.players) {
      if (p.isLoanedOut || p.loanBaseWage != null) continue;
      expect(p.wage,
          p.fairWeeklyWage(wageCountryFactor(LeagueTheme.france, 2)),
          reason: p.id);
    }
    // 資金はそのまま、給与の枠の余裕は保つ。
    expect(ls.budget, budget);
    expect(
      ls.wageBudget - ContractEngine.weeklyWageBill(loaded.userTeam),
      300,
    );

    // もう一度読み込んでも、作り直さない(交渉で決めた額が残る)。
    final p0 = loaded.userTeam.players
        .firstWhere((p) => !p.isLoanedOut && p.loanBaseWage == null);
    p0.wage += 7;
    final again = GameState();
    expect(await again.importSaveJson(loaded.exportSaveJson()!), isTrue);
    expect(
      again.userTeam.players.firstWhere((p) => p.id == p0.id).wage,
      p0.wage,
    );
  });

  test('今の版のセーブ(新しいゲーム)は、読み込んでも週俸が変わらない', () async {
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
