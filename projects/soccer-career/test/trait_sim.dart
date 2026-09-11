// ignore_for_file: avoid_print
/// **特性は、キャリアをどれだけ変えているか。**
///
/// 「能力値だけだと、そうなるので特性とかの影響度をあげていこう」への
/// 手がかり。能力値も選び方も揃えて、**特性だけを差し替えて**引退まで回す。
/// 結果が動かないなら、特性は名前が付いているだけの飾りということになる。
///
/// `flutter test test/trait_sim.dart` で明示的に走らせる。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/season.dart';
import 'package:soccer_career/models/traits.dart';

import 'support/career_sim.dart';

void main() {
  test('特性がキャリアを変えるか', () async {
    const seeds = 16;

    Future<void> run(String name, List<Trait> traits) async {
      var overall = 0.0;
      var rating = 0.0;
      var value = 0.0;
      var caps = 0.0;
      var titles = 0.0;
      var goals = 0.0;
      var appearances = 0.0;
      var salary = 0.0;
      var top = 0;

      for (var seed = 0; seed < seeds; seed++) {
        final career = await runCareer(
          Playstyle(
            name: 'x',
            position: Position.cm,
            startAge: 18,
            sim: SimStyle.balanced,
            agent: Agent.pool.first,
            traits: traits,
          ),
          seed,
        );
        overall += career.peakOverall;
        rating += career.averageRating;
        value += career.peakValue;
        caps += career.caps;
        titles += career.leagueTitles + career.cupTitles;
        goals += career.goals;
        appearances += career.appearances;
        salary += career.peakSalary;
        // 最上位の国の1部まで行けたか。
        if (career.bestPrestige >= 5) top++;
      }

      print(
        '${name.padRight(20)} '
        'ピーク ${(overall / seeds).toStringAsFixed(1)}  '
        '評価 ${(rating / seeds).toStringAsFixed(2)}  '
        '値札 ${(value / seeds / 10000).toStringAsFixed(2)}億  '
        '年俸 ${(salary / seeds / 10000).toStringAsFixed(2)}億  '
        '代表 ${(caps / seeds).toStringAsFixed(0)}  '
        'タイトル ${(titles / seeds).toStringAsFixed(1)}  '
        'ゴール ${(goals / seeds).toStringAsFixed(0)}  '
        '出場 ${(appearances / seeds).toStringAsFixed(0)}  '
        '格5 ${top * 100 ~/ seeds}%',
      );
    }

    print('--- 能力値と選び方を揃えて、特性だけ差し替える ---');
    await run('特性なし', const []);
    await run('司令塔＋テンポ', const [Trait.playmaker, Trait.tempoSetter]);
    await run('本番強者＋クラッチ', const [Trait.ironNerve, Trait.clutch]);
    await run('飲み込み＋殻を破る', const [Trait.quickLearner, Trait.breaker]);
    await run('鉄人＋頑丈', const [Trait.ironman, Trait.robust]);
    await run('天才', const [Trait.genius]);
    await run('欠点2つ', const [Trait.lazy, Trait.fragile]);
  }, timeout: const Timeout(Duration(minutes: 60)));
}
