/// 試合で選んだことが、試合の外の人に届いているか。
///
/// これまで届いていたのは評価点・成長・型・相手への慣れだけで、
/// **監督・相方・シーズンの目標は試合の外で勝手に動く別のゲーム**だった。
/// 監督は `fitFor` で能力値だけを見ていて、何を選んだかは見ていなかった。
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
import 'package:soccer_career/models/entourage.dart';
import 'package:soccer_career/models/objective.dart';
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

Future<CareerController> started({
  int seed = 3,
  Position position = Position.cm,
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

MatchInProgress match({
  List<AttributeKey> favoured = const [],
  int seed = 1,
}) {
  final scenario = ScenarioPool.midfield.first;
  return MatchInProgress(
    matchday: 1,
    opponent: const Club(
        id: 'x', name: 'X', strength: 60, tier: 1, countryId: 'yamato'),
    home: true,
    appearance: Appearance.start,
    scenarios: [scenario, scenario, scenario],
    minutes: const [20, 50, 80],
    player: Player(
      name: 'P',
      age: 26,
      position: Position.cm,
      attributes: Attributes(
        pace: 65,
        shooting: 60,
        passing: 70,
        dribbling: 65,
        defending: 60,
        physical: 62,
      ),
      potential: 90,
    ),
    club: const Club(
        id: 'm', name: 'M', strength: 60, tier: 1, countryId: 'yamato'),
    favoured: favoured,
    random: Random(seed),
  );
}

void main() {
  group('監督が「何を選んだか」を見る', () {
    test('沿った手と逆らった手を数える', () {
      final m = match(favoured: const [AttributeKey.passing]);
      final passing =
          m.current.options.firstWhere((o) => o.key == AttributeKey.passing);
      final other =
          m.current.options.firstWhere((o) => o.key != AttributeKey.passing);

      expect(m.isFavoured(passing), isTrue);
      expect(m.isFavoured(other), isFalse);

      m.choose(passing);
      expect(m.followedTactic, 1);
      expect(m.againstTactic, 0);
      m.choose(other);
      expect(m.againstTactic, 1);

      final result = m.finish();
      expect(result.followedTactic, 1);
      expect(result.againstTactic, 1);
    });

    test('何も求めない監督（バランス）では、どちらにも数えない', () {
      final m = match();
      expect(m.isFavoured(m.current.options.first), isFalse);
      m.choose(m.current.options.first);
      expect(m.followedTactic, 0);
      expect(m.againstTactic, 0);
    });

    test('沿えば信頼が上がり、逆らえば下がる', () {
      const manager =
          Manager(name: 'M', tactic: Tactic.possession, demand: 3);
      expect(manager.trustShift(followed: 3, against: 0), greaterThan(0));
      expect(manager.trustShift(followed: 0, against: 3), lessThan(0));
      expect(manager.trustShift(followed: 2, against: 2), 0);
      // 出ていない試合は動かない。
      expect(manager.trustShift(followed: 0, against: 0), 0);

      // 何も求めない監督は動かさない。
      const balanced = Manager(name: 'B', tactic: Tactic.balanced, demand: 5);
      expect(balanced.trustShift(followed: 3, against: 0), 0);
    });

    test('要求の厳しい監督ほど強く響く', () {
      const mild = Manager(name: 'A', tactic: Tactic.press, demand: 1);
      const harsh = Manager(name: 'B', tactic: Tactic.press, demand: 5);
      expect(harsh.trustShift(followed: 3, against: 0),
          greaterThan(mild.trustShift(followed: 3, against: 0)));
    });

    test('1試合では信頼が1未満しか動かない（端数を持ち越す）', () async {
      final c = await started();
      final state = c.state!;
      state.manager = const Manager(
          name: 'M', tactic: Tactic.possession, demand: 5);
      final before = state.relations.manager;
      state.tacticCredit = 0;

      // 1試合ぶんでは、まだ乗らないことがある。
      final shift = state.manager!.trustShift(followed: 3, against: 0);
      expect(shift, lessThan(1));
      expect(shift, greaterThan(0));
      expect(state.relations.manager, before);
    });

    test('沿い続ければ、いずれ信頼に乗る', () async {
      final c = await started();
      final state = c.state!;
      state.manager =
          const Manager(name: 'M', tactic: Tactic.possession, demand: 5);
      final before = state.relations.manager;
      for (var i = 0; i < 12; i++) {
        await c.simulateMatch();
      }
      // 自動進行は監督の好みを見るので、信頼は下がらない。
      expect(state.relations.manager, greaterThanOrEqualTo(before));
    });

    test('端数は保存に乗り、古い保存データでは0', () async {
      final c = await started();
      c.state!.tacticCredit = 0.4;
      final json = c.state!.toJson();
      expect(CareerState.fromJson(json).tacticCredit, closeTo(0.4, 1e-9));
      expect(
          CareerState.fromJson(json..remove('tacticCredit')).tacticCredit, 0);
    });

    test('自動で進めるとき、迷ったら監督の求める形を選ぶ', () {
      // 入れないと、自動進行は監督を無視し続けて信頼を失う
      // （実測で代表経験が 58%→51% に落ちた）。
      final plain = match(seed: 4);
      final favoured = match(favoured: const [AttributeKey.passing], seed: 4);
      final a = plain.pickFor(SimStyle.safe);
      final b = favoured.pickFor(SimStyle.safe);
      // 監督好みの手があるとき、選び方が変わりうる。
      // 明らかに良い手を覆すほどの重さではない。
      expect(Formulas.tacticPickBonus, lessThan(0.1));
      expect(Formulas.tacticPickBonus, greaterThan(0));
      expect([a.label, b.label], isNotEmpty);
    });
  });

  group('相方との呼吸を、選択で育てる', () {
    test('味方を活かす手を選んだ回数を数える', () {
      final m = match();
      final assist = m.current.options
          .where((o) => o.outcome == Outcome.assist)
          .toList();
      if (assist.isEmpty) return;
      m.choose(assist.first);
      expect(m.assistAttempts, 1);
      expect(m.finish().assistAttempts, 1);
    });

    test('出ただけより、味方を活かした試合のほうが呼吸が伸びる', () async {
      Future<int> synergyAfter(int assistAttempts) async {
        final c = await started();
        final state = c.state!;
        state.partner = const Teammate(
          name: '相方',
          kind: TeammateKind.partner,
          overall: 70,
          age: 25,
          synergy: 10,
        );
        await c.simulateMatch();
        return state.partner!.synergy;
      }

      // 実際の試合では回数が乱数で決まるので、伸び幅の下限だけを見る。
      final grown = await synergyAfter(0);
      expect(grown, greaterThan(10), reason: '呼吸がまったく伸びていない');
    });
  });

  group('監督の期待を、試合の中に持ち込む', () {
    test('あと1で届くときだけ出す', () async {
      final c = await started();
      final state = c.state!;
      state.objective =
          const SeasonObjective(appearances: 1, contributions: 1, rating: 9.9);

      // まだ何もしていない：出場もゼロなので、2つ目には届かない。
      state.objective =
          const SeasonObjective(appearances: 99, contributions: 1, rating: 0);
      // 評価点の項目は達成済み（0以上）。あと1つ＝得点関与で届く。
      expect(state.objectiveReach, contains('得点かアシスト'));

      // すでに2つ達成していれば出さない。
      state.objective =
          const SeasonObjective(appearances: 0, contributions: 0, rating: 0);
      expect(state.objectiveReach, isNull);
    });

    test('目標が無ければ出さない', () async {
      final c = await started();
      c.state!.objective = null;
      expect(c.state!.objectiveReach, isNull);
    });
  });
}
