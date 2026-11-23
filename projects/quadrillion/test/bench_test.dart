import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quadrillion/game/game.dart';
import 'package:quadrillion/ui/app.dart';
import 'package:quadrillion/ui/controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/bot.dart';

/// 月を進める速さを測る（手元で見るためのもの。QUAD_BENCH を渡したときだけ動く）。
///   QUAD_BENCH=1 flutter test test/bench_test.dart
/// 1980年から自動で回して大きくした会社で、2000年と2060年の局面から100か月ぶんを測り、
/// 1か月あたりの「仕組み（nextQuarter）」「保存」「画面の描き直し」の平均を出す。
final _on = Platform.environment['QUAD_BENCH'] != null;

void main() {
  for (final c in const [('2000年', 240), ('2060年', 960)]) {
    testWidgets('月を進める速さ（${c.$1}の局面・100か月平均）', (tester) async {
      final g = Game.newGame(SetupConfig(mode: 'endless', year: 1980, traits: ['charm', 'gambler']), rng: ParkMiller(2024));
      for (var i = 0; i < c.$2 && g.over == null; i++) {
        botMonth(g);
      }
      resolveEvents(g);
      g.calcAll();
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final ctl = GameController(prefs: prefs, newRandom: () => ParkMiller(77), lang: 'ja')..game = g;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(QuadrillionApp(controller: ctl));
      await tester.pump();
      // 1回目は JIT の暖機になるので、10か月ぶん回してから測る
      final next = Stopwatch(), save = Stopwatch(), draw = Stopwatch();
      final tabs = <String, Stopwatch>{for (final t in ['town', 'biz', 'people', 'stock', 'num']) t: Stopwatch()};
      for (var i = 0; i < 110; i++) {
        final on = i >= 10;
        resolveEvents(g);
        if (on) next.start();
        g.nextQuarter();
        next.stop();
        if (on) save.start();
        ctl.save();
        save.stop();
        if (on) draw.start();
        ctl.render();
        await tester.pump();
        draw.stop();
        if (on && i % 10 == 0) {
          for (final e in tabs.entries) {
            ctl.tab = e.key;
            e.value.start();
            ctl.render();
            await tester.pump();
            e.value.stop();
          }
          ctl.tab = 'town';
          ctl.render();
          await tester.pump();
        }
      }
      String ms(Stopwatch w, int n) => (w.elapsedMicroseconds / n / 1000).toStringAsFixed(2);
      // ignore: avoid_print
      print('[bench] ${c.$1}: ${g.year}年${g.q}月 事業${g.biz.length} 子会社${g.subs().length} 会社${g.cos.where((x) => x.alive).length} '
          '部下${g.staff.length} 時価総額${yen(g.cap)} 保存${(prefs.getString(slotKey(1))?.length ?? 0) ~/ 1024}KB\n'
          '[bench]   1か月あたり: 仕組み ${ms(next, 100)}ms・保存 ${ms(save, 100)}ms・描き直し（街） ${ms(draw, 100)}ms\n'
          '[bench]   タブを開く: ${tabs.entries.map((e) => '${e.key} ${ms(e.value, 10)}ms').join('・')}');
    }, skip: !_on, timeout: const Timeout(Duration(minutes: 20)));
  }
}
