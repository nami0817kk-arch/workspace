// ignore_for_file: avoid_print
/// **強い選手と弱い選手が、どれだけ分かれているか。**
///
/// 「もっと明確に強い選手と弱い選手を分けたい」への手がかり。
/// 引退までのピーク総合力を並べて、**どれだけ散っているか**と、
/// **何がその幅を決めているか**（ポテンシャルか、そこへの到達か）を見る。
///
/// `flutter test test/spread_sim.dart` で明示的に走らせる。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/season.dart';

import 'support/career_sim.dart';

void main() {
  test('ピークはどれだけ散るか', () async {
    const seeds = 120;
    final careers = <Career>[];

    for (var seed = 0; seed < seeds; seed++) {
      careers.add(
        await runCareer(
          Playstyle(
            name: 'x',
            position: Position.cm,
            startAge: 18,
            sim: SimStyle.balanced,
            agent: Agent.pool.first,
          ),
          seed,
        ),
      );
    }

    List<int> sorted(int Function(Career) of) =>
        careers.map(of).toList()..sort();
    int at(List<int> values, double q) =>
        values[(values.length * q).clamp(0, values.length - 1).toInt()];

    void show(String name, int Function(Career) of) {
      final values = sorted(of);
      final mean = values.reduce((a, b) => a + b) / values.length;
      print(
        '${name.padRight(14)} '
        '平均 ${mean.toStringAsFixed(1)}  '
        '最低 ${values.first}  '
        '下位1割 ${at(values, 0.1)}  '
        '中央 ${at(values, 0.5)}  '
        '上位1割 ${at(values, 0.9)}  '
        '最高 ${values.last}  '
        '**幅 ${at(values, 0.9) - at(values, 0.1)}**',
      );
    }

    print('--- $seeds キャリア（CM・自動進行）---');
    show('開始の総合力', (c) => c.startOverall);
    show('ポテンシャル', (c) => c.potential);
    show('ピーク総合力', (c) => c.peakOverall);
    show('引退時', (c) => c.finalOverall);

    // ポテンシャルへの到達。上のほうほど届いていないなら、
    // ポテンシャルを広げてもピークは広がらない。
    print('');
    final byPotential = <String, List<Career>>{};
    for (final c in careers) {
      final band = c.potential < 78
          ? '〜77'
          : c.potential < 84
          ? '78〜83'
          : c.potential < 90
          ? '84〜89'
          : '90〜';
      byPotential.putIfAbsent(band, () => []).add(c);
    }
    print('ポテンシャルの帯ごとに、どこまで届いたか:');
    for (final band in ['〜77', '78〜83', '84〜89', '90〜']) {
      final group = byPotential[band];
      if (group == null || group.isEmpty) continue;
      double avg(num Function(Career) of) =>
          group.fold<double>(0, (s, c) => s + of(c)) / group.length;
      print(
        '  $band ${group.length.toString().padLeft(3)}人  '
        'ポテンシャル ${avg((c) => c.potential).toStringAsFixed(1)}  '
        'ピーク ${avg((c) => c.peakOverall).toStringAsFixed(1)}  '
        '**残し ${(avg((c) => c.potential) - avg((c) => c.peakOverall)).toStringAsFixed(1)}**  '
        '評価 ${avg((c) => c.averageRating).toStringAsFixed(2)}  '
        '代表 ${avg((c) => c.caps).toStringAsFixed(0)}',
      );
    }
  }, timeout: const Timeout(Duration(minutes: 60)));
}
