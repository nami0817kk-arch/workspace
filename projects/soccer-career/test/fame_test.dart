/// **名前が、値段と行ける先になる。**
///
/// 知名度（`Person.fameFor`）には 代表・大陸カップ・世界大会・ゴール・
/// リーグの格・特性（華がある／生まれながらの主役）が全部集まってくるのに、
/// 効いていたのは愛称と引退後の道だけだった。移籍にも年俸にも返らないので、
/// 知名度を上げる特性も出来事も飾りになっていた。
///
/// あわせて、長所が「速さ」ではなく「届く高さ」に返ることも見る。
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/data/save_repository.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/game/formulas.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/game/person.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/career.dart';
import 'package:soccer_career/models/season.dart';
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

Future<CareerController> started({int seed = 7}) async {
  final c = CareerController(
    repository: _MemoryRepository(),
    careerEngine: CareerEngine(random: Random(seed)),
    matchEngine: MatchEngine(random: Random(seed)),
    random: Random(seed),
  );
  await c.startCareer(
    name: '検証',
    position: Position.cm,
    age: 24,
    agent: Agent.pool.first,
  );
  return c;
}

void main() {
  group('名前は値段になる', () {
    test('同じ実力でも、名の知れた選手のほうが高く売れる', () async {
      final c = await started();
      final state = c.state!;

      state.reputation = state.reputation.copyWith(fame: 0);
      final unknown = Person(random: Random(1)).marketValueFor(state);

      state.reputation = state.reputation.copyWith(fame: 90);
      final famous = Person(random: Random(1)).marketValueFor(state);

      expect(famous, greaterThan(unknown), reason: '知名度が値札に乗っていない');
    });

    test('知名度で値札が跳ね上がりはしない', () {
      // 0〜100 なので、効きは最大でもこの倍率。実力を追い越させない。
      expect(1 + 100 * Formulas.fameValue, lessThanOrEqualTo(1.5));
      expect(100 * Formulas.fameReach, lessThanOrEqualTo(4.0));
    });

    test('華のある特性は、同じ働きでも名前が広まる', () async {
      final c = await started();
      final state = c.state!;
      state.reputation = state.reputation.copyWith(fame: 20);
      // 代表戦に出たぶんが知名度になる。倍率が乗るのは「得たぶん」だけ。
      state.results = [
        for (var i = 0; i < 4; i++)
          MatchResult(
            matchday: 0,
            opponentName: '相手',
            home: true,
            scored: 1,
            conceded: 0,
            appearance: Appearance.start,
            rating: 7.0,
            goals: 0,
            assists: 0,
            international: true,
          ),
      ];

      final plain = Person(random: Random(1)).fameFor(state);
      state.player = state.player.copyWith(traits: const [Trait.showman]);
      final showy = Person(random: Random(1)).fameFor(state);

      expect(showy, greaterThan(plain));
    });
  });

  group('長所は、届く高さに返る', () {
    test('伸びる速さを持つ長所には、高さも付く', () {
      // **速く伸びてもポテンシャルで止まるので、同じ選手になる。**
      // 実測（`test/trait_sim.dart`）で、練習の効き 1.25 倍と
      // 限界突破 1.6 倍を持つ組み合わせが、特性なしよりピーク +0.4 しか
      // 高くなかった。下振れには上限が無く、上振れにだけ上限があった。
      expect(Trait.quickLearner.potentialBonus, greaterThan(0));
      expect(Trait.lateBloomer.potentialBonus, greaterThan(0));
    });

    test('殻を破る選手は、限界突破の条件そのものが軽い', () {
      expect(Trait.breaker.breakthroughWeekOffset, lessThan(0));
      expect(
        Trait.genius.breakthroughWeekOffset,
        lessThan(0),
        reason: '確率の倍率だけでは、条件に届かないキャリアに何も返らない',
      );
    });

    test('要る回数は、画面と判定が同じところから出る', () async {
      // ここがずれると「あと3回」と書いてあるのに起きない、になる。
      final c = await started();
      final plain = c.state!.player;
      expect(plain.breakthroughWeeks, Formulas.breakthroughGreatWeeks);

      final breaker = plain.copyWith(traits: const [Trait.breaker]);
      expect(
        breaker.breakthroughWeeks,
        Formulas.breakthroughGreatWeeks + Trait.breaker.breakthroughWeekOffset,
      );
      expect(breaker.breakthroughWeeks, lessThan(plain.breakthroughWeeks));
    });

    test('効き方は画面の文にも出る', () {
      // 数字を変えれば画面も変わる、を崩さない。
      expect(
        Trait.breaker.effects.any((e) => e.contains('大成功の週')),
        isTrue,
      );
      expect(
        Trait.lateBloomer.effects.any((e) => e.contains('ポテンシャル')),
        isTrue,
      );
    });
  });
}
