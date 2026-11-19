import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_manager/logic/offscreen_development.dart';
import 'package:soccer_manager/logic/player_generator.dart';
import 'package:soccer_manager/logic/training_engine.dart';
import 'package:soccer_manager/models/player.dart';

void main() {
  Player make(Position pos, int age) {
    final p =
        PlayerGenerator.generate(position: pos, strengthTier: 70, ageOverride: age);
    p.growthType = PlayerGrowthType.balanced;
    return p;
  }

  test('衰えの始まる年齢: GK は3年遅く、センターバックは1年遅く、サイドは1年早い', () {
    expect(TrainingEngine.declineStartAge(make(Position.mc, 25)), 31);
    expect(TrainingEngine.declineStartAge(make(Position.gk, 25)), 34);
    expect(TrainingEngine.declineStartAge(make(Position.dc, 25)), 32);
    expect(TrainingEngine.declineStartAge(make(Position.aml, 25)), 30);
    expect(TrainingEngine.declineStartAge(make(Position.dr, 25)), 30);
    expect(TrainingEngine.declineStartAge(make(Position.st, 25)), 31);
  });

  test('他の部の選手も、32歳の GK は落ちにくく、32歳のウイングは落ちる', () {
    final rng = Random(1);
    var gkSum = 0;
    var wingSum = 0;
    for (var i = 0; i < 300; i++) {
      gkSum += OffscreenDevelopment.yearlyChange(make(Position.gk, 32), rng);
      wingSum += OffscreenDevelopment.yearlyChange(make(Position.amr, 32), rng);
    }
    expect(gkSum, greaterThan(wingSum));
    expect(wingSum, lessThan(-300), reason: '32歳のウイングは毎年1以上落ちる');
  });
}
