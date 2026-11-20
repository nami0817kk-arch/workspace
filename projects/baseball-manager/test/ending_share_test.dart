import 'dart:math';

import 'package:baseball_manager/game/game.dart';
import 'package:baseball_manager/game/life.dart';
import 'package:baseball_manager/game/path.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:baseball_manager/ui/game_screen.dart';
import 'package:baseball_manager/ui/labels.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('引退時の共有文に、役割の主な能力がランク付きで並ぶ(2026-11-03)', () {
    for (final role in Role.values) {
      final g = Game.newGame(name: 'テスト', role: role, rng: Random(3));
      var n = 0;
      while (g.phase != Phase.retired && n++ < 3000) {
        g.autoSpend();
        switch (g.phase) {
          case Phase.term:
            g.choose(Plan.train, abilitiesOf(g.player.role).first);
          case Phase.event:
            g.resolveEvent(0);
          case Phase.pathChoice:
            g.chooseRoute(Course.corporate);
          case Phase.retired:
            break;
        }
      }
      final t = endingShareText(g);
      final line = t.split('\n').firstWhere((l) => l.startsWith('最後の能力: '));
      for (final a in mainAbilitiesOf(role)) {
        expect(line, contains('${abilityLabel(a)}${rankOf(g.player.of(a))}'));
      }
      expect(line.split('・').length, mainAbilitiesOf(role).length);
    }
  });
}
