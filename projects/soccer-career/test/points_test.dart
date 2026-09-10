/// 経験点。伸びるはずだったぶんを、自分で振る。
///
/// 成長は**全部自動**で、伸ばす先を選ぶ余地が無かった。練習の種類で
/// カテゴリは選べても、その中のどれが伸びるかは運任せだった。
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/data/save_repository.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/game/formulas.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/career.dart';
import 'package:soccer_career/models/development.dart';
import 'package:soccer_career/models/player.dart';
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
      name: '検証', position: Position.cm, age: 20, agent: Agent.pool.first);
  return c;
}

void main() {
  group('値段', () {
    test('上に行くほど高い', () {
      // 平らにすると、一番得意なところに全部注ぐのが常に正解になる。
      expect(Formulas.experienceCost(90),
          greaterThan(Formulas.experienceCost(50)));
      expect(Formulas.experienceCost(70),
          greaterThan(Formulas.experienceCost(55)));
    });

    test('安い側でも、ただにはしない', () {
      expect(Formulas.experienceCost(1), greaterThan(0));
    });

    test('付与量と値段が釣り合っている', () {
      // ここがずれると、切り替えるだけで成長速度が変わる。
      // 平均的な能力値のあたりで、1回ぶん ≒ 1段。
      expect(Formulas.pointsPerGrowth,
          closeTo(Formulas.experienceCost(65).toDouble(), 1.0));
    });

    test('画面に出す値段と、実際に引かれる値段が同じ', () async {
      final c = await started();
      final state = c.state!;
      state.autoSpend = false;
      const detail = Detail.vision;
      state.development = Development(points: {AttributeKey.passing: 50});

      final shown = c.costOf(detail);
      await c.spendPoint(detail);
      expect(state.development.points[AttributeKey.passing], 50 - shown);
    });
  });

  group('振る', () {
    test('振ったぶんだけ上がる', () async {
      final c = await started();
      final state = c.state!;
      state.autoSpend = false;
      state.development = Development(points: {AttributeKey.passing: 40});
      final before = state.player.attributes.detail(Detail.vision);

      final grown = await c.spendPoint(Detail.vision);
      expect(grown, isNotNull);
      expect(state.player.attributes.detail(grown!), before + 1);
    });

    test('カテゴリを跨いでは使えない', () async {
      final c = await started();
      final state = c.state!;
      state.autoSpend = false;
      state.development = Development(points: {AttributeKey.passing: 40});

      expect(c.canSpend(Detail.tackling), isFalse);
      expect(c.reasonNotToSpend(Detail.tackling), contains('守備'));
      expect(await c.spendPoint(Detail.tackling), isNull);
    });

    test('足りなければ、その理由が出る', () async {
      final c = await started();
      final state = c.state!;
      state.autoSpend = false;
      state.development = Development(points: {AttributeKey.passing: 1});
      expect(c.canSpend(Detail.vision), isFalse);
      expect(c.reasonNotToSpend(Detail.vision), contains('足りない'));
    });

    test('ポテンシャルに届いていれば振れない', () async {
      final c = await started();
      final state = c.state!;
      state.autoSpend = false;
      state.development = Development(points: {AttributeKey.passing: 99});
      state.player = Player.rebuild(state.player,
          attributes: state.player.attributes,
          potential: state.player.overall);
      expect(state.player.atPotential, isTrue);
      expect(c.canSpend(Detail.vision), isFalse);
      expect(c.reasonNotToSpend(Detail.vision), contains('ポテンシャル'));
    });

    test('土台が足りなければ、土台のほうが伸びる', () async {
      // 練習と同じ扱い。別の式にすると、自分で振ったときだけ土台を無視できる。
      final c = await started();
      final state = c.state!;
      state.autoSpend = false;
      state.development =
          const Development(points: {AttributeKey.passing: 200});
      // 視野は ショートパス を土台にしている。土台だけ低く置く。
      state.player = Player.rebuild(
        state.player,
        attributes: Attributes.fromDetails({
          for (final d in Detail.values) d: 70,
          Detail.shortPassing: 30,
        }),
        potential: 99,
      );

      final grown = await c.spendPoint(Detail.vision);
      expect(grown, Detail.shortPassing,
          reason: '土台を飛ばして視野だけが伸びている');
    });
  });

  group('貯まる', () {
    test('自動のままなら、その場で伸びて貯まらない', () async {
      final c = await started();
      final state = c.state!;
      expect(state.autoSpend, isTrue, reason: '既定が自動でない');
      for (var i = 0; i < 20; i++) {
        await c.simulateMatch();
      }
      expect(state.development.totalPoints, 0);
    });

    test('自分で振る側に切り替えると、貯まる', () async {
      final c = await started();
      final state = c.state!;
      await c.setAutoSpend(false);
      final before = state.player.overall;
      for (var i = 0; i < 20; i++) {
        await c.simulateMatch();
      }
      expect(state.development.totalPoints, greaterThan(0));
      // 振らないうちは伸びない。貯めたまま忘れると伸びない選手になる。
      expect(state.player.overall, lessThanOrEqualTo(before + 1));
    });

    test('練習したカテゴリに貯まる', () async {
      final c = await started();
      final state = c.state!;
      await c.setAutoSpend(false);
      await c.setMenu(TrainingMenu.defenceWork);
      for (var i = 0; i < 30; i++) {
        await c.simulateMatch();
      }
      expect(state.development.points[AttributeKey.defending] ?? 0,
          greaterThan(0));
    });
  });

  group('保存', () {
    test('経験点と設定は保存に乗る', () async {
      final c = await started();
      final state = c.state!;
      await c.setAutoSpend(false);
      state.development =
          const Development(points: {AttributeKey.passing: 12});
      final json = state.toJson();
      final back = CareerState.fromJson(json);
      expect(back.autoSpend, isFalse);
      expect(back.development.points[AttributeKey.passing], 12);
    });

    test('経験点を知らない保存データは、自動のまま読める', () async {
      final c = await started();
      final json = c.state!.toJson()..remove('autoSpend');
      (json['development'] as Map).remove('points');
      final back = CareerState.fromJson(json);
      expect(back.autoSpend, isTrue, reason: '続きから遊ぶ人に不意打ちになる');
      expect(back.development.points, isEmpty);
    });
  });
}
