// ignore_for_file: avoid_print
import 'dart:math';
import 'package:baseball_manager/game/game.dart';
import 'package:baseball_manager/game/life.dart';
import 'package:baseball_manager/game/path.dart';
import 'package:baseball_manager/game/player.dart';

/// 1人の一生を自動で遊んで、ログを全部出す(文言・数字のおかしさを目で探す用)。
void main(List<String> args) {
  final seed = args.isEmpty ? 7 : int.parse(args[0]);
  final g = Game.newGame(
      name: 'テスト', role: Role.pitcher, rng: Random(seed), potential: 80);
  var n = 0;
  while (g.phase != Phase.retired && n++ < 3000) {
    g.autoSpend();
    switch (g.phase) {
      case Phase.term:
        g.choose(g.condition.fatigue >= 60 ? Plan.rest : Plan.train,
            g.player.role == Role.batter ? Ability.contact : Ability.stuff);
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
