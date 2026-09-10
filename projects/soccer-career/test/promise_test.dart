/// 自分から口にした数字が、シーズンの意味を変えているか。
///
/// 監督の `SeasonObjective` は**向こうから降ってくる数字**で、プレイヤーは
/// 受け取るだけだった。約束は逆に、自分で数字を選ぶ。果たせば信頼と年俸が
/// 乗り、届かなければ両方を失う。
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/data/save_repository.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/game/match_brief.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/game/person.dart';
import 'package:soccer_career/game/promises.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/career.dart';
import 'package:soccer_career/models/objective.dart';
import 'package:soccer_career/models/promise.dart';
import 'package:soccer_career/models/season.dart';
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

Future<CareerController> started({
  int seed = 3,
  Position position = Position.st,
}) async {
  final c = CareerController(
    repository: _MemoryRepository(),
    careerEngine: CareerEngine(random: Random(seed)),
    matchEngine: MatchEngine(random: Random(seed)),
    random: Random(seed),
  );
  await c.startCareer(
      name: '検証', position: position, age: 24, agent: Agent.pool.first);
  return c;
}

void playedWith(CareerState state,
    {required int matchdays, int goals = 0, double rating = 7.0}) {
  state.results = [
    for (var i = 0; i < matchdays; i++)
      MatchResult(
        matchday: i + 1,
        opponentName: state.opponentFor(i + 1).name,
        home: state.isHome(i + 1),
        scored: 1,
        conceded: 0,
        appearance: Appearance.start,
        rating: rating,
        goals: i < goals ? 1 : 0,
        assists: 0,
      ),
  ];
}

void main() {
  group('約束できる場面', () {
    test('目標があり、序盤のうちだけ', () async {
      final c = await started();
      final state = c.state!;
      expect(PromiseOffers.canPromise(state), isTrue);

      // 目標が無ければ約束しようがない。
      state.objective = null;
      expect(PromiseOffers.canPromise(state), isFalse);
    });

    test('終盤には約束できない（後出しにさせない）', () async {
      final c = await started();
      final state = c.state!;
      playedWith(state, matchdays: PromiseOffers.window + 1);
      expect(PromiseOffers.canPromise(state), isFalse);
    });

    test('1シーズンに1つだけ。取り消せない', () async {
      final c = await started();
      final state = c.state!;
      final offers = PromiseOffers.forState(state);
      await c.makePromise(offers.first);
      expect(state.promise, isNotNull);
      expect(PromiseOffers.canPromise(state), isFalse);

      // 2つ目は通らない。
      await c.makePromise(offers.last);
      expect(state.promise!.target, offers.first.target);
    });

    test('口にしたことは記事になる', () async {
      final c = await started();
      final state = c.state!;
      await c.makePromise(PromiseOffers.forState(state).first);
      expect(state.news.first.headline, contains(state.promise!.label));
    });
  });

  group('3つの出方', () {
    test('控えめ・順当・大きく出るの3つ', () async {
      final c = await started();
      final offers = PromiseOffers.forState(c.state!);
      expect(offers.map((o) => o.weight).toSet(), PromiseWeight.values.toSet());
    });

    test('大きく出るほど、見返りも罰も大きい', () {
      for (var i = 1; i < PromiseWeight.values.length; i++) {
        final small = PromiseWeight.values[i - 1];
        final big = PromiseWeight.values[i];
        expect(big.trustKept, greaterThan(small.trustKept));
        expect(big.trustBroken, greaterThan(small.trustBroken));
        expect(big.salaryKept, greaterThan(small.salaryKept));
        expect(big.salaryBroken, lessThan(small.salaryBroken));
      }
    });

    test('前に出るポジションはゴールで大きく出られる', () async {
      final striker = await started(position: Position.st);
      expect(
          PromiseOffers.forState(striker.state!).last.kind, PromiseKind.goals);
      // 後ろの選手にゴール数を約束させても、ただの罰になる。
      final defender = await started(position: Position.cb);
      expect(PromiseOffers.forState(defender.state!).last.kind,
          PromiseKind.contributions);
    });

    test('監督の数字から作る（勝手な数字を出さない）', () async {
      // 難しさの順は実測で決めてある（`test/promise_sim.dart`）。
      // 言葉の響きで並べると、順当が大きく出るより難しくなる。
      final c = await started();
      final state = c.state!;
      final before = PromiseOffers.forState(state).map((o) => o.target).toList();

      // 監督の要求が上がれば、約束の数字も上がる。
      final objective = state.objective!;
      state.objective = SeasonObjective(
        appearances: objective.appearances + 6,
        contributions: objective.contributions + 6,
        rating: objective.rating + 0.5,
      );
      final after = PromiseOffers.forState(state).map((o) => o.target).toList();
      for (var i = 0; i < before.length; i++) {
        expect(after[i], greaterThan(before[i]));
      }
    });

    test('約束したシーズンの年が入る', () async {
      final c = await started();
      for (final offer in PromiseOffers.forState(c.state!)) {
        expect(offer.year, c.state!.year);
      }
    });
  });

  group('清算', () {
    test('果たせば信頼が乗り、破れば失う', () {
      int trustFor({required int goals}) {
        const promise = ManagerPromise(
          kind: PromiseKind.goals,
          target: 10,
          weight: PromiseWeight.bold,
          year: 2030,
        );
        final stats = SeasonStats(
            appearances: 30, goals: goals, assists: 0, averageRating: 7.0);
        return promise.achievedBy(stats)
            ? promise.weight.trustKept
            : -promise.weight.trustBroken;
      }

      expect(trustFor(goals: 10), greaterThan(0));
      expect(trustFor(goals: 3), lessThan(0));
    });

    test('同じ成績でも、約束の有無で信頼が変わる', () async {
      Future<int> managerAfter(ManagerPromise? promise) async {
        final c = await started();
        final state = c.state!;
        playedWith(state, matchdays: 30, goals: 2, rating: 6.6);
        state.promise = promise;
        return Person(random: Random(1)).updateRelations(state).manager;
      }

      final without = await managerAfter(null);
      final broken = await managerAfter(const ManagerPromise(
        kind: PromiseKind.goals,
        target: 20,
        weight: PromiseWeight.bold,
        year: 2030,
      ));
      final kept = await managerAfter(const ManagerPromise(
        kind: PromiseKind.goals,
        target: 2,
        weight: PromiseWeight.bold,
        year: 2030,
      ));
      expect(broken, lessThan(without));
      expect(kept, greaterThan(without));
    });

    test('果たしたシーズンのほうが、契約更改の年俸が高い', () async {
      Future<int> salaryAfter({required bool kept}) async {
        final c = await started();
        final state = c.state!;
        playedWith(state, matchdays: 30, goals: 10, rating: 7.0);
        // 契約が残っているうちは条件が動かない。更改の年に見る。
        state.contractYears = 1;
        state.promise = ManagerPromise(
          kind: PromiseKind.goals,
          target: kept ? 8 : 25,
          weight: PromiseWeight.bold,
          year: state.year,
        );
        return c.renewalOffer!.salary;
      }

      expect(await salaryAfter(kept: true),
          greaterThan(await salaryAfter(kept: false)));
    });

    test('記録に残る', () async {
      final c = await started();
      final state = c.state!;
      playedWith(state, matchdays: state.fixtures.length, goals: 30);
      state.promise = ManagerPromise(
        kind: PromiseKind.goals,
        target: 10,
        weight: PromiseWeight.fair,
        year: state.year,
      );
      final retired = CareerEngine(random: Random(1)).retire(state);
      expect(retired.history.last.promiseLabel, '今季 10 ゴール');
      expect(retired.history.last.promiseKept, isTrue);
    });
  });

  group('約束が見えている', () {
    test('局面の手前に必ず出る', () async {
      final c = await started();
      final state = c.state!;
      await c.makePromise(PromiseOffers.forState(state).first);
      final labels = MatchBrief.of(state).map((l) => l.label).toList();
      expect(labels, contains('約束'));
    });

    test('あと1で届くときだけ、局面の側に出す', () async {
      final c = await started();
      final state = c.state!;
      playedWith(state, matchdays: 20, goals: 9);
      state.promise = ManagerPromise(
        kind: PromiseKind.goals,
        target: 10,
        weight: PromiseWeight.fair,
        year: state.year,
      );
      expect(state.promiseReach, isNotNull);

      // まだ遠いときは出さない。
      state.promise = ManagerPromise(
        kind: PromiseKind.goals,
        target: 20,
        weight: PromiseWeight.fair,
        year: state.year,
      );
      expect(state.promiseReach, isNull);
    });

    test('約束していなければ何も出さない', () async {
      final c = await started();
      expect(c.state!.promiseReach, isNull);
      expect(
          MatchBrief.of(c.state!).map((l) => l.label), isNot(contains('約束')));
    });
  });

  group('画面から約束できる', () {
    testWidgets('カードから選んで、そのまま口にできる', (tester) async {
      final controller = await ui.newCareer();
      await ui.pumpHub(tester, controller, height: 2400);

      expect(find.text('監督に約束するか'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, '約束する'));
      await tester.pumpAndSettle();

      // 3つの出方が並ぶ。どれも効きが書いてある。
      for (final offer in PromiseOffers.forState(controller.state!)) {
        expect(find.text(offer.label), findsOneWidget);
      }
      await tester.tap(find.text(
          PromiseOffers.forState(controller.state!).last.label));
      await tester.pumpAndSettle();

      expect(controller.state!.promise, isNotNull);
      expect(find.text('監督との約束'), findsOneWidget);
      // 言った後は、もう言い直せない。
      expect(find.text('監督に約束するか'), findsNothing);
    });
  });

  group('保存', () {
    test('約束は保存に乗る', () async {
      final c = await started();
      final state = c.state!;
      await c.makePromise(PromiseOffers.forState(state).last);
      final json = state.toJson();
      final back = CareerState.fromJson(json);
      expect(back.promise!.label, state.promise!.label);
      expect(back.promise!.weight, state.promise!.weight);
    });

    test('約束を知らない保存データでも読める', () async {
      final c = await started();
      final json = c.state!.toJson()..remove('promise');
      expect(CareerState.fromJson(json).promise, isNull);
      expect(CareerState.fromJson(json).promiseKept, isNull);
    });

    test('シーズンが変われば約束は消える', () async {
      final c = await started();
      final state = c.state!;
      await c.makePromise(PromiseOffers.forState(state).first);
      playedWith(state, matchdays: state.fixtures.length, goals: 5);
      final engine = CareerEngine(random: Random(1));
      final next =
          engine.advanceSeason(state, accepted: engine.renewalOffer(state));
      expect(next.promise, isNull);
      expect(next.history.last.promiseLabel, isNotNull);
    });
  });
}
