import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/logic/league_rules.dart';
import 'package:soccer_manager/models/league_theme.dart';
import 'package:soccer_manager/state/game_state.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Tr.language = AppLanguage.japanese;
  });
  tearDown(() => Tr.language = AppLanguage.system);

  test('国の選択で開始すると、その国の規則が当たる', () async {
    final gs = GameState();
    await gs.startNewGame('テストFC', theme: LeagueTheme.spain);
    expect(gs.ruleSet, RuleSet.spain);
  });

  test('手放す状況でなければ、国またぎの買い直しはできない', () async {
    final gs = GameState();
    await gs.startNewGame('テストFC');
    expect(await gs.buyClubInCountry(LeagueTheme.germany), isFalse);
  });

  test('手放したあとに別の国で立ち上げると、その国の規則・リーグ・4部から始まる', () async {
    final gs = GameState();
    await gs.startNewGame('テストFC');
    final save = gs.save!;
    save.confidence = 0; // サポーターの期待が尽きた
    expect(gs.saleReason, isNotNull);
    final legacies = save.ownerLegacies.length;
    expect(await gs.buyClubInCountry(LeagueTheme.germany), isTrue);
    expect(gs.save!.leagueName, LeagueTheme.germany.label);
    expect(gs.ruleSet, RuleSet.germany);
    expect(gs.save!.currentDivisionTier, 4);
    expect(gs.save!.ownerLegacies.length, legacies + 1);
    expect(gs.save!.confidence, 60);
    expect(gs.save!.league.teams.length, 20);
    expect(gs.userTeam.id, 'user');
    expect(gs.save!.otherDivisionLeagues[3], isNull);
    expect(gs.save!.otherDivisionLeagues[0], isNotNull);
    expect(gs.currentLeagueTheme, LeagueTheme.germany);
    expect(gs.saleReason, isNull);
  });

  test('いまいる国には、国またぎの買い直しはできない', () async {
    final gs = GameState();
    await gs.startNewGame('テストFC');
    gs.save!.confidence = 0;
    expect(await gs.buyClubInCountry(gs.currentLeagueTheme), isFalse);
  });
}
