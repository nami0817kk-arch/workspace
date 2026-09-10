// ignore_for_file: avoid_print
/// 自分で振ったときと、自動で振られたときで、成長が釣り合っているか。
///
/// `flutter test test/points_sim.dart` で明示的に走らせる。
///
/// ここがずれていると、切り替えるだけで強く（または弱く）なる。
/// 「自分で選べる」ことの見返りは、伸ばす先が選べることであって、
/// 伸びる量そのものではない。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/season.dart';

import 'support/career_sim.dart';

void main() {
  test('自分で振る／自動で振られる', () async {
    const seeds = 40;

    Future<void> run(String name, {required bool spends}) async {
      var peak = 0.0;
      var rating = 0.0;
      var growth = 0.0;
      for (final position in [Position.cm, Position.st, Position.cb]) {
        for (var seed = 0; seed < seeds; seed++) {
          final c = await runCareer(
            Playstyle(
              name: name,
              position: position,
              startAge: 18,
              sim: SimStyle.balanced,
              agent: Agent.pool.first,
              spendsPoints: spends,
            ),
            seed,
          );
          peak += c.peakOverall;
          rating += c.averageRating;
          growth += c.growth;
        }
      }
      const n = seeds * 3;
      print('${name.padRight(12)} '
          'ピーク ${(peak / n).toStringAsFixed(1)}  '
          '伸び幅 ${(growth / n).toStringAsFixed(1)}  '
          '平均評価 ${(rating / n).toStringAsFixed(2)}');
    }

    await run('自動', spends: false);
    await run('自分で振る', spends: true);
  }, timeout: const Timeout(Duration(minutes: 40)));
}
