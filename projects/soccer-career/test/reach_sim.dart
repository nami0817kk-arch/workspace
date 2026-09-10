// ignore_for_file: avoid_print
/// 実際にキャリアを回して、一度も起きない状態を探す。
///
/// `flutter test test/reach_sim.dart` で明示的に走らせる。
/// ファイル名が `_test.dart` で終わらないので、CI の一括実行には入らない。
///
/// 「作ってあるのに起きない」は、このプロジェクトで繰り返し出る壊れ方。
/// `SelectionOutlook` の離脱・出場停止はこの形だった（分岐はあるのに到達しない）。
/// ソースを読むだけでは分からない——**回さないと見えない**。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/game/formulas.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/competition.dart';
import 'package:soccer_career/models/development.dart';
import 'package:soccer_career/models/entourage.dart';
import 'package:soccer_career/models/injury.dart';
import 'package:soccer_career/models/life.dart';
import 'package:soccer_career/models/news.dart';
import 'package:soccer_career/models/season.dart';
import 'package:soccer_career/models/reputation.dart';
import 'package:soccer_career/models/traits.dart';

import 'support/career_sim.dart';

void main() {
  test('起きない状態を探す', () async {
    final seen = <String, int>{};
    final gaps = <int>[];
    void mark(String kind, Object value) {
      final key = '$kind.${(value as dynamic).name}';
      seen[key] = (seen[key] ?? 0) + 1;
    }

    final styles = <Playstyle>[
      Playstyle(
        name: 'CM',
        position: Position.cm,
        startAge: 18,
        sim: SimStyle.balanced,
        agent: Agent.pool[0],
      ),
      Playstyle(
        name: 'ST',
        position: Position.st,
        startAge: 18,
        sim: SimStyle.aggressive,
        agent: Agent.pool[1],
      ),
      Playstyle(
        name: 'GK',
        position: Position.gk,
        startAge: 16,
        sim: SimStyle.safe,
        agent: Agent.pool[3],
      ),
      Playstyle(
        name: 'CB',
        position: Position.cb,
        startAge: 20,
        sim: SimStyle.safe,
        agent: Agent.pool[0],
      ),
      Playstyle(
        name: '残留志向',
        position: Position.wg,
        startAge: 18,
        sim: SimStyle.balanced,
        agent: Agent.pool[2],
        ambitious: false,
      ),
    ];

    for (final style in styles) {
      for (var seed = 0; seed < 12; seed++) {
        final career = await runCareer(style, seed);
        for (final state in career.seenStates) {
          seen[state] = (seen[state] ?? 0) + 1;
        }
        gaps.add(career.minGap);
      }
    }

    final report = <String, List<String>>{};
    void survey(String kind, List<String> names) {
      final dead = [
        for (final name in names)
          if ((seen['$kind.$name'] ?? 0) == 0) name,
      ];
      if (dead.isNotEmpty) report[kind] = dead;
    }

    survey('Trait', [for (final v in Trait.values) v.name]);
    survey('SecondCareer', [for (final v in SecondCareer.values) v.name]);
    survey('Appearance', [for (final v in Appearance.values) v.name]);
    survey('InjurySeverity', [for (final v in InjurySeverity.values) v.name]);
    survey('MomentumState', [for (final v in MomentumState.values) v.name]);
    survey('NewsKind', [for (final v in NewsKind.values) v.name]);
    survey('FixtureStake', [for (final v in FixtureStake.values) v.name]);
    survey('SquadStatus', [for (final v in SquadStatus.values) v.name]);
    survey('ContinentalStage',
        [for (final v in ContinentalStage.values) v.name]);
    survey('CupStage', [for (final v in CupStage.values) v.name]);
    survey('WorldCupStage', [for (final v in WorldCupStage.values) v.name]);
    survey('CareerStage', [for (final v in CareerStage.values) v.name]);
    survey('Award', [for (final v in Award.values) v.name]);
    survey('Signature', [for (final v in Signature.values) v.name]);
    survey('Tactic', [for (final v in Tactic.values) v.name]);

    print('');
    print('=== 一度も起きなかったもの ===');
    if (report.isEmpty) {
      print('無し');
    }
    for (final entry in report.entries) {
      print('${entry.key}: ${entry.value.join(', ')}');
    }
    gaps.sort();
    print('');
    print('=== クラブの強さとの差（キャリア中の最小）===');
    print('  最小 ${gaps.first} / 下位1割 ${gaps[gaps.length ~/ 10]} / '
        '中央 ${gaps[gaps.length ~/ 2]} / 最大 ${gaps.last}');
    print('  いまの登録外の線: ${Formulas.squadRegistrationGap}');
    print('');
    print('=== 起きた回数（少ない順に20件）===');
    final sorted = seen.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    for (final entry in sorted.take(20)) {
      print('  ${entry.key}  ${entry.value}');
    }
  }, timeout: const Timeout(Duration(minutes: 20)));
}
