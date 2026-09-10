/// 取り返しのつかないところ。
///
/// このゲームで戻せなかったのは**怪我だけ**だった。信頼は下がっても、
/// 出れば評価点で戻せる。だから、積み上げてきた選択に値段が付かない。
///
/// 構想外は「出られないので評価点も付かない」状態で、評価点で戻す道だけが
/// 閉じている。落ちる前に必ず画面に出す（予告なしに落とすのは理不尽）。
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/data/save_repository.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/game/formulas.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/game/weekly_plan.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/career.dart';
import 'package:soccer_career/models/entourage.dart';
import 'package:soccer_career/models/injury.dart';
import 'package:soccer_career/models/life.dart';
import 'package:soccer_career/models/player.dart';
import 'package:soccer_career/models/reputation.dart';
import 'package:soccer_career/models/season.dart';
import 'package:soccer_career/state/career_controller.dart';

class _MemoryRepository implements SaveRepository {
  CareerState? _saved;

  @override
  Future<CareerState?> load() async => _saved;

  @override
  Future<void> save(CareerState state) async => _saved = state;

  @override
  Future<void> clear() async => _saved = null;
}

Future<CareerController> started({int seed = 3}) async {
  final c = CareerController(
    repository: _MemoryRepository(),
    careerEngine: CareerEngine(random: Random(seed)),
    matchEngine: MatchEngine(random: Random(seed)),
    random: Random(seed),
  );
  await c.startCareer(
      name: '検証', position: Position.cm, age: 24, agent: Agent.pool.first);
  return c;
}

void main() {
  group('構想外', () {
    test('信頼を失い切ると、力があっても使われない', () async {
      final c = await started();
      final state = c.state!;
      state.manager =
          const Manager(name: 'M', tactic: Tactic.balanced, demand: 3);

      state.relations = const Relations(manager: 50);
      expect(state.frozenOut, isFalse);

      state.relations =
          const Relations(manager: Formulas.frozenOutTrust - 1);
      expect(state.frozenOut, isTrue);

      c.startNextMatch();
      expect(c.currentMatch!.appearance, Appearance.benched);
    });

    test('落ちる前に、必ず画面に出る', () async {
      final c = await started();
      final state = c.state!;
      state.manager =
          const Manager(name: 'M', tactic: Tactic.balanced, demand: 3);

      state.relations = const Relations(manager: 50);
      expect(state.trustAtRisk, isFalse);

      state.relations =
          const Relations(manager: Formulas.trustWarning - 1);
      expect(state.trustAtRisk, isTrue, reason: '予告なしに落ちる');
      expect(state.frozenOut, isFalse, reason: '警告より先に落ちている');

      // 警告の線は、落ちる線より上にある。
      expect(Formulas.trustWarning, greaterThan(Formulas.frozenOutTrust));
    });

    test('監督が居なければ、構想外にはならない', () async {
      final c = await started();
      final state = c.state!;
      state.manager = null;
      state.relations = const Relations(manager: 0);
      expect(state.frozenOut, isFalse);
      expect(state.trustAtRisk, isFalse);
    });

    test('見通しに理由が出て、評価点では戻せないと書いてある', () async {
      final c = await started();
      final state = c.state!;
      state.manager =
          const Manager(name: 'M', tactic: Tactic.balanced, demand: 3);
      state.relations = const Relations(manager: 1);

      final outlook = SelectionOutlook.of(state, bonus: 0);
      expect(outlook.frozenOut, isTrue);
      expect(outlook.likely, Appearance.benched);
      expect(outlook.headline, '構想外');
      expect(outlook.reason, contains('評価点も付かない'));
    });

    test('離脱や出場停止のほうが先に来る', () async {
      final c = await started();
      final state = c.state!;
      state.manager =
          const Manager(name: 'M', tactic: Tactic.balanced, demand: 3);
      state.relations = const Relations(manager: 1);
      state.suspension = 2;

      final outlook = SelectionOutlook.of(state, bonus: 0);
      expect(outlook.likely, Appearance.suspended);
    });

    test('監督が代われば、白紙に戻る', () async {
      final c = await started();
      final state = c.state!;
      state.manager =
          const Manager(name: 'M', tactic: Tactic.balanced, demand: 3);
      state.relations = const Relations(manager: 1);
      expect(state.frozenOut, isTrue);

      // 新しい監督の下では 50 から始まる（`advanceSeason` と同じ扱い）。
      state.relations = const Relations(manager: 50);
      expect(state.frozenOut, isFalse);
    });
  });

  group('無理を通した代償', () {
    test('疲れているほど、引くのは重いほうの怪我', () {
      expect(MatchEngine.severeShareFor(80),
          greaterThan(MatchEngine.severeShareFor(0)));
      expect(MatchEngine.severeShareFor(0), Formulas.severeInjuryShare);
    });

    test('理不尽にはならない（上限がある）', () {
      expect(MatchEngine.severeShareFor(100),
          lessThanOrEqualTo(Formulas.severeShareMax));
      // 元の割合の3倍を超えると、走った選手が必ず壊れるゲームになる。
      expect(Formulas.severeShareMax,
          lessThan(Formulas.severeInjuryShare * 3));
    });

    test('実際に重傷の割合が上がる', () {
      int severeOver(int fatigue) {
        var severe = 0;
        for (var seed = 0; seed < 600; seed++) {
          final injury = MatchEngine(random: Random(seed)).rollInjury(
            Player(
              name: 'P',
              age: 27,
              position: Position.cm,
              attributes: Attributes.fromDetails(
                  {for (final d in Detail.values) d: 60}),
              potential: 80,
              condition: 60,
            ),
            baseChance: 1.0,
            fatigue: fatigue,
          );
          if (injury?.severity == InjurySeverity.severe) severe++;
        }
        return severe;
      }

      expect(severeOver(90), greaterThan(severeOver(0)));
    });

    test('限界まで来ていることが、画面に出る段と揃っている', () {
      // 「疲労 限界まで来ている」と警告の線がずれると、
      // 危ないと書いていないのに危ない状態ができる。
      expect(const Fatigue(value: Formulas.fatigueWarning).label,
          '限界まで来ている');
    });
  });
}
