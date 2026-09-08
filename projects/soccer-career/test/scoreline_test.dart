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
  bool withReserves = false,
}) {
  final scenarios =
      ScenarioPool.neutralFor(position.family).take(minutes.length).toList();
  return MatchInProgress(
    matchday: 1,
    opponent: club('rival'),
    home: true,
    appearance: Appearance.start,
    scenarios: scenarios,
    reserves: withReserves
        ? [
            ...ScenarioPool.tempoFor(position.family, ScenarioTempo.chase),
            ...ScenarioPool.tempoFor(position.family, ScenarioTempo.hold),
          ]
        : const [],
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
      // アシストは、後に入る予定の味方の得点を引き寄せるだけ。点は増えない。
      expect(result.scored, 2 + result.goals);
      expect(result.conceded, 1);
    });

    test('アシストが決まれば、その時点でスコアに乗る', () {
      // 「味方が決めた」と書いてあるのに 0-0 のままだった。
      var found = false;
      for (var seed = 0; seed < 60 && !found; seed++) {
        final m = match(
          minutes: const [10, 50, 80],
          teammateGoals: const [70],
          seed: seed,
        );
        final assist = m.current.options
            .where((o) => o.outcome == Outcome.assist)
            .toList();
        if (assist.isEmpty) continue;
        final before = m.scoredBy(10);
        m.choose(assist.first);
        if (m.assists != 1) continue;
        found = true;
        expect(m.scoredBy(10), before + 1);
        // 流れの中では「アシスト」の1行になり、味方の得点と二重に出ない。
        final at10 = m.timeline.where((e) => e.minute == 10).toList();
        expect(at10.length, 1);
        expect(at10.single.kind, MatchEventKind.ownAssist);
      }
      expect(found, isTrue, reason: '60回試してアシストが決まらなかった');
    });

    test('後に味方の得点が予定されていれば、アシストはそれを引き寄せる', () {
      var found = false;
      for (var seed = 0; seed < 60 && !found; seed++) {
        final m = match(
          minutes: const [10, 50, 80],
          teammateGoals: const [70],
          seed: seed,
        );
        final assist = m.current.options
            .where((o) => o.outcome == Outcome.assist)
            .toList();
        if (assist.isEmpty) continue;
        m.choose(assist.first);
        if (m.assists != 1) continue;
        found = true;
        expect(m.scoredBy(10), 1);
        expect(m.scoredBy(90), 1, reason: '点が増えてはいけない');
      }
      expect(found, isTrue);
    });

    test('アシストの見込みは終盤ほど低く、必ず 1 を切る', () {
      final m = match(minutes: const [10, 50, 80], teammateGoals: const [30]);
      final early = m.assistConversionAt(10);
      final late = m.assistConversionAt(85);
      expect(early, lessThan(1.0));
      expect(early, greaterThan(0));
      expect(late, lessThan(early));
      expect(m.assistConversionAt(90), 0);
      // 自動進行の物差しも同じ見込みを使う。
      final assist = m.current.options
          .where((o) => o.outcome == Outcome.assist)
          .toList();
      if (assist.isNotEmpty) {
        final p = m.chanceFor(assist.first);
        final expected = p *
                (Formulas.ratingPerSuccess +
                    Formulas.ratingPerChance +
                    Formulas.ratingPerAssist * m.assistConversionAt(10)) +
            (1 - p) * Formulas.ratingPerFailure;
        expect(m.expectedDelta(assist.first), closeTo(expected, 1e-9));
      }
    });

    test('この後に味方が決める予定が無ければ、アシストは決まらない', () {
      // 予定が無いのに点を足すと、自分のクラブだけが強くなる。
      for (var seed = 0; seed < 60; seed++) {
        final m = match(minutes: const [10, 50, 80], seed: seed);
        final assist = m.current.options
            .where((o) => o.outcome == Outcome.assist)
            .toList();
        if (assist.isEmpty) continue;
        m.choose(assist.first);
        expect(m.assists, 0, reason: 'seed $seed');
        expect(m.scoredBy(90), 0);
      }
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

  group('展開に合わせた局面', () {
    test('終盤にビハインドなら、追いかける局面に差し替わる', () {
      final m = match(
        minutes: [20, 50, 82],
        conceded: [30],
        withReserves: true,
      );
      // 序盤は展開に依らない局面のまま。
      expect(m.current.tempo, ScenarioTempo.any);
      m.choose(m.current.options.first);
      m.choose(m.current.options.first);
      expect(m.tempoNow, ScenarioTempo.chase);
      expect(m.current.tempo, ScenarioTempo.chase,
          reason: '終盤にビハインドなのに、追いかける局面が来ない');
    });

    test('終盤にリードしていれば、守り切る局面に差し替わる', () {
      final m = match(
        minutes: [20, 50, 82],
        teammateGoals: [30],
        withReserves: true,
      );
      m.choose(m.current.options.first);
      m.choose(m.current.options.first);
      expect(m.tempoNow, ScenarioTempo.hold);
      expect(m.current.tempo, ScenarioTempo.hold);
    });

    test('2点差を追う展開は、もう少し早くから勝負になる', () {
      final m = match(
        minutes: [20, 62, 82],
        conceded: [10, 15],
        withReserves: true,
      );
      m.choose(m.current.options.first);
      expect(m.currentMinute, 62);
      expect(m.currentMinute, lessThan(Formulas.situationalMinute));
      expect(m.current.tempo, ScenarioTempo.chase,
          reason: '2点ビハインドでも普通の局面のまま');
    });

    test('同点なら差し替わらない', () {
      final m = match(
        minutes: [20, 50, 82],
        teammateGoals: [30],
        conceded: [40],
        withReserves: true,
      );
      m.choose(m.current.options.first);
      m.choose(m.current.options.first);
      expect(m.tempoNow, ScenarioTempo.any);
      expect(m.current.tempo, ScenarioTempo.any);
    });

    test('控えが無ければ何も起きない', () {
      final m = match(minutes: [20, 50, 82], conceded: [30]);
      m.choose(m.current.options.first);
      m.choose(m.current.options.first);
      expect(m.tempoNow, ScenarioTempo.chase);
      expect(m.current.tempo, ScenarioTempo.any, reason: '控えが無いのに差し替わった');
    });

    test('差し替えても、同じ局面が1試合に二度出ない', () {
      final m = match(
        minutes: [20, 50, 82],
        conceded: [30],
        withReserves: true,
      );
      while (!m.isFinished) {
        m.choose(m.current.options.first);
      }
      final ids = m.scenarios.map((s) => s.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('差し替わる時間帯は、画面にも状況が出る', () {
      // 局面だけが変わって理由が出ないと、ただの気まぐれに見える。
      final m = match(
        minutes: [20, 62, 82],
        conceded: [10, 15],
        withReserves: true,
      );
      m.choose(m.current.options.first);
      expect(m.situationLabel, contains('2点ビハインド'));
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

    test('骨格だけで1試合ぶんを賄え、どの展開にも控えがある', () {
      for (final family in ScenarioFamily.values) {
        expect(ScenarioPool.neutralFor(family).length,
            greaterThanOrEqualTo(12),
            reason: '$family の骨格が少ない');
        for (final tempo in [ScenarioTempo.chase, ScenarioTempo.hold]) {
          expect(ScenarioPool.tempoFor(family, tempo).length,
              greaterThanOrEqualTo(3),
              reason: '$family に $tempo の局面が足りない');
        }
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
