import 'dart:convert';

import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('施設はシーズン前に上げられ、費用は開幕で支出に入り、保存しても残る', () {
    final c = careerAt(5, 10);
    expect(c.phase, Phase.preseason);
    expect(c.facilityLevel(Facility.arena), 1);
    final attBefore = c.attendance;
    expect(c.upgradeFacility(Facility.arena), isTrue);
    expect(c.facilityLevel(Facility.arena), 2);
    expect(c.attendance, greaterThan(attBefore));
    expect(c.facilityDebt, facilityUpgradeCost[2]);
    expect(c.upgradeFacility(Facility.medical), isTrue);
    expect(c.medicalScale, lessThan(1));
    final back = Career.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
    expect(back.facilities, c.facilities);
    expect(back.facilityDebt, c.facilityDebt);
    c.startSeason();
    expect(c.costs, facilityUpgradeCost[2] * 2 + facilityUpkeep[2] * 2);
    expect(c.facilityDebt, 0);
    expect(c.facilityProblem(Facility.training), isNotNull, reason: 'シーズン中は上げられない');
    expect(c.upgradeFacility(Facility.training), isFalse);
  });

  test('段階3より上には上げられない', () {
    final c = careerAt(5, 10);
    expect(c.upgradeFacility(Facility.training), isTrue);
    expect(c.upgradeFacility(Facility.training), isTrue);
    expect(c.facilityLevel(Facility.training), 3);
    expect(c.upgradeFacility(Facility.training), isFalse);
  });

  test('練習施設を上げると、若手の伸びに内訳が付く', () {
    final c = careerAt(6, 8);
    c.upgradeFacility(Facility.training);
    c.upgradeFacility(Facility.training);
    var guard = 0;
    while (c.phase != Phase.seasonEnd && guard++ < 200) {
      botStep(c);
    }
    c.toOffseason();
    final young = c.growth.where((g) => g.age <= 24 && g.delta > 0);
    expect(young, isNotEmpty);
    expect(c.growth.any((g) => g.parts.any((x) => x.$1 == Facility.training.label)), isTrue);
  });
}
