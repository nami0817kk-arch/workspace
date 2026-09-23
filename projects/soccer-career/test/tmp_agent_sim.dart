// ignore_for_file: avoid_print
/// **代理人を選ぶことに意味はあるか。**
///
/// 6人のプールから3人引いて選ばせているのに、単独で比べた計測が無かった。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/season.dart';

import 'support/career_sim.dart';

double _avg(Iterable<num> xs) =>
    xs.isEmpty ? 0 : xs.fold<double>(0, (a, b) => a + b) / xs.length;

void main() {
  test('代理人ごとの効き', () async {
    print('代理人 | 交渉 | 人脈 | 手数料 | ピーク | 届いた話 | 1部の話'
        ' | 格 | 最高年俸 | 貯蓄 | 優勝');
    for (final a in Agent.pool) {
      final cs = <Career>[];
      for (var seed = 0; seed < 12; seed++) {
        cs.add(
          await runCareer(
            Playstyle(
              name: a.name,
              position: Position.cm,
              startAge: 18,
              sim: SimStyle.balanced,
              agent: a,
            ),
            seed,
          ),
        );
      }
      print(
        '${a.style} | ${a.negotiation} | ${a.reach} | ${a.feePercent}%'
        ' | ${_avg(cs.map((c) => c.peakOverall)).toStringAsFixed(1)}'
        ' | ${_avg(cs.map((c) => c.offersSeen)).toStringAsFixed(1)}'
        ' | ${_avg(cs.map((c) => c.topTierOffers)).toStringAsFixed(1)}'
        ' | ${_avg(cs.map((c) => c.bestPrestige)).toStringAsFixed(2)}'
        ' | ${_avg(cs.map((c) => c.peakSalary)).toStringAsFixed(0)}'
        ' | ${_avg(cs.map((c) => c.savings)).toStringAsFixed(0)}'
        ' | ${_avg(cs.map((c) => c.leagueTitles)).toStringAsFixed(1)}',
      );
    }
  }, timeout: const Timeout(Duration(minutes: 60)));
}
