// 育成ミッションと、1年の成長の記録(2026-10-28)。
import 'dart:convert';
import 'dart:math';

import 'package:baseball_manager/game/career.dart';
import 'package:baseball_manager/game/exp.dart';
import 'package:baseball_manager/game/game.dart';
import 'package:baseball_manager/game/life.dart';
import 'package:baseball_manager/game/missions.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:flutter_test/flutter_test.dart';

Game _g([int seed = 1]) =>
    Game.newGame(name: 'み', role: Role.batter, rng: Random(seed), potential: 60);

void main() {
  test('どの段階にもミッションがあり、id は重ならない', () {
    for (final s in [
      Stage.youth,
      Stage.juniorHigh,
      Stage.highSchool,
      Stage.pathChoice,
      Stage.pro
    ]) {
      expect(missionsFor(s).length, greaterThanOrEqualTo(3));
    }
    expect(missions.map((m) => m.id).toSet().length, missions.length);
  });

  test('達成すると1度だけ経験点とやる気がもらえ、保存しても残る', () {
    final g = _g();
    g.adminSetAbility(Ability.contact, 55);
    final before = g.exp.of(Category.batting);
    expect(g.checkMissions(), 1); // どれか1つの能力を50以上に
    expect(g.missionsDone, contains('y-ability'));
    expect(g.exp.of(Category.batting), before + missionExp(Stage.youth));
    expect(g.log.last, startsWith('育成ミッション達成'));
    expect(g.checkMissions(), 0); // 2度目はもらえない
    final back = Game.fromJson(
        jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>, Random(1));
    expect(back.missionsDone, contains('y-ability'));
  });

  test('振り分けで条件を満たしても達成する', () {
    final g = _g(2);
    g.adminSetAbility(Ability.contact, 49);
    g.adminAddExp(500);
    g.spend(Ability.contact);
    expect(g.missionsDone, contains('y-ability'));
  });

  test('年の終わりに「この1年の成長」が出る。いちばん伸びた年は自己ベスト', () {
    final g = _g(3);
    var n = 0;
    while (g.player.age < 9 && n++ < 400) {
      g.autoSpend();
      if (g.phase == Phase.event) {
        g.resolveEvent(0);
      } else {
        g.choose(Plan.train, Ability.contact);
      }
    }
    expect(g.log.where((l) => l.startsWith('この1年の成長')), isNotEmpty);
    expect(g.bestYearGain, greaterThan(0));
  });
}
