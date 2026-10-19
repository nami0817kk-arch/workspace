// ignore_for_file: avoid_print
// 出来事の選択肢を比べて、ほぼ一方が有利(選ぶ意味が薄い)なものを探す。
import 'dart:math';
import 'package:baseball_manager/game/life.dart';
import 'package:baseball_manager/game/player.dart';

void main() {
  final p = Player(name: 't', role: Role.batter, age: 20, potential: 50, abilities: {for (final a in batterAbilities) a: 50});
  const c = Condition(fatigue: 50, morale: 50);
  for (final e in events) {
    final rows = <String>[];
    final scores = <List<double>>[];
    for (final ch in e.choices) {
      var ab = 0.0, fa = 0.0, mo = 0.0;
      const n = 200;
      for (var i = 0; i < n; i++) {
        final r = ch.risky != null ? ch.risky!(p, c, Ability.contact, Random(i)) : ch.apply(p, c, Ability.contact);
        ab += abilitiesOf(Role.batter).fold<int>(0, (s, a) => s + r.player.of(a) - 50);
        fa += r.condition.fatigue - 50;
        mo += r.condition.morale - 50;
      }
      scores.add([ab / n, -fa / n, mo / n]);
      rows.add('${ch.label}: 能力${(ab / n).toStringAsFixed(1)} 疲れ${(fa / n).toStringAsFixed(1)} やる気${(mo / n).toStringAsFixed(1)}');
    }
    var dom = false;
    for (var i = 0; i < scores.length; i++) {
      for (var j = 0; j < scores.length; j++) {
        if (i == j) continue;
        final better = [for (var k = 0; k < 3; k++) scores[i][k] >= scores[j][k] - 1e-9].every((x) => x);
        final strictly = [for (var k = 0; k < 3; k++) scores[i][k] > scores[j][k] + 1e-9].any((x) => x);
        if (better && strictly) dom = true;
      }
    }
    print('${dom ? '!! ' : '   '}${e.id}  ${rows.join(' | ')}');
  }
}
