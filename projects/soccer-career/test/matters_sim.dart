// ignore_for_file: avoid_print
/// **局面の選択は、キャリアを変えているのか。**
///
/// このゲームの中核は「試合中の選択」だと決めてある。1試合3局面 × 38節 ×
/// 20年で 2280回。その2280回が本当に効いているなら、わざと一番悪い手を
/// 選び続けたキャリアは、最善手のキャリアとはっきり違うはずだ。
/// 同じなら、2280回のタップは飾りということになる。
///
/// `flutter test test/matters_sim.dart` で明示的に走らせる。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/game/scenarios.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/season.dart';

import 'support/career_sim.dart';

void main() {
  test('選択がキャリアを変えているか', () async {
    const seeds = 24;

    Future<void> run(
      String name, {
      SimStyle sim = SimStyle.balanced,
      ScenarioOption Function(MatchInProgress)? pick,
      Position position = Position.cm,
    }) async {
      var peak = 0.0;
      var rating = 0.0;
      var goals = 0.0;
      var apps = 0.0;
      var caps = 0.0;
      var titles = 0.0;
      var tier = 0.0;
      var salary = 0.0;
      for (var seed = 0; seed < seeds; seed++) {
        final c = await runCareer(
          Playstyle(
            name: 'x',
            position: position,
            startAge: 18,
            sim: sim,
            agent: Agent.pool.first,
            pick: pick,
          ),
          seed,
        );
        peak += c.peakOverall;
        rating += c.averageRating;
        goals += c.goals;
        apps += c.appearances;
        caps += c.caps;
        titles += c.leagueTitles + c.cupTitles;
        tier += c.bestTier;
        salary += c.peakSalary;
      }
      print('${name.padRight(18)} '
          'ピーク ${(peak / seeds).toStringAsFixed(1)}  '
          '平均評価 ${(rating / seeds).toStringAsFixed(2)}  '
          '通算 ${(goals / seeds).toStringAsFixed(0)}G  '
          '出場 ${(apps / seeds).toStringAsFixed(0)}  '
          '代表 ${(caps / seeds).toStringAsFixed(0)}キャップ  '
          'タイトル ${(titles / seeds).toStringAsFixed(1)}  '
          '最高の部 ${(tier / seeds).toStringAsFixed(1)}  '
          '最高年俸 ${(salary / seeds / 10000).toStringAsFixed(0)}万');
    }

    // 一番悪い手（期待値が最小）を選び続ける。
    ScenarioOption worst(MatchInProgress m) => m.current.options
        .reduce((a, b) => m.expectedDelta(a) <= m.expectedDelta(b) ? a : b);
    // 毎回いちばん左の手を選ぶ。読まずに押しているのと同じ。
    ScenarioOption first(MatchInProgress m) => m.current.options.first;

    print('--- 2280回の選択が、キャリアをどれだけ動かすか ---');
    await run('最善（期待値）');
    await run('安全に', sim: SimStyle.safe);
    await run('勝負に出る', sim: SimStyle.aggressive);
    await run('読まずに左端', pick: first);
    await run('わざと最悪', pick: worst);

    print('--- ポジション別（最善） ---');
    for (final position in [Position.st, Position.wg, Position.cb]) {
      await run(position.name, position: position);
    }
  }, timeout: const Timeout(Duration(minutes: 40)));
}
