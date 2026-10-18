import 'dart:math';

import 'package:baseball_manager/game/career.dart';
import 'package:baseball_manager/game/game.dart';
import 'package:baseball_manager/game/life.dart';
import 'package:baseball_manager/game/path.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:baseball_manager/game/school.dart';
import 'package:flutter_test/flutter_test.dart';

Game _toHighSchool([int seed = 1]) {
  final g = Game.newGame(
      name: 't', role: Role.batter, rng: Random(seed), potential: 80);
  var n = 0;
  while (!(g.stage == Stage.highSchool && g.canChooseSchool) && n++ < 2000) {
    g.autoSpend();
    switch (g.phase) {
      case Phase.term:
        g.choose(g.condition.fatigue >= 60 ? Plan.rest : Plan.train,
            Ability.contact);
      case Phase.event:
        g.resolveEvent(0);
      case Phase.pathChoice:
        g.chooseRoute(Course.university);
      case Phase.retired:
        break;
    }
  }
  return g;
}

void main() {
  test('進学先は、中学・高校の入学の年の最初だけ選べる', () {
    final g = Game.newGame(name: 't', role: Role.batter, rng: Random(1));
    expect(g.canChooseSchool, isFalse); // 少年野球
    expect(() => g.chooseSchool(School.powerhouse), throwsStateError);
    final h = _toHighSchool();
    expect(h.canChooseSchool, isTrue);
    expect(h.school, School.local);
    h.chooseSchool(School.powerhouse);
    expect(h.school, School.powerhouse);
  });
  test('強豪校は疲れがたまり、進学校は経験点が増える', () {
    int fatigueAfter(School s) {
      final g = _toHighSchool();
      g.chooseSchool(s);
      final f = g.condition.fatigue;
      g.choose(Plan.train, Ability.contact);
      return g.condition.fatigue - f;
    }

    expect(fatigueAfter(School.powerhouse),
        greaterThan(fatigueAfter(School.local)));
    int expAfter(School s) {
      final g = _toHighSchool();
      g.chooseSchool(s);
      g.choose(Plan.train, Ability.contact);
      return g.lastGain.values.fold(0, (a, b) => a + b);
    }

    expect(expAfter(School.academic),
        greaterThanOrEqualTo(expAfter(School.local)));
  });
  test('段階が変わると地元の学校に戻る。保存で残り、古い保存は地元', () {
    final g = _toHighSchool();
    g.chooseSchool(School.academic);
    final r = Game.fromJson(g.toJson(), Random(1));
    expect(r.school, School.academic);
    final j = g.toJson()..remove('school');
    expect(Game.fromJson(j, Random(1)).school, School.local);
  });
}
