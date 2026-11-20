import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_manager/models/owner_goal.dart';

/// オーナーの目標に足した6種類の判定。
void main() {
  bool met(
    OwnerGoal g, {
    int topFourCount = 0,
    bool unbeaten = false,
    int stadiumLevel = 0,
    int healthScore = 0,
    int supporter = 0,
    int shareholder = 0,
  }) =>
      OwnerGoalRules.isMet(
        g,
        wonTopLeague: false,
        promotedOrTop: false,
        wonCup: false,
        budget: 0,
        topFourCount: topFourCount,
        unbeaten: unbeaten,
        stadiumLevel: stadiumLevel,
        healthScore: healthScore,
        supporter: supporter,
        shareholder: shareholder,
      );

  test('目標は11種類で、名前と期限が全部ある', () {
    expect(OwnerGoal.values.length, 11);
    final labels = <String>{};
    for (final g in OwnerGoal.values) {
      expect(g.label, isNotEmpty, reason: '$g');
      expect(g.deadlineSeasons, greaterThan(0), reason: '$g');
      labels.add(g.label);
    }
    expect(labels.length, 11, reason: '名前が重複している');
  });

  test('1部で4位以内は、3シーズン以上で達成', () {
    expect(met(OwnerGoal.topFour, topFourCount: 2), isFalse);
    expect(met(OwnerGoal.topFour, topFourCount: OwnerGoalRules.topFourSeasons),
        isTrue);
  });

  test('無敗は、負けなしのシーズンがあれば達成', () {
    expect(met(OwnerGoal.unbeaten), isFalse);
    expect(met(OwnerGoal.unbeaten, unbeaten: true), isTrue);
  });

  test('スタジアムは、目標レベル以上で達成', () {
    expect(met(OwnerGoal.bigStadium, stadiumLevel: OwnerGoalRules.stadiumTarget - 1),
        isFalse);
    expect(met(OwnerGoal.bigStadium, stadiumLevel: OwnerGoalRules.stadiumTarget),
        isTrue);
  });

  test('経営診断Aは、点数が下限以上で達成', () {
    expect(met(OwnerGoal.healthA, healthScore: OwnerGoalRules.healthTarget - 1),
        isFalse);
    expect(met(OwnerGoal.healthA, healthScore: OwnerGoalRules.healthTarget), isTrue);
  });

  test('サポーター・株主の期待は、目標値以上で達成', () {
    expect(met(OwnerGoal.fanFavorite, supporter: OwnerGoalRules.fanTarget - 1),
        isFalse);
    expect(met(OwnerGoal.fanFavorite, supporter: OwnerGoalRules.fanTarget), isTrue);
    expect(
        met(OwnerGoal.investorFavorite,
            shareholder: OwnerGoalRules.investorTarget - 1),
        isFalse);
    expect(
        met(OwnerGoal.investorFavorite, shareholder: OwnerGoalRules.investorTarget),
        isTrue);
  });

  test('新しい目標は、旧来の目標の判定に影響しない', () {
    expect(
        OwnerGoalRules.isMet(OwnerGoal.richClub,
            wonTopLeague: false,
            promotedOrTop: false,
            wonCup: false,
            budget: OwnerGoalRules.richTarget),
        isTrue);
    expect(
        OwnerGoalRules.isMet(OwnerGoal.leagueTitle,
            wonTopLeague: true,
            promotedOrTop: false,
            wonCup: false,
            budget: 0),
        isTrue);
  });
}
