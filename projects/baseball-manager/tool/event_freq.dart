// 出来事が1人の一生に何回出るかを数える(出すぎ・出なさすぎの確認。dart run tool/event_freq.dart [人数])。
// ignore_for_file: avoid_print
import 'dart:math';

import 'package:baseball_manager/game/career.dart';
import 'package:baseball_manager/game/game.dart';
import 'package:baseball_manager/game/life.dart';
import 'package:baseball_manager/game/path.dart';
import 'package:baseball_manager/game/player.dart';

void main(List<String> a) {
  final n = a.isEmpty ? 200 : int.parse(a.first);
  final tot = <String, int>{};
  final maxPer = <String, int>{};
  var evTotal = 0;
  for (var s = 0; s < n; s++) {
    final g = Game.newGame(
        name: 't', role: s.isEven ? Role.batter : Role.pitcher, rng: Random(s));
    final mine = <String, int>{};
    while (g.phase != Phase.retired) {
      g.autoSpend();
      switch (g.phase) {
        case Phase.term:
          if (g.stage == Stage.pro && g.player.age >= 36) {
            g.retire();
            break;
          }
          final ab = abilitiesOf(g.player.role);
          g.choose(g.condition.fatigue >= 60 ? Plan.rest : Plan.train,
              ab[g.slot % ab.length]);
        case Phase.event:
          final id = g.pendingEvent!.id;
          mine[id] = (mine[id] ?? 0) + 1;
          evTotal++;
          g.resolveEvent(0);
        case Phase.pathChoice:
          g.chooseRoute(Course.university);
        case Phase.retired:
          break;
      }
    }
    mine.forEach((k, v) {
      tot[k] = (tot[k] ?? 0) + v;
      maxPer[k] = max(maxPer[k] ?? 0, v);
    });
  }
  print('1人あたり出来事 ${(evTotal / n).toStringAsFixed(1)}件');
  final l = tot.entries.toList()..sort((x, y) => y.value.compareTo(x.value));
  for (final e in l) {
    print('${e.key.padRight(16)} 平均${(e.value / n).toStringAsFixed(2)}回 '
        '最多${maxPer[e.key]}回');
  }
  print('一度も出なかった: '
      '${events.map((e) => e.id).where((i) => !tot.containsKey(i)).join(', ')}');
}
