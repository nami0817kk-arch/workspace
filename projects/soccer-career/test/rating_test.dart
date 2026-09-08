/// 評価点の付き方と、休養とリカバリーの違い。
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/data/save_repository.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/game/formulas.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/game/scenarios.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/career.dart';
import 'package:soccer_career/models/club.dart';
import 'package:soccer_career/models/life.dart';
import 'package:soccer_career/models/player.dart';
import 'package:soccer_career/models/season.dart';
import 'package:soccer_career/models/training.dart';
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

MatchInProgress forwardMatch(int seed) {
  final scenario = ScenarioPool.forward
      .firstWhere((s) => s.options.any((o) => o.outcome == Outcome.goal));
  return MatchInProgress(
    matchday: 1,
    opponent: const Club(
        id: 'x', name: 'X', strength: 60, tier: 1, countryId: 'yamato'),
    home: true,
    appearance: Appearance.start,
    scenarios: [scenario],
    minutes: const [40],
    player: Player(
      name: 'P',
      age: 26,
      position: Position.st,
      attributes: Attributes(
        pace: 70,
        shooting: 75,
        passing: 60,
        dribbling: 65,
        defending: 30,
        physical: 65,
      ),
      potential: 90,
    ),
    club: const Club(
        id: 'm', name: 'M', strength: 60, tier: 1, countryId: 'yamato'),
    random: Random(seed),
  );
}

void main() {
  group('決定機', () {
    test('ゴールの手が通れば、決まらなくても無難な手より高くつく', () {
      var successes = 0;
      var missed = 0;
      for (var seed = 0; seed < 300; seed++) {
        final m = forwardMatch(seed);
        final goal =
            m.current.options.firstWhere((o) => o.outcome == Outcome.goal);
        final r = m.choose(goal);
        if (!r.success) continue;
        successes++;
        if (!r.isGoal) missed++;
        expect(
            r.ratingDelta,
            greaterThanOrEqualTo(
                Formulas.ratingPerSuccess + Formulas.ratingPerChance - 1e-9),
            reason: 'seed $seed');
      }
      expect(successes, greaterThan(50));
      expect(missed, greaterThan(10), reason: '決まらなかった手が無い');
    });

    test('自動で進めるときの物差しにも入っている', () {
      final m = forwardMatch(1);
      final goal =
          m.current.options.firstWhere((o) => o.outcome == Outcome.goal);
      final p = m.chanceFor(goal);
      final expected = p *
              (Formulas.ratingPerSuccess +
                  Formulas.ratingPerChance +
                  Formulas.ratingPerGoal * Formulas.goalConversion) +
          (1 - p) * Formulas.ratingPerFailure;
      expect(m.expectedDelta(goal), closeTo(expected, 1e-9));
    });
  });

  group('休養とリカバリー', () {
    test('休養は溜まった疲労を抜き、リカバリーは抜かない', () async {
      Future<int> after(TrainingMenu menu) async {
        final c = await started(seed: 7);
        c.state!.fatigue = const Fatigue(value: 50);
        c.state!.autoRestBelow = 0;
        await c.setMenu(menu);
        await c.simulateMatch();
        return c.state!.fatigue.value;
      }

      final rested = await after(TrainingMenu.rest);
      final light = await after(TrainingMenu.lightWork);
      expect(rested, light - Formulas.restFatigueRelief);
    });

    test('自動で休んだ週も疲労が抜ける', () async {
      Future<int> after(int autoRestBelow) async {
        final c = await started(seed: 8);
        c.state!.fatigue = const Fatigue(value: 50);
        c.state!.player = c.state!.player.copyWith(condition: 20);
        c.state!.autoRestBelow = autoRestBelow;
        await c.setMenu(TrainingMenu.tactical);
        await c.simulateMatch();
        return c.state!.fatigue.value;
      }

      expect(await after(40), await after(0) - Formulas.restFatigueRelief);
    });
  });
}
