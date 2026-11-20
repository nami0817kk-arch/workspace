import 'dart:math';

import 'package:baseball_manager/game/career.dart';
import 'package:baseball_manager/game/game.dart';
import 'package:baseball_manager/game/life.dart';
import 'package:baseball_manager/game/path.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:flutter_test/flutter_test.dart';

final _duel = RegExp(r'との直接対決|対決を制し|火花を散らし|意地を見せられ');

void main() {
  test('二軍の年は、一軍のライバルとの「直接対決」を出さない(2026-11-03)', () {
    var farmTurns = 0;
    for (var seed = 0; seed < 60 && farmTurns < 30; seed++) {
      final g = Game.newGame(
          name: 'テスト', role: Role.values[seed % 3], rng: Random(seed));
      var n = 0;
      while (g.phase != Phase.retired && n++ < 3000) {
        g.autoSpend();
        final before = g.log.length;
        final farm = g.stage == Stage.pro && g.onFarm;
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
        if (farm && g.stage == Stage.pro && g.onFarm) {
          farmTurns++;
          final added = g.log.skip(before).where(_duel.hasMatch).toList();
          expect(added, isEmpty, reason: 'seed $seed: ${added.join(' / ')}');
        }
      }
    }
    expect(farmTurns, greaterThan(0), reason: '二軍の年に一度も当たらなかった');
  });
}
