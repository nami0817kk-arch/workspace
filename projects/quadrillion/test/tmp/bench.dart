import 'dart:convert';
import 'package:quadrillion/game/game.dart';
import '../support/bot.dart';

void main() {
  for (final c in [(2000, 120), (2025, 420)]) {
    final g = Game.newGame(SetupConfig(mode: 'endless', year: c.$1, traits: ['charm', 'gambler']), rng: ParkMiller(2024));
    for (var i = 0; i < c.$2; i++) { botMonth(g); }
    resolveEvents(g);
    g.calcAll();
    for (var i = 0; i < 10; i++) { resolveEvents(g); g.nextQuarter(); jsonEncode(g.toJson()); }
    var turn = 0, save = 0;
    final sw = Stopwatch();
    for (var i = 0; i < 100; i++) {
      resolveEvents(g);
      sw..reset()..start();
      g.nextQuarter();
      turn += sw.elapsedMicroseconds;
      sw..reset()..start();
      jsonEncode(g.toJson());
      save += sw.elapsedMicroseconds;
    }
    print('${c.$1}+${c.$2}: ${g.year} turn ${(turn/100000).toStringAsFixed(2)}ms save ${(save/100000).toStringAsFixed(2)}ms');
  }
}
