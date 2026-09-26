// ignore_for_file: avoid_print
/// **今節の的は、的になっているか。**
///
/// `flutter test test/target_sim.dart` で明示的に走らせる。
///
/// 入れたきり達成率を測っていない。9割達成なら的ではなく通行料、
/// 1割なら見ても意味が無い添え物になる。ポジションごとに、
/// 3種それぞれの達成率と、シーズンで入る報酬の合計を見る。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/game/match_target.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/season.dart';

import 'support/career_sim.dart';

void main() {
  test('今節の的の達成率', () async {
    const seeds = 30;

    for (final position in [
      Position.st,
      Position.am,
      Position.cm,
      Position.cb,
      Position.gk,
    ]) {
      final played = <String, int>{};
      final met = <String, int>{};
      var rewardSum = 0;
      var salarySum = 0;
      var seasons = 0;
      // キャリアの段ごとの重み。序盤は効いて終盤は消えるのか。
      final byStage = <int, List<int>>{
        0: [0, 0],
        1: [0, 0],
        2: [0, 0],
      };
      var index = 0;
      // 連続達成の分布。出た試合だけで数え、外したら0に戻す。
      var streak = 0;
      var best = 0;
      final runs = <int, int>{};

      for (var seed = 0; seed < seeds; seed++) {
        await runCareer(
          Playstyle(
            name: '的',
            position: position,
            startAge: 18,
            sim: SimStyle.balanced,
            agent: Agent.pool.first,
          ),
          seed,
          onSeason: (state, stats, c) {
            seasons++;
            salarySum += state.salary;
            final stage = index < 3 ? 0 : (index < 8 ? 1 : 2);
            index++;
            var seasonReward = 0;
            for (var i = 0; i < state.leagueResults.length; i++) {
              // その試合のときの節は leagueResults.length + 1 だったので i+1。
              final turn = (i + 1) % 3;
              final label = _labelFor(position.family, turn);
              final r = state.leagueResults[i];
              if (!r.appearance.played) continue;
              played[label] = (played[label] ?? 0) + 1;
              if (_metBy(position.family, turn, r)) {
                streak++;
                if (streak > best) best = streak;
                runs[streak] = (runs[streak] ?? 0) + 1;
                met[label] = (met[label] ?? 0) + 1;
                rewardSum += MatchTarget.reward;
                seasonReward += MatchTarget.reward;
              } else {
                streak = 0;
              }
            }
            byStage[stage]![0] += seasonReward;
            byStage[stage]![1] += state.salary;
          },
        );
        index = 0;
        streak = 0;
      }

      final labels = played.keys.toList()..sort();
      final parts = labels.map((l) {
        final rate = (met[l] ?? 0) / played[l]! * 100;
        return '$l ${rate.toStringAsFixed(0)}%';
      });
      print(
        '${position.name.toUpperCase().padRight(3)} '
        '${parts.join('  ').padRight(46)} '
        '報酬 ${(rewardSum / seasons).round()}万/季  '
        '年俸 ${(salarySum / seasons).round()}万/季  '
        '割合 ${(rewardSum / salarySum * 100).toStringAsFixed(1)}%',
      );
      final total = runs[1] ?? 1;
      print(
        '      連続 3以上 ${((runs[3] ?? 0) / total * 100).toStringAsFixed(1)}%  '
        '5以上 ${((runs[5] ?? 0) / total * 100).toStringAsFixed(1)}%  '
        '8以上 ${((runs[8] ?? 0) / total * 100).toStringAsFixed(1)}%  '
        '最長 $best',
      );
      final stages = ['1-3季', '4-8季', '9季-'];
      for (var i = 0; i < 3; i++) {
        final r = byStage[i]![0];
        final sal = byStage[i]![1];
        print(
          '      ${stages[i]}  報酬 $r 万 / 年俸 $sal 万 = '
          '${sal == 0 ? '-' : (r / sal * 100).toStringAsFixed(1)}%',
        );
      }
    }
  }, timeout: const Timeout(Duration(minutes: 40)));
}

/// `MatchTarget.of` と同じ並び。節から的を引き直す。
String _labelFor(ScenarioFamily family, int turn) {
  if (family == ScenarioFamily.forward) {
    return switch (turn) {
      0 => '1ゴール',
      1 => '得点に絡む',
      _ => '評価7.0',
    };
  }
  if (family == ScenarioFamily.midfield) {
    return switch (turn) {
      0 => '1アシスト',
      1 => '得点に絡む',
      _ => '評価7.0',
    };
  }
  return switch (turn) {
    0 => '無失点',
    1 => '評価7.0',
    _ => '失点1以内',
  };
}

bool _metBy(ScenarioFamily family, int turn, MatchResult r) {
  if (family == ScenarioFamily.forward) {
    return switch (turn) {
      0 => r.goals >= 1,
      1 => r.goals + r.assists >= 1,
      _ => (r.rating ?? 0) >= 7.0,
    };
  }
  if (family == ScenarioFamily.midfield) {
    return switch (turn) {
      0 => r.assists >= 1,
      1 => r.goals + r.assists >= 1,
      _ => (r.rating ?? 0) >= 7.0,
    };
  }
  return switch (turn) {
    0 => r.conceded == 0,
    1 => (r.rating ?? 0) >= 7.0,
    _ => r.conceded <= 1,
  };
}
