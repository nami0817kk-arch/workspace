import 'dart:convert';
import 'package:quadrillion/game/game.dart';
import '../support/bot.dart';

void main() {
  final g = Game.newGame(SetupConfig(mode: 'endless', year: 2025, traits: ['charm', 'gambler']), rng: ParkMiller(2024));
  for (var i = 0; i < 420; i++) { botMonth(g); }
  resolveEvents(g);
  g.calcAll();
  final j = g.toJson();
  void t(String n, void Function() f) {
    for (var i = 0; i < 5; i++) { f(); }
    final sw = Stopwatch()..start();
    for (var i = 0; i < 30; i++) { f(); }
    print('$n ${(sw.elapsedMicroseconds / 30000).toStringAsFixed(2)}ms');
  }
  t('toJson', g.toJson);
  t('encode all', () => jsonEncode(j));
  final cos = j['cos'] as List;
  t('encode cos', () => jsonEncode(cos));
  final noHist = [for (final c in cos) Map.of(c as Map)..remove('revHist')];
  t('encode cos w/o revHist', () => jsonEncode(noHist));
  final ds = <double>[for (final c in cos) ...((c as Map)['revHist'] as List).cast<double>()];
  print('revHist doubles ${ds.length}');
  t('encode revHist doubles', () => jsonEncode(ds));
  t('toString revHist doubles', () { for (final d in ds) { d.toString(); } });
  final strs = [for (final d in ds) d.toString()];
  t('encode same as strings', () => jsonEncode(strs));
  t('utf8 of json', () => utf8.encode(jsonEncode(j)));
}
