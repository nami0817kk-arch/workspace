import 'package:baseball_manager/game/career.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('年齢で段階が進む', () {
    expect(stageOf(6), Stage.youth);
    expect(stageOf(13), Stage.juniorHigh);
    expect(stageOf(16), Stage.highSchool);
    expect(stageOf(19), Stage.pathChoice);
    expect(stageOf(20, turnedPro: true), Stage.pro);
    expect(stageOf(maxProAge + 1, turnedPro: true), Stage.retired);
  });

  test('伸びやすさは若いほど大きく、後半は下降する', () {
    expect(growthFactor(8), greaterThan(growthFactor(22)));
    expect(growthFactor(22), greaterThan(growthFactor(28)));
    expect(growthFactor(36), lessThan(0));
  });

  test('少年期から引退まで全年齢で段階が定まる', () {
    for (var a = startAge; a <= maxProAge + 1; a++) {
      expect(() => stageOf(a, turnedPro: a >= 19), returnsNormally);
    }
  });
}
