import 'dart:math';

import 'package:baseball_manager/game/game.dart';
import 'package:baseball_manager/game/life.dart';
import 'package:baseball_manager/game/path.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:flutter_test/flutter_test.dart';

/// プロ8年目の最初まで進める(届かなければ失敗)。
Game _fa() {
  for (var s = 0; s < 80; s++) {
    final g = Game.newGame(
        name: 't', role: Role.batter, rng: Random(s), potential: 100);
    var n = 0;
    while (g.phase != Phase.retired && n++ < 5000) {
      g.autoSpend();
      if (g.canUseFa) return g;
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
  }
  fail('FA権を使える所まで進めない');
}

void main() {
  test('FA権はプロ8年目以降の年の最初に、一生に一度だけ使える', () {
    final g = _fa();
    expect(g.canUseFa, isTrue);
    g.useFa(FaChoice.stay);
    expect(g.canUseFa, isFalse);
    expect(() => g.useFa(FaChoice.stay), throwsStateError);
  });
  test('強豪へ移籍するとチーム名が変わり、契約金が入ってチーム力+3', () {
    final g = _fa();
    final before = g.proTeam, money = g.money;
    g.useFa(FaChoice.contender);
    expect(g.proTeam, isNot(before));
    expect(g.teamBoost, 3);
    expect(g.money, money + 4000);
    expect(g.lifeLog.last.text, contains('FAで'));
  });
  test('高額オファーは契約金1億円とチーム力-2', () {
    final g = _fa();
    final money = g.money;
    g.useFa(FaChoice.cash);
    expect(g.teamBoost, -2);
    expect(g.money, money + 10000);
  });
  test('保存と読み込みで残る(古い保存は初期値)', () {
    final g = _fa();
    g.useFa(FaChoice.contender);
    final r = Game.fromJson(g.toJson(), Random(1));
    expect(r.teamBoost, 3);
    expect(r.faUsed, isTrue);
    final j = g.toJson()
      ..remove('teamBoost')
      ..remove('faUsed');
    final old = Game.fromJson(j, Random(1));
    expect(old.teamBoost, 0);
    expect(old.faUsed, isFalse);
  });
}
