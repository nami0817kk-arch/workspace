// 海外(アメリカ)のリーグで、優勝・順位がどのくらい取れるかを見る(dart run tool/overseas_audit.dart [人数])。
// 素質の高い選手が、プロ入りしてすぐ海を渡り、特訓と休養で遊んだ場合。
// ignore_for_file: avoid_print
import 'dart:math';

import 'package:baseball_manager/game/career.dart';
import 'package:baseball_manager/game/game.dart';
import 'package:baseball_manager/game/life.dart';
import 'package:baseball_manager/game/path.dart';
import 'package:baseball_manager/game/player.dart';

void main(List<String> a) {
  final n = a.isEmpty ? 300 : int.parse(a.first);
  var years = 0, titles = 0;
  final ranks = <int, int>{};
  for (var s = 0; s < n; s++) {
    final role = s.isEven ? Role.batter : Role.pitcher;
    final g =
        Game.newGame(name: 't', role: role, rng: Random(s), potential: 95);
    while (g.phase != Phase.retired) {
      g.autoSpend();
      switch (g.phase) {
        case Phase.term:
          if (g.stage == Stage.pro && g.player.age >= 36) {
            g.retire();
            break;
          }
          if (g.stage == Stage.pro && g.canMoveOverseas) g.moveOverseas();
          final ab = abilitiesOf(g.player.role);
          g.choose(g.condition.fatigue >= 60 ? Plan.rest : Plan.special,
              ab[g.slot % ab.length]);
        case Phase.event:
          g.resolveEvent(0);
        case Phase.pathChoice:
          g.chooseRoute(Course.university);
        case Phase.retired:
          break;
      }
    }
    for (final r in g.records.where((r) => r.overseas)) {
      years++;
      final k = r.rank ?? 0;
      ranks[k] = (ranks[k] ?? 0) + 1;
      if (k == 1) titles++;
    }
  }
  print('海外 $years シーズン / $n人。優勝 $titles回');
  print(
      '順位分布: ${(ranks.entries.toList()..sort((x, y) => x.key.compareTo(y.key))).map((e) => '${e.key}位:${e.value}').join(' ')}');
}
