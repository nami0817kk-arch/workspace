import 'dart:math';

import 'package:baseball_manager/game/game.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pennant_test.dart' show proGameForTest;

void main() {
  test('オフの過ごし方は、プロの年のはじめに年1度だけ選べる', () {
    final g = proGameForTest();
    expect(g.canChooseOffseason, isTrue);
    g.chooseOffseason(Offseason.family, Ability.contact);
    expect(g.canChooseOffseason, isFalse);
    expect(() => g.chooseOffseason(Offseason.camp, Ability.contact),
        throwsStateError);
  });
  test('家族旅行は疲れが減りやる気が上がる。自主トレは疲れて経験点が入る', () {
    final a = proGameForTest();
    final f0 = a.condition.fatigue, m0 = a.condition.morale;
    a.chooseOffseason(Offseason.family, Ability.contact);
    expect(a.condition.fatigue, lessThanOrEqualTo(f0));
    expect(a.condition.morale, greaterThanOrEqualTo(m0));
    final b = proGameForTest();
    final total0 = b.exp.total;
    final bf = b.condition.fatigue;
    b.chooseOffseason(Offseason.camp, Ability.contact);
    expect(b.condition.fatigue, greaterThanOrEqualTo(bf));
    expect(b.exp.total, total0 + 8);
  });
  test('保存で残る(古い保存は未選択)', () {
    final g = proGameForTest();
    g.chooseOffseason(Offseason.rehab, Ability.contact);
    expect(Game.fromJson(g.toJson(), Random(1)).offseasonDone, isTrue);
    final j = g.toJson()..remove('offseasonDone');
    expect(Game.fromJson(j, Random(1)).offseasonDone, isFalse);
  });
}
