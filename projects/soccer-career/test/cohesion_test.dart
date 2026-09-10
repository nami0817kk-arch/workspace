/// 育てたものが試合のどこで効いているか、今週なにをするか、次に出られるか。
///
/// どれも数字の中に溶けていて画面に出ていなかったもの。
/// 表示のために別の式を書くと、いつか判定とずれる。ここではその一致を縛る。
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/data/save_repository.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/game/formulas.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/game/scenarios.dart';
import 'package:soccer_career/game/weekly_plan.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/career.dart';
import 'package:soccer_career/models/club.dart';
import 'package:soccer_career/models/competition.dart';
import 'package:soccer_career/models/player.dart';
import 'package:soccer_career/models/development.dart';
import 'package:soccer_career/models/injury.dart';
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

CareerController controller({int seed = 3}) => CareerController(
      repository: _MemoryRepository(),
      careerEngine: CareerEngine(random: Random(seed)),
      matchEngine: MatchEngine(random: Random(seed)),
      random: Random(seed),
    );

Future<CareerController> started({
  int seed = 3,
  Position position = Position.st,
  int age = 24,
}) async {
  final c = controller(seed: seed);
  await c.startCareer(
      name: '検証', position: position, age: age, agent: Agent.pool.first);
  return c;
}

void main() {
  group('成功率の内訳', () {
    test('内訳の合計が、判定に使う成功率と一致する', () async {
      // 表示のために別の式を書くと、片方を触ったときに画面が嘘をつく。
      final c = await started(seed: 11);
      for (var i = 0; i < 12; i++) {
        c.startNextMatch();
        final match = c.currentMatch;
        if (match == null) break;
        while (!match.isFinished) {
          for (final option in match.current.options) {
            final sum = match.factorsFor(option).fold<double>(
                match.baseChanceFor(option), (a, f) => a + f.value);
            expect(match.chanceFor(option), closeTo(sum.clamp(0.05, 0.95), 1e-9),
                reason: option.label);
          }
          match.choose(match.current.options.first);
        }
        await c.finishMatch();
      }
    });

    test('共通のものと、その手だけのものに漏れなく分かれる', () async {
      final c = await started(seed: 12);
      c.startNextMatch();
      final match = c.currentMatch!;
      for (final option in match.current.options) {
        final all = match.factorsFor(option).map((f) => f.label).toList();
        final shared = match.sharedFactors.map((f) => f.label).toList();
        final distinct =
            match.distinctFactorsFor(option).map((f) => f.label).toList();
        expect({...shared, ...distinct}, all.toSet());
        expect(shared.toSet().intersection(distinct.toSet()), isEmpty);
      }
      // 相手の格はどの手にも同じだけ効くので、必ず共通側に来る。
      expect(match.sharedFactors.any((f) => f.label.contains('の相手')), isTrue);
    });

    test('覚えた個人技は、それが出る手にだけ名前で出る', () {
      final pool = ScenarioPool.neutralFor(ScenarioFamily.forward);
      final scenario = pool.firstWhere(
          (s) => s.options.any((o) => o.detail == Detail.finishing));
      final option =
          scenario.options.firstWhere((o) => o.detail == Detail.finishing);

      MatchInProgress build(Development development) => MatchInProgress(
            matchday: 1,
            opponent: const Club(
                id: 'x', name: 'X', strength: 60, tier: 1, countryId: 'yamato'),
            home: true,
            appearance: Appearance.start,
            scenarios: [scenario],
            minutes: const [30],
            player: Player(
              name: 'P',
              age: 24,
              position: Position.st,
              attributes: Attributes(
                pace: 70,
                shooting: 70,
                passing: 70,
                dribbling: 70,
                defending: 70,
                physical: 70,
              ),
              potential: 90,
            ),
            club: const Club(
                id: 'm', name: 'M', strength: 60, tier: 1, countryId: 'yamato'),
            development: development,
            random: Random(1),
          );

      final without = build(const Development());
      expect(without.factorsFor(option).any((f) => f.label == '無回転シュート'),
          isFalse);

      // 「無回転シュート」はシュート力の技。決定力の手には同じカテゴリぶんだけ効く。
      final learned = const Development().learn(Signature.knuckle);
      final factors = build(learned).factorsFor(option);
      expect(factors.any((f) => f.label == Signature.knuckle.label), isTrue,
          reason: '同じカテゴリなのに効いていない');
      expect(
        build(learned).chanceFor(option),
        greaterThan(without.chanceFor(option)),
      );
    });
  });

  group('今週なにをするか', () {
    test('離脱中はそれだけを言う', () async {
      final c = await started(seed: 13);
      c.state!.injury = const Injury(
          name: '肉離れ', severity: InjurySeverity.moderate, matchesOut: 5);
      final plan = WeekPlan.of(c.state!);
      expect(plan.focus, WeekFocus.injured);
      expect(plan.reason, contains('5試合'));
      expect(plan.suggested, isNull);
    });

    test('疲れていたら、休むほうを勧める', () async {
      final c = await started(seed: 14);
      c.state!.player =
          c.state!.player.copyWith(condition: WeekPlan.tiredCondition - 5);
      final plan = WeekPlan.of(c.state!);
      expect(plan.focus, WeekFocus.rest);
      expect(plan.suggested, TrainingMenu.lightWork);
      // どれだけ損をするかを数字で書く。
      expect(plan.reason, contains('%'));
    });

    test('平常時は、次の相手の戦い方を出す', () async {
      final c = await started(seed: 15);
      final state = c.state!;
      final opponent = state.opponentFor(state.matchday);
      final plan = WeekPlan.of(state);
      expect(plan.focus, WeekFocus.matchup);
      expect(plan.headline, contains(opponent.name));
      expect(plan.reason, contains(ClubStyle.of(opponent).hardFor.label));
    });

    test('勧める練習は、そのポジションで選べるものに限る', () async {
      // GK 以外に GK 練習を勧めると、押しても何も起きない。
      for (final position in Position.values) {
        final c = await started(seed: 16, position: position);
        final plan = WeekPlan.of(c.state!);
        final menu = plan.suggested;
        if (menu == null) continue;
        expect(menu.availableFor(position), isTrue,
            reason: '$position に ${menu.label} を勧めている');
      }
    });
  });

  group('次に出られるか', () {
    test('離脱・出場停止・登録外は、評価点より先に見る', () async {
      // ここを飛ばしていたので、怪我をしていても「先発の見込み」と出ていた
      // （headline の injured / suspended にそもそも到達しなかった）。
      final c = await started();
      final state = c.state!;

      state.injury = const Injury(
          name: '検証', severity: InjurySeverity.moderate, matchesOut: 5);
      expect(c.outlook!.likely, Appearance.injured);
      expect(c.outlook!.headline, '出られない');
      expect(c.outlook!.reason, contains('離脱'));

      state.injury = null;
      state.suspension = 2;
      expect(c.outlook!.likely, Appearance.suspended);
      expect(c.outlook!.reason, contains('出場停止'));

      state.suspension = 0;
      state.squadStatus = SquadStatus.outOfSquad;
      expect(c.outlook!.likely, Appearance.benched);
      expect(c.outlook!.reason, contains('登録メンバー'));

      state.squadStatus = SquadStatus.registered;
      expect(c.outlook!.likely, isNot(Appearance.injured));
    });

    test('デビュー前は、そう書く', () async {
      final c = await started(seed: 17);
      final outlook = c.outlook!;
      expect(outlook.debut, isTrue);
      expect(outlook.likely, Appearance.start);
      expect(outlook.reason, contains('デビュー'));
    });

    test('見込みが、実際の判定と同じ式から出ている', () async {
      final c = await started(seed: 18);
      for (var i = 0; i < 10; i++) {
        await c.simulateMatch();
      }
      final outlook = c.outlook!;
      expect(outlook.debut, isFalse);
      expect(
        outlook.likely,
        MatchEngine.decideAppearance(c.state!.leagueResults,
            bonus: outlook.bonus),
      );
      // 先発の線を跨いでいるかどうかが、見込みと一致する。
      if (outlook.effective >= Formulas.benchThreshold) {
        expect(outlook.likely, Appearance.start);
      }
      expect(outlook.reason, contains('直近'));
    });

    test('引退後は出さない', () async {
      final c = await started(seed: 19, age: 36);
      while (!c.state!.seasonFinished) {
        await c.simulateMatch();
      }
      await c.finishSeason();
      await c.retire();
      expect(c.outlook, isNull);
    });
  });
}
