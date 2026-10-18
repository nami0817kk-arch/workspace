// ignore_for_file: avoid_print
import 'dart:math';
import 'package:baseball_manager/game/at_bat.dart';

void main() {
  final rng = Random(1);
  void pit(int s, int c, int opp) {
    var h = 0, k = 0, w = 0, n = 20000;
    for (var i = 0; i < n; i++) {
      final r = simulateAtBat(Pitcher(control: c, stuff: s),
          Batter(contact: opp, power: opp, eye: opp), rng);
      if (r == AtBatResult.strikeout) {
        k++;
      } else if (r == AtBatResult.walk) {
        w++;
      } else if (r != AtBatResult.out) {
        h++;
      }
    }
    print(
        'P stuff$s ctl$c vs $opp: K ${(k / n * 100).toStringAsFixed(1)}% BB ${(w / n * 100).toStringAsFixed(1)}% H ${(h / n * 100).toStringAsFixed(1)}%');
  }

  for (final (s, o) in [
    (50, 50),
    (90, 30),
    (70, 30),
    (90, 60),
    (90, 80),
    (30, 50)
  ]) {
    pit(s, s, o);
  }
}
