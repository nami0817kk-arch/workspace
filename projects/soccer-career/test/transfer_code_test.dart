/// 引き継ぎコード。端末をまたいでキャリアを持ち運ぶための仕組み。
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/data/save_repository.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/career.dart';
import 'package:soccer_career/models/life.dart';
import 'package:soccer_career/state/career_controller.dart';

class _MemoryRepository implements SaveRepository {
  CareerState? saved;

  @override
  Future<CareerState?> load() async => saved;

  @override
  Future<void> save(CareerState state) async => saved = state;

  @override
  Future<void> clear() async => saved = null;
}

CareerState career({int seed = 3}) =>
    CareerEngine(random: Random(seed)).startCareer(
        name: '持ち運び', position: Position.am, age: 19, agent: Agent.pool[2]);

void main() {
  test('コードにしてから戻すと、キャリアがそのまま復元される', () {
    final state = career();
    state.morale = const Morale(value: 77);
    state.player = state.player.copyWith(condition: 61);

    final code = SaveRepository.encode(state);
    expect(code.startsWith(SaveRepository.codePrefix), isTrue);

    final restored = SaveRepository.decode(code)!;
    expect(restored.player.name, state.player.name);
    expect(restored.player.overall, state.player.overall);
    expect(restored.player.condition, 61);
    expect(restored.club.name, state.club.name);
    expect(restored.year, state.year);
    expect(restored.morale.value, 77);
    expect(restored.league.length, state.league.length);
  });

  test('読めないコードは null。前後の空白は気にしない', () {
    expect(SaveRepository.decode('ただの文字列'), isNull);
    expect(SaveRepository.decode('SC1:これはbase64ではない'), isNull);
    expect(SaveRepository.decode(''), isNull);

    final code = SaveRepository.encode(career());
    expect(SaveRepository.decode('  $code \n'), isNotNull);
    // 形式が違うものは、頭で弾く。
    expect(SaveRepository.decode(code.substring(4)), isNull);
  });

  test('読めないコードで、今のキャリアを消さない', () async {
    final repository = _MemoryRepository();
    final controller = CareerController(
      repository: repository,
      careerEngine: CareerEngine(random: Random(1)),
      matchEngine: MatchEngine(random: Random(1)),
      random: Random(1),
    );
    await controller.startCareer(
      name: '元の選手',
      position: Position.cm,
      age: 20,
      agent: Agent.pool.first,
    );

    final ok = await controller.importCode('SC1:こわれている');
    expect(ok, isFalse);
    expect(controller.state!.player.name, '元の選手');
  });

  test('別の端末のコードを読み込むと、そのキャリアに入れ替わる', () async {
    final other = career(seed: 9);
    final code = SaveRepository.encode(other);

    final repository = _MemoryRepository();
    final controller = CareerController(
      repository: repository,
      careerEngine: CareerEngine(random: Random(1)),
      matchEngine: MatchEngine(random: Random(1)),
      random: Random(1),
    );
    await controller.startCareer(
      name: '元の選手',
      position: Position.cm,
      age: 20,
      agent: Agent.pool.first,
    );

    expect(await controller.importCode(code), isTrue);
    expect(controller.state!.player.name, other.player.name);
    expect(controller.state!.club.name, other.club.name);
    // 保存にも入っている（アプリを閉じても残る）。
    expect(repository.saved!.player.name, other.player.name);
  });

  test('キャリアが無ければコードは作れない', () {
    final controller = CareerController(repository: _MemoryRepository());
    expect(controller.exportCode(), isNull);
  });
}
