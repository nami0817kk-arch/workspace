// ignore_for_file: avoid_print
/// **復帰の進め方に、選ぶだけの差があるか。**
///
/// `flutter test test/rehab_sim.dart` で明示的に走らせる。
///
/// 「慎重に」と「標準」は、3度調整しても通算でほとんど並んだままだった
/// （CLAUDE.md の「復帰の進め方は、選べる時点ではもう決まっていた」）。
/// **選ばせている以上は差が要る。** 差が出ない理由を数字で見るための道具。
///
/// 見るのは、その選択が触っている先そのもの——重傷の数・離脱・出場、
/// そして衰えが効いてくる 29歳と引退時の総合力。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/entourage.dart';
import 'package:soccer_career/models/season.dart';

import 'support/career_sim.dart';

void main() {
  test('復帰の進め方', () async {
    const seeds = 48;

    for (final plan in RehabPlan.values) {
      final careers = <Career>[];
      for (var seed = 0; seed < seeds; seed++) {
        careers.add(
          await runCareer(
            Playstyle(
              name: plan.label,
              position: Position.cm,
              startAge: 18,
              sim: SimStyle.balanced,
              agent: Agent.pool[0],
              rehab: plan,
            ),
            // **種は3つで揃える。** 揃えないと、比べているのが
            // 戻し方なのか引きの良さなのか分からない。
            seed,
          ),
        );
      }
      report(plan.label, careers);
    }
  }, timeout: const Timeout(Duration(minutes: 30)));
}
