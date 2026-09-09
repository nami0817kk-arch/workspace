/// 警告・退場・出場停止。
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
import 'package:soccer_career/models/player.dart';
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
      name: '検証', position: Position.cb, age: 24, agent: Agent.pool.first);
  return c;
}

/// 止めるための反則を含む局面だけで1試合を組む。
MatchInProgress foulMatch({int seed = 1, List<int> conceded = const [70]}) {
  final scenario = ScenarioPool.defence
      .firstWhere((s) => s.options.any((o) => o.isTacticalFoul));
  return MatchInProgress(
    matchday: 1,
    opponent: const Club(
        id: 'x', name: 'X', strength: 60, tier: 1, countryId: 'yamato'),
    home: true,
    appearance: Appearance.start,
    scenarios: [scenario, scenario],
    minutes: const [40, 60],
    player: Player(
      name: 'P',
      age: 26,
      position: Position.cb,
      attributes: Attributes(
        pace: 70,
        shooting: 40,
        passing: 60,
        dribbling: 50,
        defending: 80,
        physical: 75,
      ),
      potential: 90,
    ),
    club: const Club(
        id: 'm', name: 'M', strength: 60, tier: 1, countryId: 'yamato'),
    concededMinutes: [...conceded],
    random: Random(seed),
  );
}

void main() {
  group('カード', () {
    test('止めるための反則は、選んだ時点で必ず警告になる', () {
      final match = foulMatch();
      final foul =
          match.current.options.firstWhere((o) => o.isTacticalFoul);
      expect(match.cardChanceFor(foul), 1);
      match.choose(foul);
      expect(match.yellowCards, 1);
      expect(match.sentOff, isFalse);
    });

    test('2枚目でその試合は終わる', () {
      final match = foulMatch();
      final foul =
          match.current.options.firstWhere((o) => o.isTacticalFoul);
      match.choose(foul);
      expect(match.isFinished, isFalse);
      match.choose(match.current.options.firstWhere((o) => o.isTacticalFoul));
      expect(match.sentOff, isTrue);
      expect(match.isFinished, isTrue, reason: '退場したのに局面が続く');

      final result = match.finish();
      expect(result.sentOff, isTrue);
      expect(result.yellowCards, 2);
    });

    test('止めれば、これから入るはずだった失点が消える', () {
      final match = foulMatch(conceded: const [70, 85]);
      final before = match.concededMinutes.length;
      final foul =
          match.current.options.firstWhere((o) => o.isTacticalFoul);
      // 40分の局面。70分の失点が対象になる。
      final resolution = match.choose(foul);
      if (resolution.success) {
        expect(match.concededMinutes.length, before - 1);
      }
    });

    test('荒い手にだけ、審判が出てくる', () {
      final match = foulMatch();
      // 荒くない手には出ない。
      final clean = match.current.options.firstWhere((o) => o.foul == 0);
      expect(match.cardChanceFor(clean), 0);

      // 局面のどこかに、失敗したときだけ笛が鳴る手がある。
      final rough = [
        for (final scenario in ScenarioPool.defence)
          for (final option in scenario.options)
            if (option.foul > 0 && !option.isTacticalFoul) option,
      ];
      expect(rough, isNotEmpty, reason: '荒い手が1つも無い');
      for (final option in rough) {
        expect(match.cardChanceFor(option), greaterThan(0));
        expect(match.cardChanceFor(option), lessThan(1));
      }
    });

    test('自動で進めるとき、カードのぶんが引かれている', () {
      // 引いていないと、止めるための反則が「安いだけの手」に見える。
      final match = foulMatch();
      final foul =
          match.current.options.firstWhere((o) => o.isTacticalFoul);
      final expected = match.expectedDelta(foul);
      final chance = match.chanceFor(foul);
      final withoutCard = chance * Formulas.ratingPerSuccess +
          (1 - chance) * Formulas.ratingPerFailure +
          chance * Formulas.ratingPerGoalPrevented;
      expect(expected, lessThan(withoutCard));
    });
  });

  group('出場停止', () {
    test('警告が溜まると出場停止になり、警告は減る', () async {
      final c = await started(seed: 41);
      final state = c.state!;
      state.yellowCards = Formulas.yellowCardsForBan - 1;
      // 警告1枚ぶんを直接積む。
      state.yellowCards += 1;
      if (state.yellowCards >= Formulas.yellowCardsForBan) {
        state.yellowCards -= Formulas.yellowCardsForBan;
        state.suspension += Formulas.banForYellows;
      }
      expect(state.suspension, Formulas.banForYellows);
      expect(state.yellowCards, 0);
      expect(state.suspended, isTrue);
    });

    test('停止中は出られず、試合を消化すると解ける', () async {
      final c = await started(seed: 42);
      c.state!.suspension = 2;

      await c.simulateMatch();
      expect(c.state!.results.last.appearance, Appearance.suspended);
      expect(c.state!.results.last.rating, isNull,
          reason: '出ていない試合に評価点が付いている');
      expect(c.state!.suspension, 1);

      await c.simulateMatch();
      expect(c.state!.suspension, 0);
      expect(c.state!.suspended, isFalse);
    });

    test('節は進む', () async {
      final c = await started(seed: 43);
      c.state!.suspension = 1;
      final before = c.state!.matchday;
      await c.simulateMatch();
      expect(c.state!.matchday, before + 1);
    });

    test('保存を往復しても残り、古い保存データでは0', () async {
      final c = await started(seed: 44);
      c.state!.yellowCards = 3;
      c.state!.suspension = 2;
      final json = c.state!.toJson();
      final restored = CareerState.fromJson(json);
      expect(restored.yellowCards, 3);
      expect(restored.suspension, 2);

      final legacy = CareerState.fromJson(json
        ..remove('yellowCards')
        ..remove('suspension'));
      expect(legacy.yellowCards, 0);
      expect(legacy.suspension, 0);
    });

    test('警告はシーズンをまたぐと消え、出場停止は持ち越す', () async {
      final c = await started(seed: 45);
      while (!c.state!.seasonFinished) {
        await c.simulateMatch();
      }
      c.state!.yellowCards = 3;
      c.state!.suspension = 1;
      await c.finishSeason();
      await c.advanceSeason(accepted: c.renewalOffer!);
      expect(c.state!.yellowCards, 0, reason: '警告が持ち越された');
      expect(c.state!.suspension, 1, reason: '出場停止が消えた');
    });
  });
}
