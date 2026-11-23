import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quadrillion/game/game.dart';
import 'package:quadrillion/ui/app.dart';
import 'package:quadrillion/ui/controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/bot.dart';

/// 月を進める速さの目安（9回目の改善で測った）。
/// 2000年と2060年の局面、自動プレイで育てた大きな会社で、100か月ぶんの
/// 「nextQuarter（月を進める処理）」「保存」「画面の描き直し」の平均を測る。
/// CI は手元より遅いので、ここでは大きく外れたとき（1か月 250ms 超え）だけ落とす。
/// QUAD_SPEED=1 を渡すと、測った数字を出す。
final _print = Platform.environment['QUAD_SPEED'] != null;

/// 自動プレイで [months] か月育てた会社
Game _grown(int year, int months, {int seed = 2024}) {
  final g = Game.newGame(SetupConfig(mode: 'endless', year: year, traits: ['charm', 'gambler']), rng: ParkMiller(seed));
  for (var i = 0; i < months; i++) {
    botMonth(g);
  }
  resolveEvents(g);
  g.calcAll();
  return g;
}

void main() {
  final cases = <(String, int, int)>[
    ('2000年（10年育てた会社）', 2000, 120),
    ('2060年（2025年から35年育てた大きな会社）', 2025, 420),
  ];
  for (final c in cases) {
    testWidgets('月を進める速さ：${c.$1}', (tester) async {
      final g = _grown(c.$2, c.$3);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final ctl = GameController(prefs: prefs, newRandom: () => ParkMiller(77));
      ctl.game = g;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(QuadrillionApp(controller: ctl));
      await tester.pump();
      const n = 100;
      var turn = 0, save = 0, draw = 0;
      final sw = Stopwatch();
      for (var i = 0; i < n; i++) {
        resolveEvents(g);
        sw
          ..reset()
          ..start();
        g.nextQuarter();
        turn += sw.elapsedMicroseconds;
        sw
          ..reset()
          ..start();
        ctl.save();
        save += sw.elapsedMicroseconds;
        sw
          ..reset()
          ..start();
        ctl.render();
        await tester.pump();
        draw += sw.elapsedMicroseconds;
      }
      double ms(int us) => us / n / 1000;
      final total = ms(turn + save + draw);
      if (_print) {
        // ignore: avoid_print
        print('[speed] ${c.$1} ${g.year}年${g.q}月 事業${g.biz.length} 会社${g.cos.length}: '
            '月を進める ${ms(turn).toStringAsFixed(2)}ms・保存 ${ms(save).toStringAsFixed(2)}ms・'
            '描き直し ${ms(draw).toStringAsFixed(2)}ms・計 ${total.toStringAsFixed(2)}ms');
      }
      expect(total, lessThan(250));
      expect(tester.takeException(), isNull);
    });
  }
}
