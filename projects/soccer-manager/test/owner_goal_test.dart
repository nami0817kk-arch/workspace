import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/models/owner_goal.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/models/season_record.dart';
import 'package:soccer_manager/state/game_state.dart';

SeasonRecord _record(int season,
        {int tier = 1,
        bool won = false,
        bool promoted = false,
        List<String> cups = const []}) =>
    SeasonRecord(
      season: season,
      clubName: 'テストFC',
      leagueName: 'L',
      divisionTier: tier,
      finalRank: won ? 1 : 5,
      teamCount: 20,
      played: 38,
      won: 10,
      draw: 10,
      lost: 18,
      goalsFor: 30,
      goalsAgainst: 40,
      wonLeague: won,
      promoted: promoted,
      cupsWon: cups,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('OwnerGoalRules', () {
    test('期限は目標ごとに決まっていて、数え始めのシーズンを含む', () {
      expect(
          OwnerGoalRules.isExpired(OwnerGoal.reachTopDivision,
              startSeason: 1, season: 4),
          isFalse);
      expect(
          OwnerGoalRules.isExpired(OwnerGoal.reachTopDivision,
              startSeason: 1, season: 5),
          isTrue);
    });

    test('資金の目標は、目標額に届いたときだけ満たす', () {
      bool met(int budget) => OwnerGoalRules.isMet(OwnerGoal.richClub,
          wonTopLeague: false,
          promotedOrTop: false,
          wonCup: false,
          budget: budget);
      expect(met(OwnerGoalRules.richTarget - 1), isFalse);
      expect(met(OwnerGoalRules.richTarget), isTrue);
    });
  });

  group('GameState', () {
    test('目標は決めるまで無く、決めると保存して読み戻せる', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      expect(gs.ownerGoal, isNull);
      await gs.setOwnerGoal(OwnerGoal.winCup);
      expect(gs.ownerGoal, OwnerGoal.winCup);
      expect(gs.ownerGoalSeasonsLeft, OwnerGoal.winCup.deadlineSeasons);

      final restored = SaveGame.fromJson(gs.save!.toJson());
      expect(restored.ownerGoal, OwnerGoal.winCup);
      final old = gs.save!.toJson()
        ..remove('ownerGoal')
        ..remove('achievedGoals');
      expect(SaveGame.fromJson(old).ownerGoal, isNull);
      expect(SaveGame.fromJson(old).achievedGoals, isEmpty);
    });

    test('1部にいるなら「1部へ昇格」は選べない', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      if (gs.currentDivisionTier <= 1) {
        expect(gs.selectableOwnerGoals,
            isNot(contains(OwnerGoal.reachTopDivision)));
      } else {
        expect(gs.selectableOwnerGoals, contains(OwnerGoal.reachTopDivision));
      }
    });

    test('達成すると殿堂に残り、目標は消えて期待が上がる', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      await gs.setOwnerGoal(OwnerGoal.winCup);
      final save = gs.save!;
      save.confidence = 50;
      save.shareholderExpectation = 50;
      save.seasonHistory.add(_record(save.league.season, cups: ['カップ']));

      gs.debugEvaluateOwnerGoal(season: save.league.season);

      expect(save.ownerGoal, isNull);
      expect(save.achievedGoals, hasLength(1));
      expect(save.confidence, 60);
      expect(save.shareholderExpectation, 60);
    });

    test('期限が来ても果たせなければ、罰なしで目標が消える', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      await gs.setOwnerGoal(OwnerGoal.winCup);
      final save = gs.save!;
      save.confidence = 50;
      save.seasonHistory.add(_record(save.league.season));

      gs.debugEvaluateOwnerGoal(
          season: save.ownerGoalStartSeason + OwnerGoal.winCup.deadlineSeasons - 1);

      expect(save.ownerGoal, isNull);
      expect(save.achievedGoals, isEmpty);
      expect(save.confidence, 50);
    });

    test('期限内で果たせていないあいだは、目標を追い続ける', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      await gs.setOwnerGoal(OwnerGoal.leagueTitle);
      final save = gs.save!;
      save.seasonHistory.add(_record(save.league.season));

      gs.debugEvaluateOwnerGoal(season: save.league.season);

      expect(save.ownerGoal, OwnerGoal.leagueTitle);
    });
  });
}
