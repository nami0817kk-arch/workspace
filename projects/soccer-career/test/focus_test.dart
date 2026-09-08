/// 育てる方向。選んだ項目に、練習と試合の成長が寄るか。
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/data/save_repository.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/game/world.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/career.dart';
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

Future<CareerController> started({int seed = 3, int age = 19}) async {
  final c = CareerController(
    repository: _MemoryRepository(),
    careerEngine: CareerEngine(random: Random(seed)),
    matchEngine: MatchEngine(random: Random(seed)),
    random: Random(seed),
  );
  await c.startCareer(
      name: '検証', position: Position.st, age: age, agent: Agent.pool.first);
  return c;
}

void main() {
  group('方向の選び方', () {
    test('上限まで。それ以上は黙って入れ替えない', () async {
      final c = await started();
      expect(c.state!.focus, isEmpty);
      for (final d in [Detail.finishing, Detail.shotPower, Detail.vision]) {
        await c.toggleFocus(d);
      }
      expect(c.state!.focus.length, CareerState.maxFocus);

      await c.toggleFocus(Detail.crossing);
      expect(c.state!.focus.contains(Detail.crossing), isFalse,
          reason: '上限を超えて入った');
      expect(c.state!.focus.length, CareerState.maxFocus,
          reason: '黙って何かが外れた');

      // もう一度押すと外れる。
      await c.toggleFocus(Detail.vision);
      expect(c.state!.focus.contains(Detail.vision), isFalse);
      expect(c.state!.focus.length, CareerState.maxFocus - 1);
    });

    test('カテゴリごとに取り出せる', () async {
      final c = await started();
      await c.toggleFocus(Detail.finishing);
      await c.toggleFocus(Detail.vision);
      expect(c.state!.focusIn(AttributeKey.shooting), [Detail.finishing]);
      expect(c.state!.focusIn(AttributeKey.passing), [Detail.vision]);
      expect(c.state!.focusIn(AttributeKey.defending), isEmpty);
    });

    test('保存を往復しても残り、古い保存データでは空', () async {
      final c = await started();
      await c.toggleFocus(Detail.acceleration);
      final json = c.state!.toJson();
      expect(CareerState.fromJson(json).focus, [Detail.acceleration]);
      expect(CareerState.fromJson(json..remove('focus')).focus, isEmpty);
    });

    test('シーズンを跨いでも残る', () async {
      final c = await started(seed: 71);
      await c.toggleFocus(Detail.finishing);
      while (!c.state!.seasonFinished) {
        await c.simulateMatch();
      }
      await c.finishSeason();
      await c.advanceSeason(accepted: c.renewalOffer!);
      expect(c.state!.focus, [Detail.finishing]);
    });
  });

  group('練習が方向に寄る', () {
    test('同じカテゴリの中では、選んだ項目だけが伸びる', () {
      // シュートの練習で伸びるのは、決定力・シュート力・ロングシュート・
      // ヘディングのどれか。方向を1つ入れたら、そこだけに乗る。
      final engine = MatchEngine(random: Random(5));
      final career = CareerEngine(random: Random(5)).startCareer(
          name: 'P', position: Position.st, age: 18, agent: Agent.pool.first);
      var player = career.player;
      final before = player.attributes;

      for (var i = 0; i < 60; i++) {
        final week = engine.applyWeek(
          player,
          menu: TrainingMenu.finishingWork,
          focus: const [Detail.finishing],
          played: false,
        );
        player = player.copyWith(
            attributes: week.attributes, condition: week.condition);
      }

      final grew = [
        for (final d in AttributeKey.shooting.details)
          if (player.attributes.detail(d) > before.detail(d)) d,
      ];
      expect(grew, isNotEmpty, reason: '60週やって1つも伸びていない');
      // 土台（Dependencies）に振り替えられることがあるので、
      // 決定力が一番伸びていることを見る。
      final finishingGain = player.attributes.detail(Detail.finishing) -
          before.detail(Detail.finishing);
      for (final d in AttributeKey.shooting.details) {
        if (d == Detail.finishing) continue;
        expect(player.attributes.detail(d) - before.detail(d),
            lessThanOrEqualTo(finishingGain),
            reason: '${d.label} のほうが伸びている');
      }
    });

    test('方向を入れていなければ、これまでどおり散らばる', () {
      final engine = MatchEngine(random: Random(6));
      final career = CareerEngine(random: Random(6)).startCareer(
          name: 'P', position: Position.st, age: 18, agent: Agent.pool.first);
      var player = career.player;
      final before = player.attributes;

      for (var i = 0; i < 60; i++) {
        final week = engine.applyWeek(
          player,
          menu: TrainingMenu.finishingWork,
          played: false,
        );
        player = player.copyWith(
            attributes: week.attributes, condition: week.condition);
      }
      final grew = [
        for (final d in AttributeKey.shooting.details)
          if (player.attributes.detail(d) > before.detail(d)) d,
      ];
      expect(grew.length, greaterThan(1), reason: '1つにしか乗っていない');
    });
  });

  group('国籍', () {
    test('国の名前が実在のものになっている', () {
      final names = World.countries.map((c) => c.name).toList();
      expect(names, contains('日本'));
      expect(names, contains('イングランド'));
      expect(names, contains('ブラジル'));
      // 架空の頃の名前が残っていない。
      for (final old in ['ヤマト', 'アルビオン', 'セリーナ']) {
        expect(names, isNot(contains(old)), reason: old);
      }
    });

    test('国のIDは変えていない（保存データが読めなくなる）', () {
      final ids = World.countries.map((c) => c.id).toSet();
      for (final id in ['yamato', 'albion', 'germania', 'serena']) {
        expect(ids, contains(id), reason: id);
      }
      expect(World.byId('yamato').name, '日本');
    });

    test('呼び方も国名に合っている', () {
      expect(World.byId('yamato').demonym, '日本人');
      expect(World.byId('albion').demonym, 'イングランド人');
    });
  });
}
