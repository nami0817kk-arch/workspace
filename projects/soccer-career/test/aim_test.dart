/// 狙って取りに行けるか。
///
/// ここで守りたいのは3つ。
/// - 狙っても**能力は要る**（78に届くまで付かない）
/// - 狙っている間は**他のものを覚えない**（枠を空けて待つ）
/// - 狙いは**シーズンを跨いで残る**（オフに外れると、狙った意味が無い）
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/game/formulas.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/development.dart';
import 'package:soccer_career/models/player.dart';
import 'package:soccer_career/models/training.dart';
import 'package:soccer_career/models/career.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/data/save_repository.dart';
import 'package:soccer_career/state/career_controller.dart';
import 'dart:math';

Player _striker({required int longShots, required int finishing}) {
  return Player(
    name: 'テスト',
    position: Position.st,
    age: 24,
    potential: 90,
    attributes: Attributes.fromDetails({
      for (final detail in Detail.values) detail: 60,
      Detail.longShots: longShots,
      Detail.finishing: finishing,
    }),
  );
}

/// 1年ぶん練習して、覚えた個人技を集める。
List<Signature> _train(
  Player player, {
  Signature? aim,
  Development development = const Development(),
}) {
  final engine = MatchEngine(random: Random(7));
  final learned = <Signature>[];
  var current = development;
  for (var week = 0; week < 200; week++) {
    final outcome = engine.applyWeek(
      player,
      menu: TrainingMenu.finishingWork,
      development: current,
      signatureAim: aim,
      played: true,
    );
    if (outcome.learned != null) {
      learned.add(outcome.learned!);
      current = current.learn(outcome.learned!, position: player.position);
    }
  }
  return learned;
}

class _MemoryRepository implements SaveRepository {
  CareerState? _saved;

  @override
  Future<CareerState?> load() async => _saved;

  @override
  Future<void> save(CareerState state) async => _saved = state;

  @override
  Future<void> clear() async => _saved = null;
}

void main() {
  test('狙っても、能力が届いていなければ何も付かない', () {
    // ボレーは longShots が 78 で覚えられる。70 では届かない。
    final learned = _train(
      _striker(longShots: 70, finishing: 70),
      aim: Signature.volley,
    );
    expect(learned, isEmpty);
  });

  test('狙っている間は、他のものを覚えない', () {
    // finishing は届いていて「流し込み」を覚えられるが、ボレーを狙っている。
    final learned = _train(
      _striker(longShots: 70, finishing: 90),
      aim: Signature.volley,
    );
    expect(learned, isEmpty);
  });

  test('狙わなければ、届いているものを覚える', () {
    final learned = _train(_striker(longShots: 70, finishing: 90));
    expect(learned, contains(Signature.placement));
  });

  test('届いていれば、狙ったものを覚える', () {
    final learned = _train(
      _striker(longShots: 90, finishing: 90),
      aim: Signature.volley,
    );
    expect(learned.first, Signature.volley);
  });

  test('狙いは、保存して読み直しても残る', () async {
    final controller = CareerController(
      repository: _MemoryRepository(),
      careerEngine: CareerEngine(random: Random(5)),
      matchEngine: MatchEngine(random: Random(5)),
      random: Random(5),
    );
    await controller.startCareer(
      name: '検証',
      position: Position.st,
      age: 20,
      agent: Agent.pool.first,
    );
    await controller.aimSignature(Signature.volley);
    final state = controller.state!;
    expect(state.signatureAim, Signature.volley);
    expect(CareerState.fromJson(state.toJson()).signatureAim, Signature.volley);

    // **狙いを知らない保存データは「狙っていない」で読む。**
    final old = state.toJson()..remove('signatureAim');
    expect(CareerState.fromJson(old).signatureAim, isNull);

    // もう一度同じものを選べば、狙いを外す。
    await controller.aimSignature(Signature.volley);
    expect(controller.state!.signatureAim, isNull);
  });

  test('狙いは、シーズンを跨いでも残る', () async {
    // **一度これで落ちた。** `advanceSeason` は `CareerState` を組み直すので、
    // 渡し忘れた項目はオフに黙って消える。狙いが毎年外れていたせいで、
    // 取得率が 30.5% → 31.0% しか動かなかった。
    final controller = CareerController(
      repository: _MemoryRepository(),
      careerEngine: CareerEngine(random: Random(11)),
      matchEngine: MatchEngine(random: Random(11)),
      random: Random(11),
    );
    await controller.startCareer(
      name: '検証',
      position: Position.st,
      age: 20,
      agent: Agent.pool.first,
    );
    // 届かないものを狙う。届いてしまうと覚えて、狙いが外れる。
    await controller.aimSignature(Signature.spring);
    final startYear = controller.state!.year;
    var guard = 0;
    while (controller.state!.fixtures.isNotEmpty && guard++ < 200) {
      await controller.simulateMatch();
    }
    final offers = [
      if (controller.renewalOffer != null) controller.renewalOffer!,
      ...controller.offers,
    ];
    expect(offers, isNotEmpty);
    await controller.advanceSeason(accepted: offers.first);
    expect(controller.state!.year, greaterThan(startYear));
    expect(controller.state!.signatureAim, Signature.spring);
  });

  test('狙ったほうが速い', () {
    expect(
      Formulas.signatureAimChance,
      greaterThan(Formulas.signatureChance),
    );
  });
}
