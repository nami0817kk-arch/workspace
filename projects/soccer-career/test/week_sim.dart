// ignore_for_file: avoid_print
/// 週の踏み込み方と、組む相手が、実際にどれだけ効くかを測る。
///
/// `flutter test test/week_sim.dart` で明示的に走らせる。
/// ファイル名が `_test.dart` で終わらないので、CI の一括実行には入らない。
///
/// 見たいのは「追い込むが毎週の最適解になっていないか」。
/// 消耗と怪我の代償を払ってでも伸びるなら、それは選択ではなく正解になる。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/season.dart';
import 'package:soccer_career/models/training.dart';

import 'support/career_sim.dart';

void main() {
  test('週の踏み込み方', () async {
    const seeds = 40;

    Future<void> run(String name, Playstyle style) async {
      var peak = 0.0;
      var rating = 0.0;
      var injuries = 0.0;
      var apps = 0.0;
      var broke = 0;
      var great = 0;
      var pro = 0;
      var atPot = 0;
      var potential = 0.0;
      for (var seed = 0; seed < seeds; seed++) {
        final c = await runCareer(style, seed);
        peak += c.peakOverall;
        rating += c.averageRating;
        injuries += c.seasons == 0 ? 0 : c.injuries / c.seasons;
        apps += c.appearances;
        potential += c.potential;
        if (c.breakthroughs > 0) broke++;
        great += c.greatWeeks;
        pro += c.professionalism;
        atPot += c.atPotentialSeasons;
      }
      print('${name.padRight(22)} '
          'ピーク ${(peak / seeds).toStringAsFixed(1)}  '
          'ポテ ${(potential / seeds).toStringAsFixed(1)}  '
          '限界突破 ${(broke / seeds * 100).toStringAsFixed(0)}%  '
          '平均評価 ${(rating / seeds).toStringAsFixed(2)}  '
          '怪我/季 ${(injuries / seeds).toStringAsFixed(2)}  '
          '通算出場 ${(apps / seeds).toStringAsFixed(0)}  '
          '大成功 ${(great / seeds).toStringAsFixed(0)}  '
          'プロ意識 ${(pro / seeds).toStringAsFixed(1)}  '
          '上限到達季 ${(atPot / seeds).toStringAsFixed(1)}');
    }

    Playstyle style({
      TrainingEffort effort = TrainingEffort.normal,
      TrainingCompanion companion = TrainingCompanion.alone,
      bool rests = true,
    }) =>
        Playstyle(
          name: 'x',
          position: Position.cm,
          startAge: 18,
          sim: SimStyle.balanced,
          agent: Agent.pool.first,
          effort: effort,
          companion: companion,
          rests: rests,
        );

    print('--- 踏み込み方（一人でやる・自動休養あり） ---');
    for (final effort in TrainingEffort.values) {
      await run(effort.label, style(effort: effort));
    }

    print('--- 踏み込み方（自動休養なし） ---');
    for (final effort in TrainingEffort.values) {
      await run(effort.label, style(effort: effort, rests: false));
    }

    print('--- 組む相手（普通） ---');
    for (final companion in TrainingCompanion.values) {
      await run(companion.label, style(companion: companion));
    }
  }, timeout: const Timeout(Duration(minutes: 40)));
}
