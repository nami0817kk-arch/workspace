// ignore_for_file: avoid_print
/// **オフの4択は、キャリアを変えているか。**
///
/// `flutter test test/offseason_sim.dart` で明示的に走らせる。
///
/// 選べるようにしただけで、結果が同じなら選択肢ではない。逆に
/// 1つが常に上なら、それも選択肢ではない。**4つとも、別のものを
/// 取りに行った形になっているか**を見る。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/life.dart';
import 'package:soccer_career/models/season.dart';

import 'support/career_sim.dart';

void main() {
  test('オフの過ごし方', () async {
    const seeds = 40;

    for (final off in Offseason.values) {
      var peak = 0.0;
      var rating = 0.0;
      var apps = 0.0;
      var injuries = 0.0;
      var severe = 0.0;
      var renown = 0.0;
      var titles = 0.0;
      var caps = 0.0;
      var seasons = 0.0;
      var offers = 0.0;
      var moves = 0.0;
      for (final position in [Position.st, Position.cm, Position.cb]) {
        for (var seed = 0; seed < seeds; seed++) {
          final c = await runCareer(
            Playstyle(
              name: off.label,
              position: position,
              startAge: 18,
              sim: SimStyle.balanced,
              agent: Agent.pool.first,
              offseason: off,
            ),
            seed,
          );
          peak += c.peakOverall;
          rating += c.averageRating;
          apps += c.appearances;
          injuries += c.injuries;
          severe += c.severeInjuries;
          renown += c.peakValue;
          titles += c.leagueTitles + c.cupTitles;
          caps += c.caps;
          seasons += c.seasons;
          offers += c.offersSeen;
          moves += c.transfers;
        }
      }
      const n = seeds * 3;
      print(
        '${off.label.padRight(6)} '
        'ピーク ${(peak / n).toStringAsFixed(1)}  '
        '評価 ${(rating / n).toStringAsFixed(2)}  '
        '出場 ${(apps / n).toStringAsFixed(0)}  '
        '季 ${(seasons / n).toStringAsFixed(1)}  '
        '怪我 ${(injuries / n).toStringAsFixed(1)}(重${(severe / n).toStringAsFixed(2)})  '
        '値札 ${(renown / n).round()}  '
        'タイトル ${(titles / n).toStringAsFixed(2)}  '
        '代表 ${(caps / n).toStringAsFixed(1)}  '
        '移籍話 ${(offers / n).toStringAsFixed(1)}  '
        '移籍 ${(moves / n).toStringAsFixed(1)}',
      );
    }
  }, timeout: const Timeout(Duration(minutes: 60)));
}
