import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/game/formulas.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/game/scenarios.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/club.dart';
import 'package:soccer_career/models/player.dart';
import 'package:soccer_career/models/season.dart';

final flat = Attributes(
  pace: 70,
  shooting: 70,
  passing: 70,
  dribbling: 70,
  defending: 70,
  physical: 70,
  goalkeeping: 70,
);

Player player({Position position = Position.st}) => Player(
      name: 'P',
      age: 24,
      position: position,
      attributes: flat,
      potential: 90,
    );

Club club(String id, {int strength = 60}) =>
    Club(id: id, name: id, strength: strength, tier: 1, countryId: 'yamato');

MatchInProgress match({
  required List<int> minutes,
  List<int> teammateGoals = const [],
  List<int> conceded = const [],
  int seed = 1,
  Position position = Position.st,
}) {
  final scenarios =
      ScenarioPool.forPosition(position).take(minutes.length).toList();
  return MatchInProgress(
    matchday: 1,
    opponent: club('rival'),
    home: true,
    appearance: Appearance.start,
    scenarios: scenarios,
    minutes: minutes,
    player: player(position: position),
    club: club('mine'),
    teammateGoalMinutes: teammateGoals,
    concededMinutes: conceded,
    random: Random(seed),
  );
}

void main() {
  group('試合中のスコア', () {
    test('得点の時間は試合の前に決まっていて、時間とともに増える', () {
      final m = match(
        minutes: const [10, 50, 80],
        teammateGoals: const [20, 70],
        conceded: const [40],
      );
      expect(m.scoredBy(5), 0);
      expect(m.concededBy(5), 0);
      expect(m.scoredBy(30), 1);
      expect(m.concededBy(45), 1);
      expect(m.scoredBy(90), 2);
    });

    test('今の局面の時点のスコアが読める', () {
      final m = match(
        minutes: const [10, 50, 80],
        teammateGoals: const [20],
        conceded: const [40, 60],
      );
      expect(m.scoreLine, '0 - 0');
      m.choose(m.current.options.first);
      // 50分の時点では 1 - 1。
      expect(m.scoreLine, '1 - 1');
      expect(m.margin, 0);
    });

    test('終盤の状況が言葉になる', () {
      final early = match(minutes: const [10, 20, 30], conceded: const [5]);
      expect(early.situationLabel, isNull, reason: '序盤は状況を出さない');

      final late = match(
        minutes: const [80, 85, 88],
        conceded: const [5, 15],
        teammateGoals: const [30],
      );
      expect(late.lateGame, isTrue);
      expect(late.margin, -1);
      expect(late.situationLabel, contains('ビハインド'));
    });

    test('自分の得点はスコアに乗る', () {
      // 何度か試して、1点入ったところで確かめる。
      for (var seed = 0; seed < 40; seed++) {
        final m = match(minutes: const [10, 50, 80], seed: seed);
        final goalOption = m.current.options
            .where((o) => o.outcome == Outcome.goal)
            .toList();
        if (goalOption.isEmpty) continue;
        m.choose(goalOption.first);
        if (m.goals == 1) {
          expect(m.scoredBy(90), 1);
          expect(m.ownGoalMinutes.single, 10);
          final result = m.finish();
          expect(result.scored, greaterThanOrEqualTo(1));
          expect(result.goals, 1);
          return;
        }
      }
      fail('40回試して1点も入らなかった');
    });

    test('スコアは味方の得点と自分の得点の合計', () {
      final m = match(
        minutes: const [10, 50, 80],
        teammateGoals: const [20, 70],
        conceded: const [40],
      );
      m.autoPlay(SimStyle.safe);
      final result = m.finish();
      expect(result.scored, 2 + result.goals);
      expect(result.conceded, 1);
    });
  });

  group('決勝点', () {
    test('追いつく・突き放す得点は、同じ得点でも評価点が高い', () {
      // 同じ種・同じ手で、時間とスコアだけを変えて比べる。
      double ratingFor({required bool decisive}) {
        for (var seed = 0; seed < 60; seed++) {
          final early = match(
            minutes: const [10, 20, 30],
            conceded: const [5],
            seed: seed,
          );
          final late = match(
            minutes: const [80, 85, 88],
            conceded: const [5],
            seed: seed,
          );
          final target = decisive ? late : early;
          final goals =
              target.current.options.where((o) => o.outcome == Outcome.goal);
          if (goals.isEmpty) continue;
          final before = target.goals;
          target.choose(goals.first);
          if (target.goals > before) return target.rating;
        }
        fail('得点する組み合わせが見つからなかった');
      }

      expect(Formulas.decisiveGoalFactor, greaterThan(1.0));
      expect(ratingFor(decisive: true), greaterThan(ratingFor(decisive: false)));
    });
  });

  group('局面の数', () {
    test('どのポジションも12以上の局面から引く', () {
      for (final family in ScenarioFamily.values) {
        final pool = ScenarioPool.forFamily(family);
        expect(pool.length, greaterThanOrEqualTo(12),
            reason: '$family の局面が少ない');
        // IDが重複していない。
        expect(pool.map((s) => s.id).toSet().length, pool.length);
      }
    });

    test('局面はどれも3つの手を持ち、判定に使う能力が揃っている', () {
      for (final family in ScenarioFamily.values) {
        for (final scenario in ScenarioPool.forFamily(family)) {
          expect(scenario.options.length, 3, reason: scenario.id);
          for (final option in scenario.options) {
            expect(option.detail?.category ?? option.key, option.key,
                reason: '${scenario.id} の「${option.label}」');
            // 一番易しい手（30台）から、一番難しい手（80手前）まで。
            expect(option.difficulty, inInclusiveRange(25, 85));
            expect(option.successText, isNotEmpty);
            expect(option.failureText, isNotEmpty);
          }
        }
      }
    });
  });
}
