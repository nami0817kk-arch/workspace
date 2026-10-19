import 'dart:convert';
import 'dart:math';

import 'package:baseball_manager/game/career.dart';
import 'package:baseball_manager/game/game.dart';
import 'package:baseball_manager/game/life.dart';
import 'package:baseball_manager/game/path.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:baseball_manager/ui/controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 画面から呼ぶ入口(行動・出来事・おすすめで進める・ひとつ前に戻す・進路)を
/// ランダムに混ぜて遊ばせても、状態が壊れず、保存を読み直しても同じになる。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('操作と「戻す」を混ぜても、毎回セーブが読み直せて同じ状態になる', () async {
    for (var seed = 0; seed < 25; seed++) {
      SharedPreferences.setMockInitialValues({});
      final r = Random(seed);
      final c = GameController(rng: Random(seed));
      c.newGame('f$seed', r.nextBool() ? Role.batter : Role.pitcher);
      var steps = 0;
      while (c.game != null && c.game!.phase != Phase.retired) {
        if (++steps > 3000) fail('終わらない seed=$seed');
        final g = c.game!;
        c.pending.clear();
        final roll = r.nextInt(10);
        if (roll == 0 && c.canUndo) {
          c.undo();
        } else {
          switch (g.phase) {
            case Phase.term:
              if (g.stage == Stage.pro && g.player.age >= 36) {
                c.giveUp();
              } else if (roll == 1) {
                c.autoYear();
              } else {
                final ab = abilitiesOf(g.player.role);
                c.focus = ab[r.nextInt(ab.length)];
                c.act(Plan.values[r.nextInt(Plan.values.length)]);
              }
            case Phase.event:
              c.chooseEvent(r.nextInt(g.pendingEvent!.choices.length));
            case Phase.pathChoice:
              c.chooseRoute(
                  r.nextBool() ? Course.university : Course.corporate);
            case Phase.retired:
              break;
          }
        }
        final now = c.game;
        if (now == null || now.phase == Phase.retired) break;
        final copy = Game.fromJson(
            (jsonDecode(jsonEncode(now.toJson())) as Map).cast(), Random(0));
        expect(jsonEncode(copy.toJson()), jsonEncode(now.toJson()),
            reason: 'seed=$seed step=$steps');
        for (final a in abilitiesOf(now.player.role)) {
          expect(now.player.of(a), inInclusiveRange(0, 99), reason: '$seed');
        }
        expect(now.condition.fatigue, inInclusiveRange(0, 100));
        expect(now.condition.morale, inInclusiveRange(0, 100));
      }
    }
  });
}
