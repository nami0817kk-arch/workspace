// 進学先ごとのプロ入り率を見る(dart run tool/school_balance.dart)。
// ignore_for_file: avoid_print
import 'dart:math';
import 'package:baseball_manager/game/game.dart';
import 'package:baseball_manager/game/life.dart';
import 'package:baseball_manager/game/path.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:baseball_manager/game/school.dart';

void main() {
  for (final s in School.values) {
    var pro = 0, peak = 0;
    const n = 600;
    for (var i = 0; i < n; i++) {
      final g = Game.newGame(
          name: 't', role: Role.batter, rng: Random(i), potential: null);
      var k = 0;
      while (g.phase != Phase.retired && k++ < 5000) {
        g.autoSpend();
        if (g.canChooseSchool) g.chooseSchool(s);
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
      if (g.ending?.madePro ?? false) pro++;
      peak += g.ending?.peakOverall ?? 0;
    }
    print(
        '${s.label}: プロ入り ${(pro * 100 / n).toStringAsFixed(1)}%  最高評価平均 ${(peak / n).toStringAsFixed(1)}');
  }
}
