// ignore_for_file: avoid_print
/// **布石は賭けになっているか。**
///
/// `flutter test test/setup_sim.dart` で明示的に走らせる。
///
/// 布石を「無難な手のうち一番易しいもの」に置いていたので、
/// 布石を打つことに代償が無く、同じ `Outcome` で難しいだけの手には
/// 役どころも無かった（`test/choice_sim.dart`: 育て方を4つ変えても
/// 答えの決まった23局面が1つも動かない）。
///
/// 布石を難しいほうへ移したあと、
/// 「布石から仕留める」が自動進行の期待値選びに勝てているかを測る。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/game/scenarios.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/season.dart';

import 'support/career_sim.dart';

/// 成功率がここを下回る手は選ばない（ただの自滅になる）。
const _floor = 0.35;

/// **一手だけ待つ。**
///
/// 期待値で選ぶのを基本にして、「仕留めにいきたいが布石がまだ乗っていない」
/// ときだけ、先に布石を打つ。仕留め以外を全部捨てる型（最初に測ったもの）は
/// ただ弱いだけで、布石の値打ちを測れていなかった
/// （ゴール 83 対 自動 109）。
ScenarioOption _patient(MatchInProgress match) {
  final scenario = match.current;
  final choice = match.pickFor(SimStyle.balanced);
  if (match.setupReady) return choice;
  if (scenario.roleOf(choice) != ComboRole.finish) return choice;
  for (final o in scenario.options) {
    if (scenario.roleOf(o) == ComboRole.setup && match.chanceFor(o) >= _floor) {
      return o;
    }
  }
  return choice;
}

void main() {
  test('布石から仕留める／期待値で選ぶ', () async {
    const seeds = 30;

    Future<void> run(
      String name,
      ScenarioOption Function(MatchInProgress)? pick,
    ) async {
      var peak = 0.0;
      var rating = 0.0;
      var goals = 0.0;
      var assists = 0.0;
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
          assists += c.assists;
          titles += c.leagueTitles + c.cupTitles;
          caps += c.caps;
        }
      }
      const n = seeds * 3;
      print(
        '${name.padRight(12)} '
        'ピーク ${(peak / n).toStringAsFixed(1)}  '
        '平均評価 ${(rating / n).toStringAsFixed(2)}  '
        'ゴール ${(goals / n).toStringAsFixed(0)}  '
        'アシスト ${(assists / n).toStringAsFixed(0)}  '
        'タイトル ${(titles / n).toStringAsFixed(2)}  '
        '代表 ${(caps / n).toStringAsFixed(1)}',
      );
    }

    await run('自動（期待値）', null);
    await run('一手だけ待つ', _patient);
  }, timeout: const Timeout(Duration(minutes: 60)));
}
