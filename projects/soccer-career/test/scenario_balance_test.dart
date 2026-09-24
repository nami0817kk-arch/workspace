/// **同じ見返りで、難しいだけの手を置かない。**
///
/// 局面の3つの手は「安全＝通る・見返り小」「勝負＝通らない・見返り大」で
/// 対にしてある。ところが `Outcome` も判定する能力も同じで**難易度だけ高い**
/// 手があると、それは尖らせても選べない——**誰にとっても不正解の手**になる。
///
/// 2026-09-24 の実測（`test/choice_sim.dart`）では、中盤は出会う局面の 55% で
/// 最善手が9割以上同じで、育て方を4つ変えても答えの決まった23局面が1つも
/// 動かなかった。原因を「難しさに見返りが無いこと」と読んで経験点を配る案を
/// 作ったが、**自動で進めるだけでピークが 76.0 → 78.4 まで膨らんで外した**。
///
/// 数え直すと、同じ見返りで難しい手は 107 組あるが、**判定する能力まで同じ
/// なのは 4 組だけ**だった。残りは尖らせれば選べる（それが「別の能力」の
/// 意味）。逃げ道の無い4組は、判定する能力をその手にふさわしいものへ移した。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/game/scenarios.dart';
import 'package:soccer_career/models/attributes.dart';

final _all = [
  ...ScenarioPool.goalkeeper,
  ...ScenarioPool.defence,
  ...ScenarioPool.midfield,
  ...ScenarioPool.forward,
];

void main() {
  test('同じ見返り・同じ能力で、難しいだけの手が無い', () {
    final dead = <String>[];
    for (final scenario in _all) {
      for (final a in scenario.options) {
        for (final b in scenario.options) {
          if (identical(a, b)) continue;
          if (a.outcome != b.outcome) continue;
          if (a.difficulty <= b.difficulty) continue;
          // 反則で止める手・ゴールを防ぐ手には、別の見返りがある。
          if (a.foul != b.foul || a.preventsGoal != b.preventsGoal) continue;
          // **役どころが違えば、同じ見返りではない。** 仕留めは布石の後に
          // 深くなる（`comboLands`）ので、難しいぶんの見返りがそこにある。
          if (scenario.roleOf(a) != scenario.roleOf(b)) continue;
          final same = a.detail == b.detail && a.key == b.key;
          if (same) {
            dead.add(
              '${scenario.id}: 「${a.label}」(${a.difficulty}) は'
              '「${b.label}」(${b.difficulty}) と同じ見返り・同じ'
              '${a.detail?.label ?? a.key.label}で、難しいだけ',
            );
          }
        }
      }
    }
    expect(dead, isEmpty, reason: dead.join('\n'));
  });

  test('判定する能力は、その手の中身に合っている', () {
    // 移した4か所が戻っていないことの見張り。
    ScenarioOption pick(String id, String label) => _all
        .firstWhere((s) => s.id == id)
        .options
        .firstWhere((o) => o.label == label);

    expect(pick('gk-oneonone', '飛び出して距離を詰める').detail, Detail.reflexes);
    expect(pick('df-star', 'どこまでも付いていく').detail, Detail.sprintSpeed);
    // `mf-corner` の「ニアに速いボール」と `fw-rebound` の
    // 「落ち着いて浮かせる」は**どちらもその局面の仕留め**なので、
    // 難しいぶんの見返りはコンボにある。触らない
    // （触ったら実測で通算ゴールが 115 → 126 に膨らんだ）。
  });
}
