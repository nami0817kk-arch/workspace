// ignore_for_file: avoid_print
/// **9つの挑戦は、実際に届くか。**
///
/// `flutter test test/challenge_sim.dart` で明示的に走らせる。
///
/// 挑戦は「違う形のキャリアでしか達成できないもの」として並べてある。
/// だが**どう遊んでも届かない**ものがあれば、それは並べてあるだけの飾りで、
/// **普通に遊ぶだけで全部埋まる**なら、違う形で遊ぶ理由にならない。
/// 宣言の上乗せ（`declaredBonus`）は一度きりの仮設スクリプトで測った値なので、
/// ここで測り直して残す。
///
/// 遊び方を変えて回す:
/// - 普通（何も狙わない）
/// - 動かない（`staysPut`: 同じクラブに留まる）
/// - 遅咲き（19歳開始・流す）
/// - 点取り屋（ST・シュート重点）
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/challenge.dart';
import 'package:soccer_career/models/season.dart';
import 'package:soccer_career/models/training.dart';

import 'support/career_sim.dart';

void main() {
  test('挑戦の到達率', () async {
    const seeds = 30;

    final total = <Challenge, int>{};
    var careers = 0;

    Future<void> run(String name, Playstyle Function(Position) style) async {
      final cleared = <Challenge, int>{};
      var n = 0;
      for (final position in [Position.st, Position.cm, Position.cb]) {
        for (var seed = 0; seed < seeds; seed++) {
          final c = await runCareer(style(position), seed);
          n++;
          careers++;
          for (final challenge in c.challenges) {
            cleared[challenge] = (cleared[challenge] ?? 0) + 1;
            total[challenge] = (total[challenge] ?? 0) + 1;
          }
        }
      }
      final parts = Challenge.values.map((ch) {
        final rate = (cleared[ch] ?? 0) / n * 100;
        return '${ch.label} ${rate.toStringAsFixed(0)}%';
      });
      print('${name.padRight(10)} ${parts.join('  ')}');
    }

    await run(
      '普通',
      (p) => Playstyle(
        name: '普通',
        position: p,
        startAge: 18,
        sim: SimStyle.balanced,
        agent: Agent.pool.first,
      ),
    );
    await run(
      '動かない',
      (p) => Playstyle(
        name: '動かない',
        position: p,
        startAge: 18,
        sim: SimStyle.balanced,
        agent: Agent.pool.first,
        staysPut: true,
      ),
    );
    await run(
      '遅咲き',
      (p) => Playstyle(
        name: '遅咲き',
        position: p,
        startAge: 19,
        sim: SimStyle.safe,
        agent: Agent.pool.first,
        effort: TrainingEffort.easy,
      ),
    );
    await run(
      '攻めきる',
      (p) => Playstyle(
        name: '攻めきる',
        position: p,
        startAge: 18,
        sim: SimStyle.aggressive,
        agent: Agent.pool.last,
      ),
    );

    print('');
    print('== 全部まとめて（$careers キャリア）==');
    for (final ch in Challenge.values) {
      final rate = (total[ch] ?? 0) / careers * 100;
      print(
        '${ch.label.padRight(8)} ${rate.toStringAsFixed(1).padLeft(5)}%  '
        '宣言の上乗せ ${ch.declaredBonus}pt  ${ch.requirement}',
      );
    }
  }, timeout: const Timeout(Duration(minutes: 90)));
}
