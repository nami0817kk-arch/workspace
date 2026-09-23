// ignore_for_file: avoid_print
/// **重い試合は、強くなるほど消えるのか。**
///
/// `flutter test test/weight_sim.dart` で明示的に走らせる。
///
/// 重い試合（`MatchInProgress.bigMatch`）は「代表戦、または相手が8以上格上」。
/// 上のクラブへ行くほど格上の相手は減るので、**強くなるほど全部の試合が
/// 同じ重さになる**おそれがある。1試合の局面数もここで変わるので、
/// 消えると終盤の試合が一律に薄くなる。
///
/// 年齢の帯ごとに、重い試合の割合を測る。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/season.dart';

import 'support/career_sim.dart';

void main() {
  test('重い試合の割合', () async {
    const seeds = 30;

    // 年齢の帯 -> [局面, 重い試合の局面]
    final byAge = <String, List<int>>{};
    // クラブの部 -> [試合数, 重い試合]
    final byTier = <int, List<int>>{};

    String band(int age) {
      if (age < 22) return '〜21';
      if (age < 26) return '22-25';
      if (age < 30) return '26-29';
      if (age < 34) return '30-33';
      return '34〜';
    }

    for (final position in [Position.st, Position.cm, Position.cb]) {
      for (var seed = 0; seed < seeds; seed++) {
        await runCareer(
          Playstyle(
            name: '重さ',
            position: position,
            startAge: 18,
            sim: SimStyle.balanced,
            agent: Agent.pool.first,
          ),
          seed,
          onDecision: (match, option) {
            // **判定と同じ `bigMatch` を、試合の中で数える。**
            // 外から順位表や勝ち上がりを見て引き直すと、判定とずれる。
            final age = band(match.player.age);
            final row = byAge.putIfAbsent(age, () => [0, 0]);
            final tierRow = byTier.putIfAbsent(match.club.tier, () => [0, 0]);
            row[0]++;
            tierRow[0]++;
            if (match.bigMatch) {
              row[1]++;
              tierRow[1]++;
            }
          },
        );
      }
    }

    print('== 年齢の帯ごと ==');
    for (final key in ['〜21', '22-25', '26-29', '30-33', '34〜']) {
      final row = byAge[key];
      if (row == null || row[0] == 0) continue;
      print(
        '${key.padRight(6)} 局面 ${row[0]}  '
        '重い ${(row[1] / row[0] * 100).toStringAsFixed(1)}%',
      );
    }
    print('== 部ごと ==');
    final tiers = byTier.keys.toList()..sort();
    for (final tier in tiers) {
      final row = byTier[tier]!;
      print(
        '$tier部    試合 ${row[0]}  '
        '重い ${(row[1] / row[0] * 100).toStringAsFixed(1)}%',
      );
    }
  }, timeout: const Timeout(Duration(minutes: 60)));
}
