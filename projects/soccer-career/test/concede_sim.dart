// ignore_for_file: avoid_print
/// **外した手が失点を呼ぶようになって、失点の総量が動いていないか。**
///
/// 手を外すと失点することがある（`Exposure`）。足したぶんを放っておくと、
/// 守る選手のクラブだけ毎試合失点が増え、勝てなくなる。
/// ポジションごとに、出た試合と出なかった試合の失点・無失点の割合・
/// 評価・優勝を並べ、master と見比べる。手動実行。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/season.dart';

import 'support/career_sim.dart';

void main() {
  test('concede', () async {
    const n = int.fromEnvironment('N', defaultValue: 24);
    const only = String.fromEnvironment('POS', defaultValue: 'gk,cb,sb,dm,cm,st');
    print('ポジション  出た試合の失点  無失点  出ない試合の失点  評価   優勝   ピーク');
    for (final position in Position.values) {
      if (!only.split(',').contains(position.name)) continue;
      var played = 0, playedConceded = 0, cleanSheets = 0;
      var absent = 0, absentConceded = 0;
      var rating = 0.0, peak = 0.0;
      var league = 0;
      for (var seed = 0; seed < n; seed++) {
        final c = await runCareer(
          Playstyle(
            name: position.name,
            position: position,
            startAge: 18,
            sim: SimStyle.balanced,
            agent: Agent.pool.first,
          ),
          seed,
          onSeason: (state, stats, controller) {
            if (state.leaguePosition == 1 && state.club.tier == 1) league++;
            for (final r in state.leagueResults) {
              if (r.appearance.played) {
                played++;
                playedConceded += r.conceded;
                if (r.conceded == 0) cleanSheets++;
              } else {
                absent++;
                absentConceded += r.conceded;
              }
            }
          },
        );
        rating += c.averageRating;
        peak += c.peakOverall;
      }
      print(
        '${position.name.padRight(10)} '
        '${(playedConceded / played).toStringAsFixed(3).padLeft(12)}  '
        '${(cleanSheets / played * 100).toStringAsFixed(1).padLeft(5)}%  '
        '${(absentConceded / (absent == 0 ? 1 : absent)).toStringAsFixed(3).padLeft(14)}  '
        '${(rating / n).toStringAsFixed(2)}  '
        '${(league / n).toStringAsFixed(2).padLeft(5)}  '
        '${(peak / n).toStringAsFixed(1)}',
      );
    }
  }, timeout: const Timeout(Duration(minutes: 40)));
}
