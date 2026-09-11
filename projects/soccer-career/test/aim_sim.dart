// ignore_for_file: avoid_print
// 狙った個人技が実際に手に入るかを測る。CI では走らない（_test.dart ではない）。
import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/development.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/season.dart';

import 'support/career_sim.dart';

void main() {
  test('aim', () async {
    const n = 200;
    // ST。focus は longShots / finishing なので、狙わなければ
    // そこに近い技から順に枠が埋まる。
    const arms = <(String, Signature?)>[
      ('狙わない      ', null),
      ('ボレー（focus内）', Signature.volley),
      ('流し込み（focus内）', Signature.placement),
      ('伸びる足（focus外）', Signature.afterburner),
    ];
    for (final (label, target) in arms) {
      var got = 0;
      var owned = 0;
      var empty = 0;
      var totalGoals = 0;
      var peak = 0.0;
      for (var seed = 0; seed < n; seed++) {
        final career = await runCareer(
          Playstyle(
            name: 'st',
            position: Position.st,
            startAge: 17,
            sim: SimStyle.balanced,
            agent: Agent.pool[0],
            focus: const [Detail.longShots, Detail.finishing],
            aim: target,
          ),
          seed,
        );
        if (target != null && career.finalSignatures.contains(target)) got++;
        owned += career.finalSignatures.length;
        if (career.finalSignatures.isEmpty) empty++;
        totalGoals += career.goals;
        peak += career.peakOverall;
      }
      print(
        '$label  狙い取得 ${(got / n * 100).toStringAsFixed(1)}%  '
        '個人技 ${(owned / n).toStringAsFixed(2)}個  '
        '0個 ${(empty / n * 100).toStringAsFixed(1)}%  '
        '通算得点 ${(totalGoals / n).toStringAsFixed(1)}  '
        'ピーク ${(peak / n).toStringAsFixed(1)}',
      );
    }
  }, timeout: const Timeout(Duration(minutes: 40)));
}
