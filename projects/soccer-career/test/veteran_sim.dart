// ignore_for_file: avoid_print
/// **後半15年は本当に虚無か。**
///
/// 22歳で能力が伸び止まったあと、引退までの週に何が起きているかを測る。
/// 手動実行（`_test.dart` で終わらないので CI では走らない）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/season.dart';
import 'package:soccer_career/models/training.dart';

import 'support/career_sim.dart';

int _sum(Attributes a) {
  var total = 0;
  for (final d in Detail.values) {
    total += a.detail(d);
  }
  return total;
}

void main() {
  test('veteran', () async {
    const n = 24;
    // 歳ごとの「週の数」と「詳細能力の合計が動いた週の数」。
    final weeks = <int, int>{};
    final up = <int, int>{};
    final down = <int, int>{};
    final overall = <int, int>{};
    final seen = <int, int>{};
    final polish = <int, int>{};
    var totalMastery = 0;

    for (var seed = 0; seed < n; seed++) {
      var last = -1;
      var lastMastery = -1;
      await runCareer(
        Playstyle(
          name: 'cm',
          position: Position.cm,
          startAge: 17,
          sim: SimStyle.balanced,
          agent: Agent.pool[0],
          effort: TrainingEffort.hard,
        ),
        seed,
        onWeek: (age, attributes, ovr, mastery) {
          if (lastMastery >= 0 && mastery > lastMastery) {
            polish[age] = (polish[age] ?? 0) + 1;
          }
          lastMastery = mastery;
          weeks[age] = (weeks[age] ?? 0) + 1;
          final now = _sum(attributes);
          // **上がった週と下がった週を分けて数える。**
          // 合計が「動いた」で数えたら、衰え始める29歳から数字が戻って
          // 見えた——下がった週まで「伸びた」に入っていた。
          if (last >= 0 && now > last) up[age] = (up[age] ?? 0) + 1;
          if (last >= 0 && now < last) down[age] = (down[age] ?? 0) + 1;
          last = now;
          overall[age] = (overall[age] ?? 0) + ovr;
          seen[age] = (seen[age] ?? 0) + 1;
        },
      );
      totalMastery += lastMastery < 0 ? 0 : lastMastery;
    }

    print('引退時の磨き合計 平均 ${(totalMastery / n).toStringAsFixed(2)} / 15');
    print('歳  週数   伸びた  割合    磨いた  何かあった週  総合力');
    for (final age in weeks.keys.toList()..sort()) {
      final w = weeks[age]!;
      final u = up[age] ?? 0;
      final o = (overall[age]! / seen[age]!).toStringAsFixed(1);
      final pol = polish[age] ?? 0;
      print(
        '$age  ${w.toString().padLeft(4)}  ${u.toString().padLeft(5)}  '
        '${(u / w * 100).toStringAsFixed(1).padLeft(5)}%  '
        '${pol.toString().padLeft(5)}   '
        '${((u + pol) / w * 100).toStringAsFixed(1).padLeft(5)}%       $o',
      );
    }
  }, timeout: const Timeout(Duration(minutes: 30)));
}
