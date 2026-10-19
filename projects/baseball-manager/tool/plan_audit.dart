// ignore_for_file: avoid_print
// 行動(練習・特訓…)ごとの、経験点・疲れ・やる気の変化を比べる(dart run tool/plan_audit.dart)。
import 'dart:math';
import 'package:baseball_manager/game/game.dart';
import 'package:baseball_manager/game/life.dart';
import 'package:baseball_manager/game/path.dart';
import 'package:baseball_manager/game/player.dart';

void main() {
  for (final stage in [13, 17, 22]) {
    print('--- $stage歳ごろ');
    for (final plan in Plan.values) {
      var exp = 0.0, fat = 0.0, mor = 0.0, inj = 0;
      const n = 300;
      var cnt = 0;
      for (var s = 0; s < n; s++) {
        final g = Game.newGame(
            name: 't', role: Role.batter, rng: Random(s), potential: 70);
        var k = 0;
        while (g.player.age < stage && g.phase != Phase.retired && k++ < 3000) {
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
        if (g.phase != Phase.term) continue;
        final f0 = g.condition.fatigue, m0 = g.condition.morale;
        g.choose(plan, Ability.contact);
        exp += g.lastGain.values.fold(0, (a, b) => a + b);
        fat += g.condition.fatigue - f0;
        mor += g.condition.morale - m0;
        if (g.condition.injured) inj++;
        cnt++;
      }
      print(
          '${plan.name.padRight(8)} 経験点${(exp / cnt).toStringAsFixed(1).padLeft(6)}  疲れ${(fat / cnt).toStringAsFixed(1).padLeft(6)}  やる気${(mor / cnt).toStringAsFixed(1).padLeft(6)}  怪我${(inj * 100 / cnt).toStringAsFixed(1)}%');
    }
  }
}
