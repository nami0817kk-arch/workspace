// ignore_for_file: avoid_print
/// バランス調整のための長期シミュレーション。
///
/// `flutter test test/balance_sim.dart` で明示的に走らせる。
/// ファイル名が `_test.dart` で終わらないので、CI の一括実行には入らない。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/entourage.dart';
import 'package:soccer_career/models/life.dart';
import 'package:soccer_career/models/physique.dart';
import 'package:soccer_career/models/season.dart';
import 'package:soccer_career/models/support.dart';

import 'support/career_sim.dart';

void main() {
  final styles = <Playstyle>[
    Playstyle(
      name: '標準（CM・18歳・バランス）',
      position: Position.cm,
      startAge: 18,
      sim: SimStyle.balanced,
      agent: Agent.pool[0],
    ),
    Playstyle(
      name: 'ストライカー（ST・18歳・勝負）',
      position: Position.st,
      startAge: 18,
      sim: SimStyle.aggressive,
      agent: Agent.pool[1],
    ),
    Playstyle(
      name: '守備者（CB・20歳・安全）',
      position: Position.cb,
      startAge: 20,
      sim: SimStyle.safe,
      agent: Agent.pool[0],
    ),
    Playstyle(
      name: 'GK（16歳・安全）',
      position: Position.gk,
      startAge: 16,
      sim: SimStyle.safe,
      agent: Agent.pool[3],
    ),
    Playstyle(
      name: '育成年代から（WG・16歳・バランス）',
      position: Position.wg,
      startAge: 16,
      sim: SimStyle.balanced,
      agent: Agent.pool[3],
    ),
    Playstyle(
      name: '遅い出発（ST・21歳・バランス）',
      position: Position.st,
      startAge: 21,
      sim: SimStyle.balanced,
      agent: Agent.pool[4],
    ),
    Playstyle(
      name: '休まない（CM・18歳）',
      position: Position.cm,
      startAge: 18,
      sim: SimStyle.balanced,
      agent: Agent.pool[0],
      rests: false,
    ),
    Playstyle(
      name: '身体に投資（CM・18歳）',
      position: Position.cm,
      startAge: 18,
      sim: SimStyle.balanced,
      agent: Agent.pool[0],
      invests: true,
      habits: const Habits(sleep: 2, diet: 2),
      directive: Directive.develop,
    ),
    Playstyle(
      name: '出場優先・残留志向（CM・18歳）',
      position: Position.cm,
      startAge: 18,
      sim: SimStyle.balanced,
      agent: Agent.pool[0],
      directive: Directive.playingTime,
      ambitious: false,
    ),
    Playstyle(
      name: '居残り＋増量（ST・18歳）',
      position: Position.st,
      startAge: 18,
      sim: SimStyle.balanced,
      agent: Agent.pool[1],
      drills: true,
      bodyPlan: BodyPlan.bulk,
      preseason: PreseasonPlan.tour,
    ),
  ];

  test('長期シミュレーション', () async {
    final all = <Career>[];
    for (var i = 0; i < styles.length; i++) {
      final careers = <Career>[];
      for (var seed = 0; seed < 20; seed++) {
        careers.add(await runCareer(styles[i], i * 100 + seed));
      }
      report(styles[i].name, careers);
      all.addAll(careers);
    }
    report('全体', all);
    print('');
    print('総シーズン数 ${all.fold(0, (s, c) => s + c.seasons)}');
  }, timeout: const Timeout(Duration(minutes: 20)));
}
