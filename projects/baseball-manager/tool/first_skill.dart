// 何もしなくても特殊能力が取れてしまうか: 練習だけで、何ターン目に最初の特殊能力が買えるかを数える。
// ignore_for_file: avoid_print
import 'dart:math';

import 'package:baseball_manager/game/game.dart';
import 'package:baseball_manager/game/life.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:baseball_manager/game/skills.dart';

void main() {
  for (final role in [Role.batter, Role.pitcher]) {
    final turns = <int>[];
    for (var s = 0; s < 200; s++) {
      final g = Game.newGame(name: 't', role: role, rng: Random(s));
      for (var t = 1; t <= 40; t++) {
        while (g.phase == Phase.event) {
          g.resolveEvent(0);
        }
        if (g.phase != Phase.term) break;
        g.choose(g.condition.fatigue >= 60 ? Plan.rest : Plan.train,
            abilitiesOf(role).first);
        final ok = skillsFor(role).any((k) =>
            skillBlock(g.player, k, g.exp, g.skillTips[k] ?? 0) == null);
        if (ok) {
          turns.add(t);
          break;
        }
      }
    }
    turns.sort();
    print('${role.name}: 練習だけで最初に取れるのは ${turns.isEmpty ? '-' : turns[turns.length ~/ 2]}ターン目(中央値) 年齢 ${6 + (turns.isEmpty ? 0 : turns[turns.length ~/ 2]) ~/ 4}歳ごろ  (${turns.length}/200人)');
  }
}
