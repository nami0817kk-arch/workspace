// ignore_for_file: avoid_print
/// **「起用の約束」は守られるか。**
///
/// `flutter test test/promise_role_sim.dart` で明示的に走らせる。
///
/// 移籍先を選ぶときに出ている材料は、年俸・移籍金・契約年数と
/// **「起用の約束」（`_roleFor`）**だけ。約束が当たらないなら、
/// このゲームで一番大きな判断を材料なしでやっていることになる。
///
/// 約束（移籍した季の開幕時点の文言）と、その季に実際どれだけ出たかを並べる。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/game/formulas.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/season.dart';

import 'support/career_sim.dart';

/// `_roleFor` と同じ式。エンジンに穴を開けずに、同じ言葉を引き直す。
String _roleFor(int overall, int strength) {
  final gap = overall - strength;
  if (gap >= 5) return '絶対的な主力';
  if (gap >= -3) return '主力';
  if (gap >= -10) return 'ローテーション';
  return '控え';
}

void main() {
  test('約束と、実際の出場', () async {
    const seeds = 40;

    // 約束 -> [季の数, 出場数の合計, 先発の合計, 無出場だった季]
    // 値は全部 int で持つ（平均は出すときに割る）。
    final byRole = <String, List<int>>{};

    for (final position in [Position.st, Position.cm, Position.cb]) {
      for (var seed = 0; seed < seeds; seed++) {
        await runCareer(
          Playstyle(
            name: '約束',
            position: position,
            startAge: 18,
            sim: SimStyle.balanced,
            agent: Agent.pool.first,
          ),
          seed,
          onSeason: (state, stats, c) {
            // 季の終わりに、その季の開幕時点の力関係で約束を引き直す。
            final role = _roleFor(state.player.overall, state.club.strength);
            final row = byRole.putIfAbsent(role, () => [0, 0, 0, 0]);
            row[0]++;
            row[1] += stats.appearances;
            row[2] += state.leagueResults
                .where((r) => r.appearance == Appearance.start)
                .length;
            if (stats.appearances == 0) row[3]++;
          },
        );
      }
    }

    const order = ['絶対的な主力', '主力', 'ローテーション', '控え'];
    for (final role in order) {
      final row = byRole[role];
      if (row == null) continue;
      final seasons = row[0];
      print(
        '${role.padRight(8)} $seasons季  '
        '出場 ${(row[1] / seasons).toStringAsFixed(1)}/'
        '${Formulas.matchesPerSeason}  '
        '先発 ${(row[2] / seasons).toStringAsFixed(1)}  '
        '無出場の季 ${(row[3] / seasons * 100).toStringAsFixed(1)}%',
      );
    }
  }, timeout: const Timeout(Duration(minutes: 60)));
}
