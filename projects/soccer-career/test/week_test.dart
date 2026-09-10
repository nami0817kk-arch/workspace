/// 週の選択が、実際にゲームを動かしているか。
///
/// 週の選択は「どのメニューか」だけで、**踏み込む/流すの判断も、
/// 誰と組むかの判断も無かった**。毎週同じ画面で同じものを選ぶだけなので、
/// 練習の週に手応えが無い。
///
/// もう一つの穴は、踏み込んでも**届く高さは変わらない**こと。
/// ポテンシャルで止まるので、早く着くだけで同じ選手になる
/// （実測: 流す 74.0 / 普通 74.5 / 追い込む 74.8）。
/// 追い込んだ週の積み上げ（`greatWeeks`）だけが上限に触れる。
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/data/save_repository.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/game/formulas.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/career.dart';
import 'package:soccer_career/models/development.dart';
import 'package:soccer_career/models/entourage.dart';
import 'package:soccer_career/models/personality.dart';
import 'package:soccer_career/models/player.dart';
import 'package:soccer_career/models/training.dart';
import 'package:soccer_career/state/career_controller.dart';

import 'ui_test.dart' as ui;

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
      name: '検証', position: Position.cm, age: 20, agent: Agent.pool.first);
  return c;
}

Player plain({int condition = 80, int professionalism = 10}) => Player(
      name: 'P',
      age: 21,
      position: Position.cm,
      attributes: Attributes.fromDetails({for (final d in Detail.values) d: 60}),
      potential: 99,
      condition: condition,
      personality: Personality(
        confidence: 10,
        ambition: 10,
        professionalism: professionalism,
        temper: 10,
      ),
    );

/// 同じ条件で何週も回して、伸びた合計を測る。
int grownOver(
  TrainingEffort effort, {
  TrainingCompanion companion = TrainingCompanion.alone,
  int weeks = 1500,
  int seed = 7,
}) {
  final engine = MatchEngine(random: Random(seed));
  var total = 0;
  for (var i = 0; i < weeks; i++) {
    final player = plain();
    final before =
        Detail.values.fold<int>(0, (a, d) => a + player.attributes.detail(d));
    final week = engine.applyWeek(player,
        menu: TrainingMenu.tactical,
        effort: effort,
        companion: companion,
        played: true);
    total +=
        Detail.values.fold<int>(0, (a, d) => a + week.attributes.detail(d)) -
            before;
  }
  return total;
}

void main() {
  group('どこまで踏み込むか', () {
    test('追い込むほど伸びる', () {
      final easy = grownOver(TrainingEffort.easy);
      final normal = grownOver(TrainingEffort.normal);
      final hard = grownOver(TrainingEffort.hard);
      expect(normal, greaterThan(easy));
      expect(hard, greaterThan(normal));
      // 「普通」は今までと同じ重み。ここがずれると既存のバランスが動く。
      expect(hard / normal, lessThan(2.0), reason: '追い込むが強すぎる');
    });

    test('消耗も怪我も、踏み込んだぶんだけ増える', () {
      expect(TrainingEffort.hard.cost,
          greaterThan(TrainingEffort.normal.cost));
      expect(TrainingEffort.easy.cost, lessThan(TrainingEffort.normal.cost));
      expect(TrainingEffort.hard.injury,
          greaterThan(TrainingEffort.normal.injury));
      expect(TrainingEffort.easy.injury,
          lessThan(TrainingEffort.normal.injury));
    });

    test('実際にコンディションが余計に減る', () {
      int conditionAfter(TrainingEffort effort) => MatchEngine(random: Random(1))
          .applyWeek(plain(),
              menu: TrainingMenu.tactical, effort: effort, played: false)
          .condition;

      expect(conditionAfter(TrainingEffort.hard),
          lessThan(conditionAfter(TrainingEffort.normal)));
      expect(conditionAfter(TrainingEffort.easy),
          greaterThan(conditionAfter(TrainingEffort.normal)));
    });

    test('疲れているほど空回りする（追い込むが毎週の正解にならない）', () {
      double flatAt(int condition) => MatchEngine.outcomeOdds(
            effort: TrainingEffort.hard,
            companion: TrainingCompanion.alone,
            condition: condition,
            professionalism: 10,
          ).flat;

      expect(flatAt(30), greaterThan(flatAt(90)));
    });

    test('元気なほど、プロ意識が高いほど大成功しやすい', () {
      double greatAt({int condition = 60, int professionalism = 10}) =>
          MatchEngine.outcomeOdds(
            effort: TrainingEffort.normal,
            companion: TrainingCompanion.alone,
            condition: condition,
            professionalism: professionalism,
          ).great;

      expect(greatAt(condition: 95), greaterThan(greatAt(condition: 40)));
      expect(greatAt(professionalism: 18),
          greaterThan(greatAt(professionalism: 5)));
    });

    test('画面に出す確率と、実際に引く確率が同じ', () {
      // 表示用に別の式を書かない。
      const effort = TrainingEffort.hard;
      final odds = MatchEngine.outcomeOdds(
        effort: effort,
        companion: TrainingCompanion.alone,
        condition: 80,
        professionalism: 10,
      );
      var great = 0;
      const runs = 4000;
      final random = Random(5);
      for (var i = 0; i < runs; i++) {
        if (MatchEngine.rollOutcome(
              random: random,
              effort: effort,
              companion: TrainingCompanion.alone,
              condition: 80,
              professionalism: 10,
            ) ==
            TrainingOutcome.great) {
          great++;
        }
      }
      expect(great / runs, closeTo(odds.great, 0.03));
    });

    test('休養の週には手応えを出さない', () {
      final week = MatchEngine(random: Random(1)).applyWeek(plain(),
          menu: TrainingMenu.rest,
          effort: TrainingEffort.hard,
          played: false);
      expect(week.outcome, isNull);
    });
  });

  group('誰と組むか', () {
    test('組めば手応えが出やすくなる', () {
      for (final companion in TrainingCompanion.values) {
        if (companion == TrainingCompanion.alone) continue;
        expect(companion.greatBonus, greaterThan(0), reason: companion.label);
        // ただで手応えが上がるなら、一人でやる理由が無くなる。
        expect(companion.cost, greaterThan(TrainingCompanion.alone.cost),
            reason: companion.label);
      }
    });

    test('居ない相手とは組めない', () async {
      final c = await started();
      final state = c.state!;
      state.partner = null;
      state.mentor = null;
      state.competitor = null;
      expect(state.companionChoices, [TrainingCompanion.alone]);

      await c.setCompanion(TrainingCompanion.partner);
      expect(state.companion, TrainingCompanion.alone);
    });

    test('相方と組んだ週は、呼吸が深まる', () async {
      final c = await started();
      final state = c.state!;
      state.partner = const Teammate(
          name: '相方', kind: TeammateKind.partner, overall: 70, age: 25,
          synergy: 10);
      await c.setCompanion(TrainingCompanion.partner);
      expect(state.companion, TrainingCompanion.partner);
      await c.simulateMatch();
      expect(state.partner!.synergy, greaterThan(10));
    });

    test('相手が移籍でいなくなったら、黙って一人に戻す', () async {
      final c = await started();
      final state = c.state!;
      state.partner = const Teammate(
          name: '相方', kind: TeammateKind.partner, overall: 70, age: 25);
      await c.setCompanion(TrainingCompanion.partner);
      state.partner = null;
      await c.simulateMatch();
      expect(state.companion, TrainingCompanion.alone,
          reason: '居ない相手と組んだことになっている');
    });
  });

  group('届く高さが変わる', () {
    test('追い込んだ週だけが、限界突破の下地になる', () async {
      final c = await started();
      final state = c.state!;
      final before = state.development.greatWeeks;
      // 追い込み続ければ、いつかは大成功が積み上がる。
      await c.setEffort(TrainingEffort.hard);
      for (var i = 0; i < 20; i++) {
        await c.simulateMatch();
      }
      expect(state.development.greatWeeks, greaterThan(before));
    });

    test('追い込んでいない選手は限界を超えられない', () {
      final engine = CareerEngine(random: Random(1));
      CareerState at(int greatWeeks) {
        final s = engine.startCareer(
            name: 'B',
            position: Position.cm,
            age: 23,
            agent: Agent.pool.first);
        final flat = Attributes.fromDetails(
            {for (final d in Detail.values) d: 70});
        s.player = Player(
          name: 'B',
          age: 23,
          position: Position.cm,
          attributes: flat,
          potential: flat.overallFor(Position.cm),
          personality: const Personality(
              confidence: 10,
              ambition: 10,
              professionalism: 18,
              temper: 10),
        );
        s.development =
            Development(experience: 900, greatWeeks: greatWeeks);
        return s;
      }

      expect(engine.breaksThrough(at(0)), isFalse);
      var happened = false;
      for (var i = 0; i < 60 && !happened; i++) {
        happened = CareerEngine(random: Random(i))
            .breaksThrough(at(Formulas.breakthroughGreatWeeks));
      }
      expect(happened, isTrue);
    });
  });

  group('保存と引き継ぎ', () {
    test('週の設定は保存に乗る', () async {
      final c = await started();
      await c.setEffort(TrainingEffort.hard);
      final json = c.state!.toJson();
      expect(CareerState.fromJson(json).effort, TrainingEffort.hard);
      expect(CareerState.fromJson(json).companion, TrainingCompanion.alone);
    });

    test('週の設定を知らない保存データでも読める', () async {
      final c = await started();
      final json = c.state!.toJson()
        ..remove('effort')
        ..remove('companion')
        ..remove('greatWeeks');
      final back = CareerState.fromJson(json);
      expect(back.effort, TrainingEffort.normal);
      expect(back.companion, TrainingCompanion.alone);
      expect(back.development.greatWeeks, 0);
    });

    test('シーズンを跨いでも設定が残る', () async {
      // ここを渡し忘れると、毎年こっそり「普通・一人」に戻る。
      final c = await started();
      final state = c.state!;
      await c.setEffort(TrainingEffort.hard);
      final engine = CareerEngine(random: Random(1));
      state.results = [];
      final next =
          engine.advanceSeason(state, accepted: engine.renewalOffer(state));
      expect(next.effort, TrainingEffort.hard);
    });
  });

  group('画面から決められる', () {
    testWidgets('踏み込み方をその場で選べて、シートは閉じない', (tester) async {
      final controller = await ui.newCareer();
      await ui.pumpHub(tester, controller, height: 2000);

      await tester.tap(find.text('変える'));
      await tester.pumpAndSettle();
      expect(find.text('踏み込み'), findsOneWidget);

      await tester.tap(find.text(TrainingEffort.hard.label));
      await tester.pumpAndSettle();
      expect(controller.state!.effort, TrainingEffort.hard);
      // 選び直せるように、シートは開いたまま。
      expect(find.text('踏み込み'), findsOneWidget);
      // 大成功・空回りの見込みがその場で出る。
      expect(find.textContaining('大成功'), findsWidgets);
    });
  });
}
