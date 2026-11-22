import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/logic/club_value_engine.dart';
import 'package:soccer_manager/models/club_infrastructure.dart';
import 'package:soccer_manager/models/owner_goal.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';

ClubValue _value({
  int players = 1000,
  Map<FacilityType, int> facilities = const {},
  List<int> staff = const [0, 0],
  int leagueTitles = 0,
  int cupTitles = 0,
  int reputation = 0,
  int income = 0,
  int cash = 0,
  int debt = 0,
}) =>
    ClubValueEngine.compute(
      playersValue: players,
      facilityLevels: facilities,
      staffLevels: staff,
      leagueTitles: leagueTitles,
      cupTitles: cupTitles,
      managerReputation: reputation,
      annualOperatingIncome: income,
      cash: cash,
      debt: debt,
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Tr.language = AppLanguage.japanese;
  });
  tearDown(() => Tr.language = AppLanguage.system);

  group('クラブ価値の計算', () {
    // 2026-11-23: 以前はレベル1を0円にしていて、1万2,000席のスタジアムの
    // クラブでも「施設・スタッフ」が0円だった。建て直す額で数える。
    test('レベル1の施設にも価値があり、スタジアムは席の数×1席の値段', () {
      expect(_value().facilities, 0);
      final stadium1 = _value(facilities: {FacilityType.stadium: 1});
      expect(
          stadium1.facilities,
          ClubInfrastructure.stadiumCapacity(1) *
              ClubInfrastructure.stadiumSeatCost(1));
      expect(stadium1.facilities, 240000); // 1万2,000席で24億
      expect(_value(facilities: {FacilityType.trainingGround: 1}).facilities,
          ClubInfrastructure.facilityUpgradeCost(1));
    });

    test('増築すると、増築の工事費と同じだけ価値が増える', () {
      for (final type in FacilityType.values) {
        for (var lv = 1; lv < ClubInfrastructure.maxLevel; lv++) {
          expect(
              ClubValueEngine.facilityValue(type, lv + 1) -
                  ClubValueEngine.facilityValue(type, lv),
              ClubInfrastructure.upgradeCostFor(type, lv),
              reason: '${type.name} Lv$lv');
        }
      }
      // 4万2,000席(Lv6)のスタジアムは204億。1席あたり、最初の増築の
      // 1席の値段(20万)以上、最後の増築の1席の値段(140万)以下。
      final lv6 = ClubValueEngine.facilityValue(FacilityType.stadium, 6);
      expect(ClubInfrastructure.stadiumCapacity(6), 42000);
      expect(lv6, 2040000);
      final perSeat = lv6 / ClubInfrastructure.stadiumCapacity(6);
      expect(perSeat, inInclusiveRange(ClubInfrastructure.stadiumSeatCost(1),
          ClubInfrastructure.stadiumSeatCost(7)));
    });

    test('施設の価値は部の規模で変わらない(工事費が部で変わらないので)', () {
      final levels = {for (final f in FacilityType.values) f: 3};
      ClubValue at(double scale) => ClubValueEngine.compute(
            playersValue: 0,
            facilityLevels: levels,
            staffLevels: const [],
            leagueTitles: 0,
            cupTitles: 0,
            managerReputation: 0,
            annualOperatingIncome: 0,
            cash: 0,
            debt: 0,
            scale: scale,
          );
      expect(at(14.44).facilities, at(208.5).facilities);
    });

    test('スタッフはいるだけで価値になり、空席は数えない', () {
      expect(_value(staff: [0, 0]).facilities, 0);
      expect(_value(staff: [3, 2]).facilities, 5 * ClubValueEngine.staffPerLevel);
    });

    test('優勝歴と評判がブランドになる', () {
      final v = _value(leagueTitles: 2, cupTitles: 1, reputation: 50);
      expect(
          v.brand,
          2 * ClubValueEngine.leagueTitleBrand +
              ClubValueEngine.cupTitleBrand +
              50 * ClubValueEngine.reputationPerPoint);
    });

    test('評判が範囲外でも、ブランドは 0〜100 点ぶんで頭打ち', () {
      expect(_value(reputation: 500).brand, 100 * ClubValueEngine.reputationPerPoint);
      expect(_value(reputation: -5).brand, 0);
    });

    test('合計は、価値の合計から融資の残りを引く。資金がマイナスなら引かれる', () {
      final v = _value(players: 1000, income: 500, cash: -200, debt: 300);
      expect(v.total, 1000 + 500 - 200 - 300);
    });

    test('負債があるときだけ、内訳に融資の行が負で出る', () {
      expect(_value().lines.length, 5);
      final with_ = _value(debt: 300).lines;
      expect(with_.length, 6);
      expect(with_.last.$2, -300);
    });
  });

  group('ゲームの中', () {
    test('新規開始でクラブ価値は正で、内訳が合計と合う', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      final v = gs.clubValue;
      expect(v.total, greaterThan(0));
      expect(v.lines.fold<int>(0, (s, l) => s + l.$2), v.total);
    });

    test('新規開始(3部・施設はレベル1)でも、「施設・スタッフ」は0円でない', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      expect(
          gs.clubValue.facilities,
          greaterThanOrEqualTo(ClubValueEngine.facilityValue(
              FacilityType.stadium,
              gs.save!.infrastructure.facilityLevel(FacilityType.stadium))));
      expect(gs.clubValue.facilities, greaterThan(0));
    });

    test('施設を0円で数えていた頃のセーブは、目標・計画の基準の価値を一度だけ直す',
        () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      final s = gs.save!;
      s.ownerGoalStartValue = 500000;
      s.planStartSeason = s.league.season;
      s.planTargetValue = 900000;
      for (final f in FacilityType.values) {
        s.infrastructure.facilityLevels[f] = 1;
      }
      final json = jsonDecode(gs.exportSaveJson()!) as Map<String, dynamic>
        ..remove('clubValueVersion');
      expect(SaveGame.fromJson(json).clubValueVersion, 1);
      final loaded = GameState();
      expect(await loaded.importSaveJson(jsonEncode(json)), isTrue);
      final ls = loaded.save!;
      expect(ls.clubValueVersion, SaveGame.currentClubValueVersion);
      // 施設は全部レベル1なので、差はレベル1の施設の価値そのもの。
      final lv1 = FacilityType.values.fold<int>(
          0, (t, f) => t + ClubValueEngine.facilityValue(f, 1));
      expect(ls.ownerGoalStartValue, 500000 + lv1);
      expect(ls.planTargetValue, 900000 + lv1);
      // もう一度読み込んでも、二重には足さない。
      final again = GameState();
      expect(await again.importSaveJson(loaded.exportSaveJson()!), isTrue);
      expect(again.save!.ownerGoalStartValue, 500000 + lv1);
    });

    test('選手を放出して現金が増えても、価値は選手の分だけ動く(ごまかせない)', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      final before = gs.clubValue;
      gs.save!.budget += 1000;
      expect(gs.clubValue.total, before.total + 1000);
    });

    test('シーズン末に記録され、保存して読み戻せ、無い旧セーブは空', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      gs.debugRecordClubValue();
      expect(gs.clubValueHistory.length, 1);
      final json = gs.save!.toJson();
      final back = SaveGame.fromJson(json);
      expect(back.clubValueHistory, gs.save!.clubValueHistory);
      json
        ..remove('clubValueHistory')
        ..remove('ownerGoalStartValue');
      final old = SaveGame.fromJson(json);
      expect(old.clubValueHistory, isEmpty);
      expect(old.ownerGoalStartValue, 0);
    });

    test('「クラブ価値を2倍に」は、選んだときの価値を基準にし、2倍で達成になる', () {
      bool met(double ratio) => OwnerGoalRules.isMet(OwnerGoal.clubValue,
          wonTopLeague: false,
          promotedOrTop: false,
          wonCup: false,
          budget: 0,
          valueRatio: ratio);
      expect(met(1.99), isFalse);
      expect(met(2.0), isTrue);
    });

    test('目標を選ぶと、そのときの価値を覚える', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      await gs.setOwnerGoal(OwnerGoal.clubValue);
      expect(gs.save!.ownerGoalStartValue, gs.clubValue.total);
    });

    test('価値が2倍になったシーズン末に達成し、殿堂に残る', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      await gs.setOwnerGoal(OwnerGoal.clubValue);
      gs.save!.budget += gs.save!.ownerGoalStartValue; // 価値がちょうど2倍
      gs.debugEvaluateOwnerGoal(season: 1);
      expect(gs.ownerGoal, isNull);
      expect(gs.achievedGoals.single, contains('クラブ価値'));
    });
  });
}
