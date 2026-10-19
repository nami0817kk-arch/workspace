// ignore_for_file: avoid_print
// 1人ぶんのログを全部出して、読みづらい文・重複・おかしな数字を探す(dart run tool/log_audit.dart [seed])。
import 'dart:math';
import 'package:baseball_manager/game/game.dart';
import 'package:baseball_manager/game/life.dart';
import 'package:baseball_manager/game/path.dart';
import 'package:baseball_manager/game/player.dart';

void main(List<String> a) {
  final seed = a.isEmpty ? 3 : int.parse(a[0]);
  final g = Game.newGame(
      name: 'ユウタ', role: Role.pitcher, rng: Random(seed), potential: 95);
  var n = 0;
  while (g.phase != Phase.retired && n++ < 5000) {
    g.autoSpend();
    switch (g.phase) {
      case Phase.term:
        g.choose(g.condition.fatigue >= 60 ? Plan.rest : Plan.train,
            abilitiesOf(g.player.role).first);
      case Phase.event:
        g.resolveEvent(0);
      case Phase.pathChoice:
        g.chooseRoute(Course.university);
      case Phase.retired:
        break;
    }
  }
  for (final l in g.log) {
    print(l);
  }
}
