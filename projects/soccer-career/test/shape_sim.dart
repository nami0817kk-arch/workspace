// ignore_for_file: avoid_print
/// **選んだことが、選手の形を変えているか。**
///
/// 「自分の選択で選手の成長や方向性が決まるようにしたい」「尖った選手の育成も
/// できるようにしたい」への手がかり。育てる方向（`focus`）と練習メニューを
/// 変えて20年回し、引退した選手の**能力の形**を比べる。
///
/// 3つの育て方が同じ形に着くなら、選択は形を変えていない。
///
/// `flutter test test/shape_sim.dart` で明示的に走らせる。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/season.dart';
import 'package:soccer_career/models/training.dart';

import 'support/career_sim.dart';

void main() {
  test('選んだことが選手の形を変えるか', () async {
    const seeds = 16;

    Future<void> run(
      String name, {
      List<Detail> focus = const [],
      TrainingMenu? menu,
    }) async {
      final totals = <Detail, double>{for (final d in Detail.values) d: 0};
      var top = 0.0;
      var overall = 0.0;
      var hitFocus = 0;
      var aimedValue = 0.0;
      var aimedCount = 0.0;
      var rating = 0.0;
      var value = 0.0;
      var caps = 0.0;

      for (var seed = 0; seed < seeds; seed++) {
        final career = await runCareer(
          Playstyle(
            name: 'x',
            position: Position.cm,
            startAge: 18,
            sim: SimStyle.balanced,
            agent: Agent.pool.first,
            focus: focus,
            menu: menu,
          ),
          seed,
        );
        final attributes = career.finalAttributes;
        if (attributes == null) continue;
        final values = [
          for (final d in Detail.values) attributes.detail(d).toDouble(),
        ];
        for (final d in Detail.values) {
          totals[d] = totals[d]! + attributes.detail(d);
        }
        final best = values.reduce((a, b) => a > b ? a : b);
        top += best;
        overall += career.peakOverall;
        rating += career.averageRating;
        value += career.peakValue;
        caps += career.caps;
        if (focus.isNotEmpty) {
          aimedValue += focus
              .map((d) => attributes.detail(d))
              .reduce((a, b) => a > b ? a : b);
          aimedCount += focus
              .map(career.dedicationOf)
              .reduce((a, b) => a > b ? a : b);
        }
        // 狙った項目が、実際に一番高くなったか。
        if (focus.isNotEmpty) {
          final wanted = focus
              .map((d) => attributes.detail(d))
              .reduce((a, b) => a > b ? a : b);
          if (wanted >= best) hitFocus++;
        }
      }

      // 一番高い3項目。育て方が形に出ているなら、ここが入れ替わるはず。
      final ranked = Detail.values.toList()
        ..sort((a, b) => totals[b]!.compareTo(totals[a]!));
      final best3 = ranked
          .take(3)
          .map((d) => '${d.label}${(totals[d]! / seeds).toStringAsFixed(0)}')
          .join(' ');

      print(
        '${name.padRight(16)} '
        'ピーク ${(overall / seeds).toStringAsFixed(1)}  '
        '最高 ${(top / seeds).toStringAsFixed(1)}  '
        '評価 ${(rating / seeds).toStringAsFixed(2)}  '
        '値札 ${(value / seeds / 10000).toStringAsFixed(1)}億  '
        '代表 ${(caps / seeds).toStringAsFixed(0)}  '
        '上位3 $best3'
        '${focus.isEmpty ? '' : '  狙い ${(aimedValue / seeds).toStringAsFixed(0)}'
                  '（積み ${(aimedCount / seeds).toStringAsFixed(0)}回）'
                  ' 一番 ${hitFocus * 100 ~/ seeds}%'}',
      );
    }

    print('--- 育て方で、引退時の形はどれだけ変わるか ---');
    await run('何も選ばない');
    await run(
      'シュート一本',
      focus: [Detail.finishing, Detail.shotPower, Detail.longShots],
      menu: TrainingMenu.attacking,
    );
    await run(
      'パス一本',
      focus: [Detail.shortPassing, Detail.longPassing, Detail.vision],
      menu: TrainingMenu.possession,
    );
    await run(
      '走力一本',
      focus: [Detail.sprintSpeed, Detail.acceleration, Detail.agility],
      menu: TrainingMenu.athletic,
    );
    await run(
      '守備一本',
      focus: [Detail.tackling, Detail.marking, Detail.interceptions],
      menu: TrainingMenu.defenceWork,
    );
  }, timeout: const Timeout(Duration(minutes: 40)));
}
