// ignore_for_file: avoid_print
/// **ポジションで得をしていないか。** 同じ設定（18歳・バランス・同じ代理人）で
/// 8つのポジションを回し、ピーク・評価・代表・タイトル・クラブの強さを並べる。
///
/// balance_sim は遊び方ごとに開始年齢も自動進行も違うので、ポジションの差と
/// 遊び方の差が混ざる。ここでは他を全部揃える。手動実行。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/competition.dart';
import 'package:soccer_career/models/season.dart';

import 'support/career_sim.dart';

void main() {
  test('positions', () async {
    const n = int.fromEnvironment('N', defaultValue: 32);
    print('ポジション  ピーク  評価   代表   リーグ優勝  カップ  クラブ強さ(25-30)  差(総合力-強さ)  ゴール');
    const only = String.fromEnvironment('POS');
    for (final position in Position.values) {
      if (only.isNotEmpty && !only.split(',').contains(position.name)) continue;
      var peak = 0.0, rating = 0.0, caps = 0.0, goals = 0.0;
      var league = 0, cups = 0;
      var strength = 0.0, gap = 0.0, primeSeasons = 0;
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
            if (state.cupStage == CupStage.winner) cups++;
            final age = state.player.age;
            if (age >= 25 && age <= 30) {
              strength += state.club.strength;
              gap += state.player.overall - state.club.strength;
              primeSeasons++;
            }
          },
        );
        peak += c.peakOverall;
        rating += c.averageRating;
        caps += c.caps;
        goals += c.goals;
      }
      print(
        '${position.name.padRight(10)} ${(peak / n).toStringAsFixed(1)}  '
        '${(rating / n).toStringAsFixed(2)}  ${(caps / n).toStringAsFixed(1).padLeft(5)}  '
        '${(league / n).toStringAsFixed(2).padLeft(8)}  ${(cups / n).toStringAsFixed(2).padLeft(5)}  '
        '${(strength / primeSeasons).toStringAsFixed(1).padLeft(10)}  '
        '${(gap / primeSeasons).toStringAsFixed(1).padLeft(10)}  ${(goals / n).toStringAsFixed(0)}',
      );
    }
  }, timeout: const Timeout(Duration(minutes: 40)));
}
