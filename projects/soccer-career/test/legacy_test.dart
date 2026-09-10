/// 引退させた選手が、次のキャリアに残っているか。
///
/// 殿堂を作って記録は残るようになったが、**見るだけの場所**だった。
/// 20年かけて育てた選手が、次のキャリアのロッカールームにも監督室にも
/// 居ない。並んでいるだけで、次の20年が何を目指すのかもどこにも無い。
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/data/save_repository.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/career.dart';
import 'package:soccer_career/models/entourage.dart';
import 'package:soccer_career/models/legend.dart';
import 'package:soccer_career/models/life.dart';
import 'package:soccer_career/state/career_controller.dart';
import 'package:soccer_career/ui/screens/hall_screen.dart';

class _MemoryRepository implements SaveRepository {
  CareerState? _saved;

  @override
  Future<CareerState?> load() async => _saved;

  @override
  Future<void> save(CareerState state) async => _saved = state;

  @override
  Future<void> clear() async => _saved = null;
}

class _MemoryHall implements HallRepository {
  _MemoryHall([this._saved = const Hall()]);

  Hall _saved;

  @override
  Future<Hall> load() async => _saved;

  @override
  Future<void> save(Hall hall) async => _saved = hall;
}

Legend legend({
  required String name,
  SecondCareer second = SecondCareer.manager,
  int goals = 0,
  int appearances = 0,
  int league = 0,
  int peak = 70,
}) => Legend.fromJson({
  'name': name,
  'secondCareer': second.name,
  'goals': goals,
  'appearances': appearances,
  'leagueTitles': league,
  'peakOverall': peak,
});

Future<CareerController> started({
  Hall hall = const Hall(),
  int seed = 3,
}) async {
  final c = CareerController(
    repository: _MemoryRepository(),
    hallRepository: _MemoryHall(hall),
    careerEngine: CareerEngine(random: Random(seed)),
    matchEngine: MatchEngine(random: Random(seed)),
    random: Random(seed),
  );
  await c.init();
  await c.startCareer(
    name: '検証',
    position: Position.cm,
    age: 20,
    agent: Agent.pool.first,
  );
  return c;
}

void main() {
  group('次のキャリアの世界に居る', () {
    test('監督になった選手は、監督として現れることがある', () async {
      // 40人ぶん同じ人を入れて、確率のぶんを何度か引く。
      var seen = false;
      for (var seed = 0; seed < 12 && !seen; seed++) {
        final c = await started(
          hall: Hall(legends: [legend(name: '恩師テスト')]),
          seed: seed,
        );
        final manager = c.state!.manager;
        if (manager != null && manager.fromLegend) {
          expect(manager.name, '恩師テスト');
          seen = true;
        }
      }
      expect(seen, isTrue, reason: '12回始めて一度も現れなかった');
    });

    test('footballから離れた選手は出てこない', () async {
      for (var seed = 0; seed < 12; seed++) {
        final c = await started(
          hall: Hall(
            legends: [
              legend(name: '静かな人', second: SecondCareer.quiet),
              legend(name: '解説の人', second: SecondCareer.pundit),
            ],
          ),
          seed: seed,
        );
        expect(c.state!.manager?.fromLegend ?? false, isFalse);
        expect(c.state!.mentor?.fromLegend ?? false, isFalse);
      }
    });

    test('殿堂が空なら何も起きない', () async {
      final c = await started();
      expect(c.state!.manager?.fromLegend ?? false, isFalse);
      expect(c.state!.mentor?.fromLegend ?? false, isFalse);
    });

    test('強くはならない。名前と印が変わるだけ', () {
      const manager = Manager(name: 'A', tactic: Tactic.balanced, demand: 3);
      final cast = manager.asLegend('B');
      expect(cast.name, 'B');
      expect(cast.fromLegend, isTrue);
      expect(cast.tactic, manager.tactic);
      expect(cast.demand, manager.demand);

      const mate = Teammate(
        name: 'A',
        kind: TeammateKind.mentor,
        overall: 78,
        age: 33,
      );
      final castMate = mate.asLegend('B');
      expect(castMate.overall, mate.overall);
      expect(castMate.age, mate.age);
      expect(castMate.mentorFactor(21), mate.mentorFactor(21));
    });

    test('印は保存に乗る。知らない保存データでは付いていない', () {
      const manager = Manager(
        name: 'A',
        tactic: Tactic.balanced,
        demand: 3,
        fromLegend: true,
      );
      final json = manager.toJson();
      expect(Manager.fromJson(json, Random(1)).fromLegend, isTrue);
      expect(
        Manager.fromJson(json..remove('fromLegend'), Random(1)).fromLegend,
        isFalse,
      );

      const mate = Teammate(
        name: 'A',
        kind: TeammateKind.mentor,
        overall: 78,
        age: 33,
        fromLegend: true,
      );
      final mateJson = mate.toJson();
      expect(Teammate.fromJson(mateJson)!.fromLegend, isTrue);
      expect(
        Teammate.fromJson(mateJson..remove('fromLegend'))!.fromLegend,
        isFalse,
      );
    });

    test('呼吸が上がっても印は消えない', () {
      const mate = Teammate(
        name: 'A',
        kind: TeammateKind.partner,
        overall: 70,
        age: 25,
        fromLegend: true,
      );
      expect(mate.withSynergy(40).fromLegend, isTrue);
    });
  });

  group('歴代の記録', () {
    test('一番大きいものを、持ち主の名前と一緒に出す', () {
      final hall = Hall(
        legends: [
          legend(name: '新しい人', goals: 90, appearances: 400, peak: 78),
          legend(name: '古い人', goals: 120, appearances: 300, peak: 84),
        ],
      );
      final byLabel = {for (final r in hall.records) r.label: r};
      expect(byLabel['通算ゴール']!.holder, '古い人');
      expect(byLabel['通算ゴール']!.value, 120);
      expect(byLabel['通算出場']!.holder, '新しい人');
      expect(byLabel['ピーク総合力']!.holder, '古い人');
    });

    test('0の項目は出さない', () {
      // 0ゴールの「歴代最多」は的にならない。
      final hall = Hall(legends: [legend(name: 'A', peak: 70)]);
      final labels = hall.records.map((r) => r.label).toList();
      expect(labels, contains('ピーク総合力'));
      expect(labels, isNot(contains('通算ゴール')));
      expect(labels, isNot(contains('タイトル')));
    });

    test('誰も引退していなければ何も無い', () {
      expect(const Hall().records, isEmpty);
    });

    test('その選手が持っている記録を引ける', () {
      final top = legend(name: 'A', goals: 100, peak: 70);
      final hall = Hall(
        legends: [
          top,
          legend(name: 'B', goals: 10, peak: 90),
        ],
      );
      expect(hall.recordsHeldBy(top).map((r) => r.label), contains('通算ゴール'));
      expect(
        hall.recordsHeldBy(top).map((r) => r.label),
        isNot(contains('ピーク総合力')),
      );
    });
  });

  group('画面', () {
    testWidgets('歴代の記録が殿堂の一番上に出る', (tester) async {
      // 「歴代1位」の札は2人目からしか出さない（1人なら全部その人）。
      final c = await started(
        hall: Hall(
          legends: [
            legend(name: '記録保持者', goals: 133, peak: 88),
            legend(name: 'もう一人', goals: 10, peak: 60),
          ],
        ),
      );
      await tester.pumpWidget(MaterialApp(home: HallScreen(controller: c)));
      await tester.pumpAndSettle();
      expect(find.text('歴代の記録'), findsOneWidget);
      expect(find.text('133G'), findsOneWidget);
      expect(find.textContaining('歴代1位'), findsWidgets);
    });
  });
}
