import 'dart:convert';
import 'dart:math';

import 'package:baseball_manager/game/career.dart';
import 'package:baseball_manager/game/game.dart';
import 'package:baseball_manager/game/goals.dart';
import 'package:baseball_manager/game/life.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:baseball_manager/game/records.dart';
import 'package:baseball_manager/game/season.dart';
import 'package:flutter_test/flutter_test.dart';

SeasonRecord _rec(
        {Line line = const Line(),
        int roundsWon = 0,
        int rounds = 5,
        int? rank}) =>
    SeasonRecord(
        age: 20,
        stage: Stage.pro,
        line: line,
        roundsWon: roundsWon,
        rounds: rounds,
        rank: rank);

void main() {
  group('目標の文面と判定', () {
    test('各種類の文面', () {
      expect(Goal(GoalKind.rounds, 3).text, '夏の大会で3勝以上');
      expect(Goal(GoalKind.rank, 2).text, '2位以内');
      expect(Goal(GoalKind.battingAverage, 0.28).text, '打率.280以上');
      expect(Goal(GoalKind.homeRuns, 25).text, '本塁打25本以上');
      expect(Goal(GoalKind.era, 3.5).text, '防御率3.50以下');
      expect(Goal(GoalKind.wins, 12).text, '12勝以上');
    });

    test('判定: 届いたら達成、届かなければ未達(境目は達成)', () {
      expect(Goal(GoalKind.rounds, 3).judge(_rec(roundsWon: 3)), isTrue);
      expect(Goal(GoalKind.rounds, 3).judge(_rec(roundsWon: 2)), isFalse);
      expect(Goal(GoalKind.rank, 3).judge(_rec(rank: 3)), isTrue);
      expect(Goal(GoalKind.rank, 3).judge(_rec(rank: 4)), isFalse);
      expect(Goal(GoalKind.rank, 3).judge(_rec()), isFalse); // 順位の無い年
      const bat = Line(atBats: 100, hits: 30, homeRuns: 12);
      expect(
          Goal(GoalKind.battingAverage, 0.300).judge(_rec(line: bat)), isTrue);
      expect(
          Goal(GoalKind.battingAverage, 0.301).judge(_rec(line: bat)), isFalse);
      expect(Goal(GoalKind.homeRuns, 12).judge(_rec(line: bat)), isTrue);
      const pit = Line(faced: 100, outs: 60, runsRaw: -2, wins: 5); // 防御率 3.60
      expect(Goal(GoalKind.era, 3.6).judge(_rec(line: pit)), isTrue);
      expect(Goal(GoalKind.era, 3.0).judge(_rec(line: pit)), isFalse);
      expect(Goal(GoalKind.era, 9.0).judge(_rec()), isFalse); // 投げていない年
      expect(Goal(GoalKind.wins, 5).judge(_rec(line: pit)), isTrue);
    });

    test('保存して読み直せる。壊れた・古い値は無視', () {
      final g = Goal(GoalKind.era, 3.45, achieved: true);
      final q = Goal.fromJson(jsonDecode(jsonEncode(g.toJson())));
      expect((q!.kind, q.target, q.achieved), (GoalKind.era, 3.45, true));
      expect(Goal.fromJson(null), isNull);
      expect(Goal.fromJson({'kind': 'zzz'}), isNull);
      expect(Goal.fromJson({'kind': 'rank'})!.target, 1);
    });

    test('ごほうびは、どの段階でも正の値。プロは能力の伸びが小さいので、高校より少ない(全体のバランスのため)', () {
      for (final st in [
        Stage.youth,
        Stage.juniorHigh,
        Stage.highSchool,
        Stage.pathChoice,
        Stage.pro
      ]) {
        expect(goalRewardExp(st), greaterThan(0), reason: st.name);
      }
      expect(
          goalRewardExp(Stage.pro), lessThan(goalRewardExp(Stage.highSchool)));
      expect(goalRewardExp(Stage.retired), 0);
    });
  });

  group('目標の決め方', () {
    test('アマチュア: 回戦は1以上で全体の回戦数以下。投手は打率の目標にならない', () {
      for (final ov in [10.0, 40.0, 70.0, 95.0]) {
        for (var i = 0; i < 20; i++) {
          final g = makeGoal(
              stage: Stage.highSchool,
              role: Role.pitcher,
              ov: ov,
              rounds: 5,
              pick: i / 20);
          expect(g.kind, GoalKind.rounds);
          expect(g.target, inInclusiveRange(1, 5));
        }
      }
      final bats = {
        for (var i = 0; i < 20; i++)
          makeGoal(
                  stage: Stage.youth,
                  role: Role.batter,
                  ov: 50,
                  rounds: 4,
                  pick: i / 20)
              .kind,
      };
      expect(bats, {GoalKind.rounds, GoalKind.battingAverage});
    });

    test('強い選手ほど高い目標', () {
      int rounds(double ov) => makeGoal(
              stage: Stage.highSchool,
              role: Role.pitcher,
              ov: ov,
              rounds: 6,
              pick: 0)
          .target
          .round();
      expect(rounds(80), greaterThan(rounds(20)));
      double avg(double ov) => makeGoal(
              stage: Stage.pro,
              role: Role.batter,
              ov: ov,
              rounds: 5,
              pick: 0.40)
          .target; // 打率の目標
      expect(avg(90), greaterThan(avg(40)));
    });

    test('プロ: 役割に合う目標だけ(打者に防御率は出ない、投手に打率は出ない)', () {
      final bat = {
        for (var i = 0; i < 40; i++)
          makeGoal(
                  stage: Stage.pro,
                  role: Role.batter,
                  ov: 60,
                  rounds: 5,
                  pick: i / 40)
              .kind,
      };
      expect(bat, {GoalKind.rank, GoalKind.battingAverage, GoalKind.homeRuns});
      final pit = {
        for (var i = 0; i < 40; i++)
          makeGoal(
                  stage: Stage.pro,
                  role: Role.pitcher,
                  ov: 60,
                  rounds: 5,
                  pick: i / 40)
              .kind,
      };
      expect(pit, {GoalKind.rank, GoalKind.era, GoalKind.wins});
      final two = {
        for (var i = 0; i < 60; i++)
          makeGoal(
                  stage: Stage.pro,
                  role: Role.twoWay,
                  ov: 60,
                  rounds: 5,
                  pick: i / 60)
              .kind,
      };
      expect(two.length, 5);
    });

    test('プロの目標は、どの強さでも「届くか届かないか」の範囲(達成率 2〜8割)', () {
      Player mk(Role r, int v) => Player(
          name: 't',
          role: r,
          age: 26,
          potential: 50,
          abilities: {for (final a in abilitiesOf(r)) a: v});
      for (final v in [45, 60, 75, 90]) {
        for (final role in [Role.batter, Role.pitcher]) {
          final kinds = role == Role.batter
              ? [GoalKind.rank, GoalKind.battingAverage, GoalKind.homeRuns]
              : [GoalKind.rank, GoalKind.era, GoalKind.wins];
          for (var k = 0; k < kinds.length; k++) {
            final goal = makeGoal(
                stage: Stage.pro,
                role: role,
                ov: v.toDouble(),
                rounds: 5,
                pick: (k + 0.5) / kinds.length);
            expect(goal.kind, kinds[k]);
            var ok = 0;
            const n = 150;
            for (var s = 0; s < n; s++) {
              final ls = playLeagueSeason(mk(role, v),
                  teamLevel: 65,
                  opponents: const [55, 60, 66, 72, 78],
                  rng: Random(s));
              final r = SeasonRecord(
                  age: 26, stage: Stage.pro, line: ls.line, rank: ls.rank);
              if (goal.judge(r)) ok++;
            }
            expect(ok / n, inInclusiveRange(0.02, 0.85),
                reason:
                    '能力$v ${role.name} ${goal.text}: ${(100 * ok / n).round()}%');
          }
        }
      }
    });
  });

  group('ゲームの中の目標', () {
    Game start() => Game.newGame(
        name: 't', role: Role.batter, rng: Random(2), potential: 70);
    void tournamentYear(Game g) {
      var guard = 0;
      while (g.records.isEmpty) {
        if (++guard > 20) fail('大会が進まない');
        g.phase == Phase.event
            ? g.resolveEvent(0)
            : g.choose(Plan.rest, Ability.contact);
      }
    }

    test('始まりから目標がある。大会で判定される', () {
      final g = start();
      expect(g.goal, isNotNull);
      expect(g.goal!.achieved, isNull);
      tournamentYear(g);
      expect(g.goal!.achieved, isNotNull);
    });

    test('達成: 経験点と気持ちがもらえ、ログに残る(1回だけ)', () {
      final g = start()..goal = Goal(GoalKind.rounds, 0);
      final before = g.exp.total;
      tournamentYear(g);
      expect(g.goal!.achieved, isTrue);
      expect(g.exp.total - before,
          greaterThanOrEqualTo(goalRewardExp(Stage.youth) * 3));
      expect(g.log.where((l) => l.contains('目標') && l.contains('達成')),
          hasLength(1));
    });

    test('未達: 気持ちが少し下がるだけ', () {
      final a = start()..goal = Goal(GoalKind.rounds, 99);
      final b = start()..goal = Goal(GoalKind.rounds, 0);
      tournamentYear(a);
      tournamentYear(b);
      expect(a.goal!.achieved, isFalse);
      expect(a.condition.morale, lessThan(b.condition.morale));
      expect(a.log.any((l) => l.contains('届かなかった')), isTrue);
    });

    test('年が変わると新しい目標になり、未判定に戻る', () {
      final g = start();
      var guard = 0;
      final first = g.goal;
      while (g.player.age == startAge) {
        if (++guard > 40) fail('年が進まない');
        g.phase == Phase.event
            ? g.resolveEvent(0)
            : g.choose(Plan.rest, Ability.contact);
      }
      expect(identical(g.goal, first), isFalse);
      expect(g.goal!.achieved, isNull);
    });

    test('保存して読み直せる。古いセーブ(目標なし)でも遊べる', () {
      final g = start();
      final q = Game.fromJson(
          jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>,
          Random(1));
      expect(q.goal!.text, g.goal!.text);
      final old = Game.fromJson(g.toJson()..remove('goal'), Random(1));
      expect(old.goal, isNull);
      var guard = 0;
      while (old.player.age == startAge) {
        if (++guard > 40) fail('年が進まない');
        old.phase == Phase.event
            ? old.resolveEvent(0)
            : old.choose(Plan.rest, Ability.contact);
      }
      expect(old.goal, isNotNull); // 次の年から目標がつく
    });
  });

  group('目標のむずかしさ', () {
    final base = <Goal>[
      Goal(GoalKind.rounds, 3),
      Goal(GoalKind.rank, 3),
      Goal(GoalKind.battingAverage, 0.280),
      Goal(GoalKind.homeRuns, 20),
      Goal(GoalKind.era, 3.50),
      Goal(GoalKind.wins, 12),
    ];

    bool harderOrEqual(Goal hard, Goal easy) => switch (hard.kind) {
          GoalKind.rank || GoalKind.era => hard.target <= easy.target,
          _ => hard.target >= easy.target,
        };

    test('やさしい < ふつう < むずかしい(目標の値が動く)。ふつうは元のまま', () {
      for (final g in base) {
        final e = g.withLevel(0, maxRounds: 5);
        final n = g.withLevel(1, maxRounds: 5);
        final h = g.withLevel(2, maxRounds: 5);
        expect(n.target, g.target, reason: g.kind.name);
        expect(harderOrEqual(n, e), isTrue, reason: g.kind.name);
        expect(harderOrEqual(h, n), isTrue, reason: g.kind.name);
        expect(h.target == e.target, isFalse, reason: g.kind.name);
        expect([e.level, n.level, h.level], [0, 1, 2]);
        // 元の値を覚えているので、選び直しても元に戻れる
        expect(h.withLevel(1, maxRounds: 5).target, g.target);
        expect(e.withLevel(2, maxRounds: 5).target, h.target);
      }
    });

    test('上限・下限を超えない(回戦数・順位・打率・防御率)', () {
      expect(Goal(GoalKind.rounds, 5).withLevel(2, maxRounds: 5).target, 5);
      expect(Goal(GoalKind.rounds, 1).withLevel(0, maxRounds: 5).target, 1);
      expect(Goal(GoalKind.rank, 1).withLevel(2).target, 1);
      expect(Goal(GoalKind.rank, 6).withLevel(0).target, 6);
      expect(Goal(GoalKind.era, 1.6).withLevel(2).target, 1.5);
      expect(Goal(GoalKind.homeRuns, 1).withLevel(0).target, 1);
    });

    test('ごほうびは むずかしいほど大きい(経験点・気持ち)', () {
      for (final st in [Stage.youth, Stage.highSchool, Stage.pro]) {
        expect(goalExpFor(st, 0), lessThan(goalExpFor(st, 1)));
        expect(goalExpFor(st, 1), lessThan(goalExpFor(st, 2)));
        expect(goalExpFor(st, 1), goalRewardExp(st)); // ふつうは従来どおり
      }
      expect(goalMoraleReward[1], goalRewardMorale);
      expect(goalMoraleMiss[1], goalMissMorale);
      expect(goalMoraleReward[0], lessThan(goalMoraleReward[2]));
      expect(goalMoraleMiss[2], lessThan(goalMoraleMiss[0])); // 失敗の痛手も大きい
    });

    test('保存して読み直せる。古い保存(levelなし)はふつう', () {
      final g = Goal(GoalKind.wins, 12).withLevel(2);
      final back = Goal.fromJson(jsonDecode(jsonEncode(g.toJson())))!;
      expect(back.level, 2);
      expect(back.target, 15);
      expect(back.baseTarget, 12);
      final old = Goal.fromJson({'kind': 'wins', 'target': 12.0})!;
      expect(old.level, 1);
      expect(old.baseTarget, 12);
    });

    test('達成しやすさ: やさしい > ふつう > むずかしい(実際のシーズンで確かめる)', () {
      final p = Player(
          name: 't',
          role: Role.batter,
          age: 26,
          potential: 50,
          abilities: {for (final a in batterAbilities) a: 65});
      final goals = [
        Goal(GoalKind.battingAverage, 0.275),
        Goal(GoalKind.homeRuns, 18),
        Goal(GoalKind.rank, 3),
      ];
      for (final g in goals) {
        final rate = <double>[];
        for (var l = 0; l < 3; l++) {
          var ok = 0;
          const n = 200;
          for (var seed = 0; seed < n; seed++) {
            final ls = playLeagueSeason(p,
                teamLevel: 65,
                opponents: const [55, 60, 66, 72, 78],
                rng: Random(seed));
            final rec = SeasonRecord(
                age: 26,
                stage: Stage.pro,
                line: ls.line,
                teamWins: ls.wins,
                teamLosses: ls.losses,
                rank: ls.rank);
            if (g.withLevel(l).judge(rec)) ok++;
          }
          rate.add(ok / n);
        }
        expect(rate[0], greaterThan(rate[1]), reason: '${g.kind.name} $rate');
        expect(rate[1], greaterThan(rate[2]), reason: '${g.kind.name} $rate');
      }
    });

    test('ゲームの中: 年の最初の行動の前だけ選べ、選ぶと目標とごほうびが変わる', () {
      final g = Game.newGame(
          name: 't', role: Role.batter, rng: Random(2), potential: 80);
      expect(g.goal, isNotNull);
      expect(g.canChooseGoal, isTrue);
      final normal = g.goal!.target;
      g.chooseGoalLevel(2);
      expect(g.goal!.level, 2);
      expect(g.goal!.baseTarget, normal);
      g.chooseGoalLevel(0);
      expect(g.goal!.level, 0);
      expect(() => g.chooseGoalLevel(3), throwsArgumentError);
      g.choose(Plan.rest, Ability.contact);
      expect(g.canChooseGoal, isFalse);
      expect(() => g.chooseGoalLevel(1), throwsStateError);
    });

    test('ゲームの中で大会が終わると、選んだむずかしさのごほうびが判定される', () {
      for (final level in [0, 2]) {
        for (var seed = 0; seed < 30; seed++) {
          final g = Game.newGame(
              name: 't', role: Role.batter, rng: Random(seed), potential: 80);
          g.chooseGoalLevel(level);
          final goalLevel = g.goal!.level;
          var guard = 0;
          while (g.records.isEmpty) {
            if (++guard > 20) fail('大会が進まない');
            g.phase == Phase.event
                ? g.resolveEvent(0)
                : g.choose(Plan.rest, Ability.contact);
          }
          expect(g.goal!.level, goalLevel);
          expect(g.goal!.achieved, isNotNull);
          final line = g.log.firstWhere((l) => l.startsWith('今年の目標'));
          if (g.goal!.achieved!) {
            expect(line, contains('経験点+${goalExpFor(Stage.youth, level)}'));
            return;
          }
        }
      }
      fail('達成した年が見つからない');
    });
  });
}
