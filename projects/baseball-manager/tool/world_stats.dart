// ignore_for_file: avoid_print
import 'dart:math';
import 'package:baseball_manager/game/game.dart';
import 'package:baseball_manager/game/life.dart';
import 'package:baseball_manager/game/path.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:baseball_manager/game/world.dart';

/// 世界大会の選出率と優勝率を調べる。使い方: dart run tool/world_stats.dart [人数]
void main(List<String> a) {
  final n = a.isEmpty ? 500 : int.parse(a[0]);
  final sel = <String, int>{}, champ = <String, int>{}, reach = <String, int>{};
  var anyWorld = 0;
  for (var seed = 0; seed < n; seed++) {
    final g = Game.newGame(
        name: 't',
        role: Role.values[seed % 2],
        rng: Random(seed),
        potential: 20 + seed % 80);
    var k = 0;
    while (g.phase != Phase.retired && k++ < 4000) {
      g.autoSpend();
      switch (g.phase) {
        case Phase.term:
          final ab = abilitiesOf(g.player.role);
          g.choose(g.condition.fatigue >= 60 ? Plan.rest : Plan.train, ab[0]);
        case Phase.event:
          g.resolveEvent(0);
        case Phase.pathChoice:
          g.chooseRoute(Course.university);
        case Phase.retired:
          break;
      }
    }
    if (g.worldRecords.isNotEmpty) anyWorld++;
    for (final r in g.worldRecords) {
      sel[r.eventId] = (sel[r.eventId] ?? 0) + 1;
      if (r.champion) champ[r.eventId] = (champ[r.eventId] ?? 0) + 1;
      if (r.roundsWon >= 3) reach[r.eventId] = (reach[r.eventId] ?? 0) + 1;
    }
  }
  print('人数 $n / 1回でも代表に選ばれた人 $anyWorld');
  for (final e in worldEvents) {
    final s = sel[e.id] ?? 0;
    print(
        '${e.name}: 選出 $s (${(s * 100 / n).toStringAsFixed(0)}%) / 決勝まで ${reach[e.id] ?? 0} / 優勝 ${champ[e.id] ?? 0}');
  }
}
