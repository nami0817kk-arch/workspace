import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/logic/club_value_engine.dart';
import 'package:soccer_manager/models/owner_goal.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';

ClubValue _value({
  int players = 1000,
  List<int> facilities = const [1, 1, 1],
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
    test('レベル1の施設は数えず、上げた分だけ価値が増える', () {
      expect(_value().facilities, 0);
      expect(_value(facilities: [3, 1, 1]).facilities,
          2 * ClubValueEngine.facilityPerLevel);
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
