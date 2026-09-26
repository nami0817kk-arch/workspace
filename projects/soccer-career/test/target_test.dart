/// 今節の的と、その連続。
///
/// 的の報酬はお金だけだった。お金は年俸と一緒に増えるので、序盤は
/// 年俸の17%だったものが9季目以降は2%まで薄まっていた
/// （`test/target_sim.dart` の実測）。**入れた仕組みが途中から飾りになる**。
/// 連続の節目に経験点を払うことで、最後まで同じ重さで効かせる。
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/data/save_repository.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/game/formulas.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/game/match_target.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/career.dart';
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
  Position position = Position.st,
}) async {
  final c = CareerController(
    repository: _MemoryRepository(),
    careerEngine: CareerEngine(random: Random(seed)),
    matchEngine: MatchEngine(random: Random(seed)),
    random: Random(seed),
  );
  await c.startCareer(
    name: '検証',
    position: position,
    age: 22,
    agent: Agent.pool.first,
  );
  return c;
}

void main() {
  group('的', () {
    test('的は節から決まるので、見てから引き直せない', () async {
      final c = await started();
      final state = c.state!;
      final first = MatchTarget.of(state).label;
      expect(MatchTarget.of(state).label, first);
    });

    test('ポジションごとに、問うている能力が違う', () async {
      final forward = await started(position: Position.st);
      final keeper = await started(position: Position.gk);
      final categories = <AttributeKey>{};
      for (final c in [forward, keeper]) {
        categories.add(MatchTarget.of(c.state!).category);
      }
      // 守る選手に「1ゴール」を出しても的にならない。
      expect(categories.length, greaterThan(1));
    });

    test('出ていない試合は達成にしない', () async {
      final c = await started();
      final target = MatchTarget.of(c.state!);
      const absent = MatchResult(
        matchday: 1,
        opponentName: '相手',
        home: true,
        appearance: Appearance.benched,
        goals: 3,
        assists: 3,
        conceded: 0,
        scored: 3,
        rating: 9.0,
      );
      // 数字はどれも達成の条件を満たしているが、出ていない。
      expect(target.metBy(absent), isFalse);
    });
  });

  group('連続', () {
    test('達成すると伸び、外すと切れる', () async {
      var sawStreak = false;
      for (var seed = 0; seed < 8 && !sawStreak; seed++) {
        final c = await started(seed: seed);
        for (var i = 0; i < 40; i++) {
          if (c.state == null || c.state!.seasonFinished) break;
          final before = c.state!.targetStreak;
          final r = await c.simulateMatch();
          if (c.state == null) break;
          // 試合が始まらなかった週（代表ウィークなど）は判定が動かない。
          // カップ戦・代表戦も素通り。伸びも切れもしない。
          if (r == null || !r.isLeague) {
            expect(c.state!.targetStreak, before);
            continue;
          }
          final after = c.state!.targetStreak;
          if (c.lastTargetMet) {
            expect(after, before + 1);
            if (after > 1) sawStreak = true;
          } else {
            expect(after, 0);
          }
        }
      }
      // 連続が一度も起きないなら、節目は永久に来ない。
      expect(sawStreak, isTrue);
    });

    test('節目でだけ、その的の能力に経験点が入る', () async {
      var paid = 0;
      for (var seed = 0; seed < 8; seed++) {
        final c = await started(seed: seed);
        for (var i = 0; i < 40; i++) {
          if (c.state == null || c.state!.seasonFinished) break;
          final before = Map<AttributeKey, int>.from(
            c.state!.development.points,
          );
          final target = MatchTarget.of(c.state!);
          final r = await c.simulateMatch();
          if (c.state == null) break;
          if (r == null || !r.isLeague) continue;
          if (c.lastTargetPoints > 0) {
            paid++;
            expect(c.state!.targetStreak % MatchTarget.streakStep, 0);
            expect(c.lastTargetPoints, Formulas.targetStreakPoints);
            // 入った先は、その的が問うている能力。自動で振る設定では
            // その場で使われるので、貯まった側は増えないこともある。
            final delta =
                (c.state!.development.points[target.category] ?? 0) -
                (before[target.category] ?? 0);
            expect(delta, lessThanOrEqualTo(Formulas.targetStreakPoints));
            // 他のカテゴリに、的のぶんが紛れ込まない。
            // （難しい手のぶんは局面の能力に入るので、増えること自体はある。
            //   増え方が `targetStreakPoints` を超えないことだけ見る。）
            for (final key in AttributeKey.values) {
              if (key == target.category) continue;
              expect(
                (c.state!.development.points[key] ?? 0) - (before[key] ?? 0),
                lessThan(Formulas.targetStreakPoints),
                reason: '${key.label} に的のぶんが入っている',
              );
            }
          } else if (c.lastTargetMet) {
            expect(c.state!.targetStreak % MatchTarget.streakStep, isNot(0));
          }
        }
      }
      expect(paid, greaterThan(0));
    });

    test('自動で振る設定でも、節目の経験点が眠らない', () async {
      // **既定は「その場で自動」**。自動のときは経験点を貯めずに直接
      // 伸ばしているので、貯める側へ足すだけでは誰も使わない。
      // 入れた当初はここを見落としていて、`balance_sim` が master と
      // 1 も動かなかった（＝仕組みが丸ごと効いていなかった）。
      var checked = 0;
      for (var seed = 0; seed < 8 && checked == 0; seed++) {
        final c = await started(seed: seed);
        expect(c.state!.autoSpend, isTrue);
        for (var i = 0; i < 40; i++) {
          if (c.state == null || c.state!.seasonFinished) break;
          final r = await c.simulateMatch();
          if (c.state == null) break;
          if (r == null || !r.isLeague) continue;
          if (c.lastTargetPoints > 0) {
            checked++;
            // 使い切っているか、上限で振れないかのどちらか。
            final left =
                c.state!.development.points[MatchTarget.of(c.state!)
                    .category] ??
                0;
            expect(left, lessThan(Formulas.targetStreakPoints));
            break;
          }
        }
      }
      expect(checked, greaterThan(0));
    });

    test('保存して読み直しても、連続が残る', () async {
      final c = await started();
      await c.simulateMatch();
      c.state!.targetStreak = 7;
      final json = c.state!.toJson();
      expect(CareerState.fromJson(json).targetStreak, 7);
      // 鍵ごと無い古い保存データは 0 から。
      json.remove('targetStreak');
      expect(CareerState.fromJson(json).targetStreak, 0);
    });
  });
}
