// ignore_for_file: avoid_print
/// **試合の中に、忘れられない1試合があるか。**
///
/// 「ハットトリックとかもあるはずができない」への手がかり。
/// 通算ゴールが同じでも、毎試合0.5点と「たまに3点」はまるで違う試合になる。
/// 1試合の最多得点・2点以上・3点以上の回数を、ポジションごとに測る。
///
/// `flutter test test/flow_sim.dart` で明示的に走らせる。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/season.dart';

import 'support/career_sim.dart';

void main() {
  test('1試合に何点まで取れるか', () async {
    const seeds = 16;

    Future<void> run(String name, Position position) async {
      var goals = 0.0;
      var apps = 0.0;
      var braces = 0.0;
      var hats = 0.0;
      var best = 0.0;
      var bestEver = 0;

      for (var seed = 0; seed < seeds; seed++) {
        final career = await runCareer(
          Playstyle(
            name: 'x',
            position: position,
            startAge: 18,
            sim: SimStyle.balanced,
            agent: Agent.pool.first,
          ),
          seed,
        );
        goals += career.goals;
        apps += career.appearances;
        braces += career.braces;
        hats += career.hatTricks;
        best += career.bestMatchGoals;
        if (career.bestMatchGoals > bestEver) bestEver = career.bestMatchGoals;
      }

      print(
        '${name.padRight(10)} '
        '通算ゴール ${(goals / seeds).toStringAsFixed(0)}  '
        '出場 ${(apps / seeds).toStringAsFixed(0)}  '
        '2点以上 ${(braces / seeds).toStringAsFixed(1)}回  '
        '**ハットトリック ${(hats / seeds).toStringAsFixed(2)}回**  '
        '1試合最多 ${(best / seeds).toStringAsFixed(1)}（最大 $bestEver）',
      );
    }

    print('--- キャリアを通して（$seeds キャリア）---');
    await run('ST', Position.st);
    await run('WG', Position.wg);
    await run('CM', Position.cm);
    await run('CB', Position.cb);
  }, timeout: const Timeout(Duration(minutes: 60)));
}
