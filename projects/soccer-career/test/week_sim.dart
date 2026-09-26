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
      var conf = 0;
      var amb = 0;
      var temp = 0;
      var atPot = 0;
      var knack = 0;
      var potential = 0.0;
      var last = 0.0;
      var lateApps = 0.0;
      var lateGoals = 0.0;
      var severe = 0.0;
      var strain = 0.0;
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
        conf += c.confidence;
        amb += c.ambition;
        temp += c.temper;
        atPot += c.atPotentialSeasons;
        if (c.knackAge > 0) knack++;
        last += c.finalOverall;
        lateApps += c.lateAppearances;
        lateGoals += c.lateGoals;
        severe += c.severeInjuries;
        strain += c.strain;
      }
      print('${name.padRight(22)} '
          'ピーク ${(peak / seeds).toStringAsFixed(1)}  '
          'ポテ ${(potential / seeds).toStringAsFixed(1)}  '
          '限界突破 ${(broke / seeds * 100).toStringAsFixed(0)}%  '
          '平均評価 ${(rating / seeds).toStringAsFixed(2)}  '
          '怪我/季 ${(injuries / seeds).toStringAsFixed(2)}  '
          '通算出場 ${(apps / seeds).toStringAsFixed(0)}  '
          '大成功 ${(great / seeds).toStringAsFixed(0)}  '
          '性格 ${(pro / seeds).toStringAsFixed(1)}'
          '/${(conf / seeds).toStringAsFixed(1)}'
          '/${(amb / seeds).toStringAsFixed(1)}'
          '/${(temp / seeds).toStringAsFixed(1)}  '
          '上限到達季 ${(atPot / seeds).toStringAsFixed(1)}  '
          'コツ ${(knack * 100 / seeds).toStringAsFixed(0)}%  '
          '引退時 ${(last / seeds).toStringAsFixed(1)}  '
          '33歳以降 ${(lateApps / seeds).toStringAsFixed(0)}試合'
          '${(lateGoals / seeds).toStringAsFixed(0)}G  '
          '重傷 ${(severe / seeds).toStringAsFixed(2)}  '
          '消耗 ${(strain / seeds).toStringAsFixed(0)}');
    }

    Playstyle style({
      TrainingEffort effort = TrainingEffort.normal,
      TrainingCompanion companion = TrainingCompanion.alone,
      bool rests = true,
      int? easeFrom,
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
          easeFrom: easeFrom,
        );

    print('--- 踏み込み方（一人でやる・自動休養あり） ---');
    for (final effort in TrainingEffort.values) {
      await run(effort.label, style(effort: effort));
    }

    print('--- 踏み込み方（自動休養なし） ---');
    for (final effort in TrainingEffort.values) {
      await run(effort.label, style(effort: effort, rests: false));
    }

    // 一番知りたいのはここ。**踏み込み方を変える**手が効くかどうか。
    // 一定の型しか測っていないと、この手は測れない。
    print('--- 途中で引く（追い込む→流す） ---');
    await run('ずっと追い込む', style(effort: TrainingEffort.hard));
    for (final age in [26, 29, 32]) {
      await run('$age歳から流す',
          style(effort: TrainingEffort.hard, easeFrom: age));
    }

    print('--- 組む相手（普通） ---');
    for (final companion in TrainingCompanion.values) {
      await run(companion.label, style(companion: companion));
    }
  }, timeout: const Timeout(Duration(minutes: 40)));
}
