// ignore_for_file: avoid_print
/// **難しい手を選び続けると、何が起きるか。**
///
/// `flutter test test/difficulty_sim.dart` で明示的に走らせる。
///
/// 同じ見返りで難しいだけの手は、誰にとっても選ぶ理由が無かった
/// （`test/choice_sim.dart`: 育て方を4つ変えても、答えの決まった23局面が
/// 1つも動かない）。難しさを経験点に返したあと、
/// **今日の評価を捨てて来季の自分を買う**という取引が成立しているかを測る。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/game/scenarios.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/season.dart';

import 'support/career_sim.dart';

/// 成功率がここを下回る手は、難しくても選ばない（ただの自滅になる）。
const _floor = 0.40;

/// **同じ見返りの中で、一番難しい手。**
///
/// 局面全体で一番難しい手はたいてい得点の手で、それは自動進行ももともと
/// 選ぶ。狙いは「同じ `Outcome` で難易度だけ高い、選ぶ理由の無かった手」
/// なので、そこを突く型で測る。エンジンに頼らず、局面の中で計算する
/// （master でも同じ式で回せるように）。
int _edgeOf(Scenario scenario, ScenarioOption option) {
  final easiest = scenario.options
      .where((o) => o.outcome == option.outcome)
      .map((o) => o.difficulty)
      .reduce((a, b) => a < b ? a : b);
  return option.difficulty - easiest;
}

ScenarioOption _hardest(MatchInProgress match) {
  final scenario = match.current;
  final viable = scenario.options
      .where((o) => match.chanceFor(o) >= _floor)
      .toList();
  final from = viable.isEmpty ? scenario.options : viable;
  return from.reduce((a, b) {
    final ea = _edgeOf(scenario, a);
    final eb = _edgeOf(scenario, b);
    if (eb != ea) return eb > ea ? b : a;
    return match.expectedDelta(b) > match.expectedDelta(a) ? b : a;
  });
}

ScenarioOption _easiest(MatchInProgress match) =>
    match.current.options.reduce((a, b) => b.difficulty < a.difficulty ? b : a);

void main() {
  test('難しい手を選ぶ／易しい手を選ぶ', () async {
    const seeds = 30;

    Future<void> run(
      String name,
      ScenarioOption Function(MatchInProgress)? pick,
    ) async {
      var peak = 0.0;
      var rating = 0.0;
      var goals = 0.0;
      var apps = 0.0;
      var titles = 0.0;
      var caps = 0.0;
      for (final position in [Position.st, Position.cm, Position.cb]) {
        for (var seed = 0; seed < seeds; seed++) {
          final c = await runCareer(
            Playstyle(
              name: name,
              position: position,
              startAge: 18,
              sim: SimStyle.balanced,
              agent: Agent.pool.first,
              pick: pick,
            ),
            seed,
          );
          peak += c.peakOverall;
          rating += c.averageRating;
          goals += c.goals;
          apps += c.appearances;
          titles += c.leagueTitles + c.cupTitles;
          caps += c.caps;
        }
      }
      const n = seeds * 3;
      print(
        '${name.padRight(10)} '
        'ピーク ${(peak / n).toStringAsFixed(1)}  '
        '平均評価 ${(rating / n).toStringAsFixed(2)}  '
        'ゴール ${(goals / n).toStringAsFixed(0)}  '
        '出場 ${(apps / n).toStringAsFixed(0)}  '
        'タイトル ${(titles / n).toStringAsFixed(2)}  '
        '代表 ${(caps / n).toStringAsFixed(1)}',
      );
    }

    await run('自動（期待値）', null);
    await run('手強いほう', _hardest);
    await run('易しい手', _easiest);
  }, timeout: const Timeout(Duration(minutes: 60)));
}
