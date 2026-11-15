// ignore_for_file: avoid_print
/// **後半、何を練習するかで、何が残るか。**
///
/// 衰えは走力と身体から来て、練習しているカテゴリには当たらない
/// （2026-11-15）。同じ CM を練習メニューだけ変えて回し、30歳と35歳の
/// 総合力・走力・パスを並べる。手動実行（CI では走らない）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/season.dart';
import 'package:soccer_career/models/training.dart';

import 'support/career_sim.dart';

void main() {
  test('protect', () async {
    const n = int.fromEnvironment('N', defaultValue: 24);
    print('練習          30歳 総合/走力/パス     35歳 総合/走力/パス     落ち幅 総合/走力/パス');
    for (final (name, menu) in [
      ('ふだん', null),
      ('走力と身体', TrainingMenu.athletic),
      ('パス', TrainingMenu.passingWork),
    ]) {
      final at = <int, List<double>>{30: [0, 0, 0, 0], 35: [0, 0, 0, 0]};
      for (var seed = 0; seed < n; seed++) {
        await runCareer(
          Playstyle(
            name: name,
            position: Position.cm,
            startAge: 18,
            sim: SimStyle.balanced,
            agent: Agent.pool.first,
            menu: menu,
          ),
          seed,
          onSeason: (state, stats, c) {
            final age = state.player.age;
            final row = at[age];
            if (row == null) return;
            final a = state.player.attributes;
            row[0] += state.player.overall;
            row[1] += a[AttributeKey.pace];
            row[2] += a[AttributeKey.passing];
            row[3] += 1;
          },
        );
      }
      String fmt(List<double> r) => r[3] == 0
          ? '-'
          : '${(r[0] / r[3]).toStringAsFixed(1)}/${(r[1] / r[3]).toStringAsFixed(1)}/${(r[2] / r[3]).toStringAsFixed(1)}';
      String drop(int i) => at[30]![3] == 0 || at[35]![3] == 0
          ? '-'
          : (at[35]![i] / at[35]![3] - at[30]![i] / at[30]![3]).toStringAsFixed(1);
      print(
        '${name.padRight(10)}  ${fmt(at[30]!).padRight(20)}  ${fmt(at[35]!).padRight(20)}  '
        '${drop(0)}/${drop(1)}/${drop(2)}',
      );
    }
  }, timeout: const Timeout(Duration(minutes: 40)));
}
