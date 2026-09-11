/// コツ。20年やってきたことが、最後に1つだけ性質になる。
///
/// 特性は**生まれ持ったもの**で伸ばせない、という前提でずっと来た。
/// そのぶん、20年やってきたことが選手の「性質」には一切乗らなかった——
/// パスばかり選び続けた選手も、最後まで司令塔にはならない。
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/data/save_repository.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/game/knacks.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/career.dart';
import 'package:soccer_career/models/development.dart';
import 'package:soccer_career/models/traits.dart';
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
    name: '検証',
    position: position,
    age: 30,
    agent: Agent.pool.first,
  );
  return c;
}

/// 条件を満たした状態にする。
void ready(CareerState state, {AttributeKey key = AttributeKey.passing}) {
  state.development = Development(
    experience: Knacks.experienceNeeded,
    greatWeeks: Knacks.greatWeeksNeeded,
    choices: {key: Knacks.momentsNeeded},
  );
}

void main() {
  group('掴める条件', () {
    test('試合経験・追い込み・その場面の実績が全部要る', () async {
      final c = await started();
      final state = c.state!;
      expect(Knacks.canLearn(state), isFalse);

      state.development = Development(
        experience: Knacks.experienceNeeded - 1,
        greatWeeks: Knacks.greatWeeksNeeded,
        choices: {AttributeKey.passing: Knacks.momentsNeeded},
      );
      expect(Knacks.missing(state), contains('試合経験'));

      state.development = Development(
        experience: Knacks.experienceNeeded,
        greatWeeks: Knacks.greatWeeksNeeded - 1,
        choices: {AttributeKey.passing: Knacks.momentsNeeded},
      );
      expect(Knacks.missing(state), contains('大成功'));

      state.development = Development(
        experience: Knacks.experienceNeeded,
        greatWeeks: Knacks.greatWeeksNeeded,
        choices: const {},
      );
      expect(Knacks.missing(state), contains('勝負'));

      ready(state);
      expect(Knacks.missing(state), isNull);
      expect(Knacks.canLearn(state), isTrue);
    });

    test('経験点では買わせない', () async {
      // 自動で振る側（既定）は経験点が貯まらない。値段を経験点にすると、
      // 既定のまま遊ぶ人だけ一生掴めなくなる。
      final c = await started();
      final state = c.state!;
      expect(state.autoSpend, isTrue);
      ready(state);
      expect(Knacks.canLearn(state), isTrue);
    });

    test('1キャリアに1つだけ', () async {
      final c = await started();
      final state = c.state!;
      ready(state);
      final first = Knacks.offer(state).first;
      expect(await c.learnKnack(first), isTrue);

      expect(state.learnedKnack, isTrue);
      expect(Knacks.canLearn(state), isFalse);
      expect(Knacks.missing(state), contains('もう掴んでいる'));
      // 2つ目は通らない。**生まれつき持っていることがある**ので、
      // 「入っていない」ではなく「増えていない」で見る。
      final before = state.player.traits.length;
      expect(await c.learnKnack(Trait.wall), isFalse);
      expect(state.player.traits.length, before);
    });
  });

  group('何が出るか', () {
    test('よく勝負してきた場面からしか出ない', () async {
      final c = await started();
      final state = c.state!;
      ready(state, key: AttributeKey.defending);
      for (final trait in Knacks.offer(state)) {
        expect(trait.knackKey, AttributeKey.defending);
      }
    });

    test('回数が足りないカテゴリからは出ない', () async {
      final c = await started();
      final state = c.state!;
      state.development = Development(
        experience: Knacks.experienceNeeded,
        greatWeeks: Knacks.greatWeeksNeeded,
        choices: {AttributeKey.passing: Knacks.momentsNeeded - 1},
      );
      expect(Knacks.offer(state), isEmpty);
    });

    test('待っても引き直せない', () async {
      // 引き直せると「良いコツが出るまで待つ」が最適解になり、
      // 何をやってきたかが関係なくなる。
      final c = await started();
      final state = c.state!;
      ready(state);
      final first = Knacks.offer(state);
      expect(Knacks.offer(state), first);
      expect(Knacks.offer(state), first);
    });

    test('すでに持っている特性と、噛み合わないものは出さない', () async {
      final c = await started();
      final state = c.state!;
      ready(state);
      for (final trait in Knacks.offer(state)) {
        expect(state.player.traits.contains(trait), isFalse);
        for (final owned in state.player.traits) {
          expect(
            Trait.compatible(owned, trait),
            isTrue,
            reason: '${owned.label} と ${trait.label} が噛み合わない',
          );
        }
      }
    });

    test('ポジションで意味の無いものは出さない', () async {
      final gk = await started(position: Position.gk);
      ready(gk.state!, key: AttributeKey.goalkeeping);
      for (final trait in Knacks.offer(gk.state!)) {
        expect(trait.fitsPosition(Position.gk), isTrue);
      }

      final st = await started(position: Position.st);
      ready(st.state!, key: AttributeKey.shooting);
      for (final trait in Knacks.offer(st.state!)) {
        expect(trait.fitsPosition(Position.st), isTrue);
        expect(trait.knackKey, isNotNull);
      }
    });

    test('生まれつきでしか手に入らないものは掴めない', () {
      // 稀なもの・欠点・成長の型（早熟/大器晩成）を後から選ばせない。
      for (final trait in Trait.knacks) {
        expect(trait.rare, isFalse, reason: trait.label);
        expect(trait.flaw, isFalse, reason: trait.label);
      }
      expect(Trait.knacks.contains(Trait.genius), isFalse);
      expect(Trait.knacks.contains(Trait.earlyBloomer), isFalse);
      expect(Trait.knacks.contains(Trait.lateBloomer), isFalse);
    });

    test('出すのは3つまで', () async {
      final c = await started();
      ready(c.state!);
      expect(
        Knacks.offer(c.state!).length,
        lessThanOrEqualTo(Knacks.offerCount),
      );
    });
  });

  group('掴んだあと', () {
    test('特性として実際に付く', () async {
      final c = await started();
      final state = c.state!;
      ready(state);
      final picked = Knacks.offer(state).first;
      final before = state.player.traits.length;

      await c.learnKnack(picked);
      expect(state.player.traits.length, before + 1);
      expect(state.player.traits, contains(picked));
    });

    test('出していないものは掴めない', () async {
      final c = await started();
      final state = c.state!;
      ready(state, key: AttributeKey.passing);
      // 守備のコツは、パスの実績からは出ない。
      expect(await c.learnKnack(Trait.wall), isFalse);
      expect(state.learnedKnack, isFalse);
    });

    test('記事になる', () async {
      final c = await started();
      final state = c.state!;
      ready(state);
      await c.learnKnack(Knacks.offer(state).first);
      expect(state.news.first.headline, contains(state.player.name));
    });

    test('保存に乗る。知らない保存データでは掴んでいない扱い', () async {
      final c = await started();
      final state = c.state!;
      ready(state);
      await c.learnKnack(Knacks.offer(state).first);

      final json = state.toJson();
      expect(CareerState.fromJson(json).learnedKnack, isTrue);
      expect(
        CareerState.fromJson(json..remove('learnedKnack')).learnedKnack,
        isFalse,
      );
    });
  });
}
