import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quadrillion/game/game.dart';
import 'package:quadrillion/ui/app.dart';
import 'package:quadrillion/ui/controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../support/bot.dart';

void main() {
  testWidgets('prof2', (tester) async {
    final g = Game.newGame(SetupConfig(mode: 'endless', year: 2000, traits: ['charm', 'gambler']), rng: ParkMiller(2024));
    for (var i = 0; i < 120; i++) { botMonth(g); }
    resolveEvents(g);
    g.calcAll();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final ctl = GameController(prefs: prefs, newRandom: () => ParkMiller(77));
    ctl.game = g;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(QuadrillionApp(controller: ctl));
    await tester.pump();
    for (final t in ['town', 'biz', 'people', 'stock', 'num', 'zukan', 'town']) {
      ctl.setTab(t);
      await tester.pump();
      final sw = Stopwatch()..start();
      for (var i = 0; i < 20; i++) { ctl.render(); await tester.pump(); }
      print('$t ${(sw.elapsedMicroseconds / 20 / 1000).toStringAsFixed(2)}ms');
    }
    final sw = Stopwatch()..start();
    for (var i = 0; i < 20; i++) { await tester.pump(); }
    print('empty pump ${(sw.elapsedMicroseconds / 20 / 1000).toStringAsFixed(2)}ms');
  });
}
