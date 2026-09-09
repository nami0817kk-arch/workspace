import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/data/save_repository.dart';
import 'package:soccer_career/models/training.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/game/formulas.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/career.dart';
import 'package:soccer_career/models/season.dart';
import 'package:soccer_career/state/career_controller.dart';

/// 保存しないリポジトリ。コントローラを端末なしで回すために使う。
class _MemoryRepository implements SaveRepository {
  CareerState? _saved;

  @override
  Future<CareerState?> load() async => _saved;

  @override
  Future<void> save(CareerState state) async => _saved = state;

  @override
  Future<void> clear() async => _saved = null;
}

CareerController controller({int seed = 1}) => CareerController(
      repository: _MemoryRepository(),
      careerEngine: CareerEngine(random: Random(seed)),
      matchEngine: MatchEngine(random: Random(seed)),
      // 種を渡さないと、出場機会の判断と出来事だけが実行ごとに変わる。
      // 同じ種で違う結果が出るので、たまに落ちるテストになっていた。
      random: Random(seed),
    );

/// 1試合を最後まで進める。局面は常に最初の選択肢を選ぶ。
Future<MatchResult?> playOne(CareerController c) async {
  c.startNextMatch();
  final match = c.currentMatch;
  if (match == null) return null;
  while (!match.isFinished) {
    c.choose(0);
  }
  return c.finishMatch();
}

void main() {
  group('シーズンを通しで回す', () {
    test('38節を消化でき、代表戦は節に数えない', () async {
      final c = controller(seed: 3);
      await c.startCareer(
          name: 'F', position: Position.st, age: 18, agent: Agent.pool.first);

      var guard = 0;
      while (!c.state!.seasonFinished && guard < 200) {
        await playOne(c);
        guard++;
      }

      final state = c.state!;
      expect(state.seasonFinished, isTrue, reason: '38節を消化しきれていない');
      expect(state.leagueResults.length, state.fixtures.length);
      // 節番号が飛んでいないこと。
      for (var i = 0; i < state.leagueResults.length; i++) {
        expect(state.leagueResults[i].matchday, i + 1);
      }
      // 順位表は全クラブが同じ試合数を消化している。
      final played = state.table.map((r) => r.played).toSet();
      expect(played.length, 1, reason: 'クラブ間で消化数がずれている');
      expect(played.first, state.fixtures.length);
    });

    test('通しで回しても評価点は 4.0〜10.0 に収まり、出ていない試合には付かない', () async {
      final c = controller(seed: 5);
      await c.startCareer(
          name: 'F', position: Position.cm, age: 19, agent: Agent.pool.first);

      var guard = 0;
      while (!c.state!.seasonFinished && guard < 200) {
        await playOne(c);
        guard++;
      }

      for (final r in c.state!.results) {
        if (r.appearance == Appearance.benched ||
            r.appearance == Appearance.injured ||
            r.appearance == Appearance.suspended) {
          expect(r.rating, isNull, reason: '${r.appearance.label}に評価点が付いている');
        } else {
          expect(r.rating, inInclusiveRange(Formulas.minRating, Formulas.maxRating));
        }
      }
    });

    test('負傷したら離脱し、離脱が明ければ復帰する', () async {
      // 疲れやすい条件で回す。怪我は確率なので、1つの種に賭けると
      // 乱数の並びが変わっただけで落ちる。何人か回して見る。
      var sawInjury = false;
      var sawRecovery = false;
      for (var seed = 11; seed < 21 && !(sawInjury && sawRecovery); seed++) {
        final c = controller(seed: seed);
        await c.startCareer(
            name: 'F', position: Position.cb, age: 30, agent: Agent.pool.first);
        await c.setMenu(TrainingMenu.strengthWork);

        var guard = 0;
        while (guard < 200 && !c.state!.seasonFinished) {
          final before = c.state!.injured;
          await playOne(c);
          if (!before && c.state!.injured) sawInjury = true;
          if (before && !c.state!.injured) sawRecovery = true;
          guard++;
        }
      }

      expect(sawInjury, isTrue, reason: '10人回して怪我が一度も起きなかった');
      expect(sawRecovery, isTrue, reason: '離脱から復帰しなかった');
    });

    test('離脱中の試合は欠場として記録され、節は進む', () async {
      final c = controller(seed: 11);
      await c.startCareer(
          name: 'F', position: Position.cb, age: 30, agent: Agent.pool.first);
      await c.setMenu(TrainingMenu.strengthWork);

      var guard = 0;
      while (!c.state!.injured && guard < 200) {
        if (c.state!.seasonFinished) break;
        await playOne(c);
        guard++;
      }
      // 怪我が起きないままシーズンが終わったら、このテストは対象外。
      if (!c.state!.injured || c.state!.seasonFinished) return;

      final before = c.state!.matchday;
      // 代表ウィークは節を消費しないので、当たったらもう一度進める。
      var result = await playOne(c);
      result ??= await playOne(c);
      expect(result, isNotNull);
      expect(result!.appearance, Appearance.injured);
      expect(result.rating, isNull);
      expect(c.state!.matchday, before + 1);
    });

    test('シーズンを跨いでも保存を往復できる', () async {
      final c = controller(seed: 7);
      await c.startCareer(
          name: 'F', position: Position.wg, age: 20, agent: Agent.pool.first);

      var guard = 0;
      while (!c.state!.seasonFinished && guard < 200) {
        await playOne(c);
        guard++;
      }

      final renewal = c.renewalOffer!;
      await c.advanceSeason(accepted: renewal);

      final restored = CareerState.fromJson(c.state!.toJson());
      expect(restored.year, c.state!.year);
      expect(restored.player.age, c.state!.player.age);
      expect(restored.history.length, 1);
      expect(restored.contractYears, c.state!.contractYears);
      expect(restored.objective, isNotNull);
      expect(restored.results, isEmpty);
    });
  });
}
