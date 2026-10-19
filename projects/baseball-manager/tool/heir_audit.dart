// ignore_for_file: avoid_print
// 二世(殿堂の選手の子)が、ふつうに始めるより有利すぎないかを見る(dart run tool/heir_audit.dart)。
import 'dart:math';
import 'package:baseball_manager/game/career.dart';
import 'package:baseball_manager/game/game.dart';
import 'package:baseball_manager/game/life.dart';
import 'package:baseball_manager/game/path.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:baseball_manager/game/snapshot.dart';

Game run(int seed, PlayerSnapshot? parent) {
  final g = Game.newGame(
      name: 't', role: Role.batter, rng: Random(seed), parent: parent);
  var n = 0;
  while (g.phase != Phase.retired && n++ < 6000) {
    g.autoSpend();
    switch (g.phase) {
      case Phase.term:
        if (g.stage == Stage.pro && g.player.age >= 36) {
          g.retire();
        } else {
          g.choose(g.condition.fatigue >= 60 ? Plan.rest : Plan.train,
              abilitiesOf(g.player.role).first);
        }
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
  // 親: 素質の高い「レジェンド」を探す
  PlayerSnapshot? parent;
  for (var s = 0; s < 400 && parent == null; s++) {
    final g = run(s + 1000, null);
    if (g.ending!.peakOverall >= 78) parent = PlayerSnapshot.fromGame(g);
  }
  if (parent == null) {
    print('親が見つからない');
    return;
  }
  for (final heir in [false, true]) {
    var pro = 0, peak = 0, legend = 0;
    const n = 600;
    for (var s = 0; s < n; s++) {
      final g = run(s, heir ? parent : null);
      if (g.ending!.madePro) pro++;
      peak += g.ending!.peakOverall;
      if (g.ending!.title == 'レジェンド') legend++;
    }
    print(
        '${heir ? '二世(親 素質${parent.potential})' : 'ふつう'}: プロ入り ${(pro * 100 / n).toStringAsFixed(1)}%  最高評価平均 ${(peak / n).toStringAsFixed(1)}  レジェンド ${(legend * 100 / n).toStringAsFixed(1)}%');
  }
}
