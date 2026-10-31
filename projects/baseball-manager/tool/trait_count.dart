// 引退までに、特性・特殊能力をいくつ持つかを数える(特性が増えすぎていないかの点検)。
//
//   dart run tool/trait_count.dart 300
//
// 「上手い」遊び方(balance.dart と同じ)で遊ばせ、引退したときの数の分布を出す。
// ignore_for_file: avoid_print
import 'dart:math';

import 'package:baseball_manager/game/game.dart';
import 'package:baseball_manager/game/path.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:baseball_manager/game/traits.dart';

import 'balance.dart' show skilled;

void main(List<String> args) {
  final n = args.isEmpty ? 300 : int.parse(args.first);
  for (final role in [Role.batter, Role.pitcher]) {
    final dist = <int, int>{};
    final from = <String, int>{};
    var rare = 0, totalNormal = 0, atBirth = 0;
    for (var s = 0; s < n; s++) {
      final g = Game.newGame(name: 't', role: role, rng: Random(s));
      atBirth += g.player.traits.where((t) => !t.rare).length;
      var steps = 0;
      while (g.phase != Phase.retired && ++steps < 6000) {
        g.autoSpend();
        switch (g.phase) {
          case Phase.term:
            if (g.stage.name == 'pro' && g.player.age >= 36) {
              g.retire();
            } else {
              skilled(g);
            }
          case Phase.event:
            g.resolveEvent(g.rng.nextInt(g.pendingEvent!.choices.length));
          case Phase.pathChoice:
            g.chooseRoute(Course.university);
          case Phase.retired:
            break;
        }
      }
      final normal = g.player.traits.where((t) => !t.rare).length;
      totalNormal += normal;
      if (g.player.traits.any((t) => t.rare)) rare++;
      dist.update(normal, (v) => v + 1, ifAbsent: () => 1);
      for (final e in g.lifeLog.where((e) => e.kind == 'trait')) {
        final k = e.text.contains('特殊能力') || e.text.contains('コツ')
            ? '特殊能力'
            : (e.text.contains('覚醒') ? '覚醒' : '特性');
        from.update(k, (v) => v + 1, ifAbsent: () => 1);
      }
    }
    print('${role.name}: 通常の特性 平均${(totalNormal / n).toStringAsFixed(2)}個'
        '(生まれつき${(atBirth / n).toStringAsFixed(2)}) レア${(100 * rare / n).toStringAsFixed(0)}%');
    print('  個数の分布: ${[for (var k = 0; k <= maxTraits; k++) '$k個 ${(100 * (dist[k] ?? 0) / n).toStringAsFixed(0)}%'].join(' / ')}');
    print('  年表の記録: $from');
  }
}
