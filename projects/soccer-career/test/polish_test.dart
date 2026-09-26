/// **後半15年に、積むものがあるか。**
///
/// 25歳を過ぎると伸びる週は 10% を切る（実測: 28〜37歳で 4〜7%、
/// つまり20週に1回）。残りの週は練習を選んでも何も起きず、
/// 引退までの13年・約680週が「疲労を調整するだけ」になっていた。
///
/// 能力が伸びなくなった選手は、代わりに覚えた技を磨く。
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/game/formulas.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/development.dart';
import 'package:soccer_career/models/player.dart';
import 'package:soccer_career/models/training.dart';

Player _player({required int age, required int value, int potential = 99}) =>
    Player(
      name: 'テスト',
      position: Position.st,
      age: age,
      potential: potential,
      attributes: Attributes.fromDetails({
        for (final detail in Detail.values) detail: value,
      }),
    );

/// 200週ぶん練習して、磨かれた回数を数える。
(int polished, Development end) _train(
  Player player, {
  required Development development,
}) {
  final engine = MatchEngine(random: Random(3));
  var current = development;
  var count = 0;
  for (var week = 0; week < 200; week++) {
    final outcome = engine.applyWeek(
      player,
      menu: TrainingMenu.finishingWork,
      development: current,
      played: true,
    );
    if (outcome.polished != null) {
      count++;
      current = current.polish(outcome.polished!);
    }
  }
  return (count, current);
}

void main() {
  const learned = Development(signatures: [Signature.placement]);

  test('若いうちは磨けない', () {
    // 伸びる確率が 1 を超えているので、余りが無い。
    final (count, _) = _train(_player(age: 18, value: 60), development: learned);
    expect(count, 0);
  });

  test('伸びなくなった歳から磨かれる', () {
    final (count, end) = _train(
      _player(age: 32, value: 90),
      development: learned,
    );
    expect(count, greaterThan(0));
    expect(end.masteryOf(Signature.placement), greaterThan(0));
  });

  test('覚えていない技は磨けない', () {
    final (count, _) = _train(
      _player(age: 32, value: 90),
      development: const Development(),
    );
    expect(count, 0);
  });

  test('その練習で扱わない技は磨けない', () {
    // シュート練習では、パスの技は磨かれない。
    final (count, _) = _train(
      _player(age: 32, value: 90),
      development: const Development(signatures: [Signature.noLook]),
    );
    expect(count, 0);
  });

  test('上限まで磨いたら止まる', () {
    var development = const Development(signatures: [Signature.placement]);
    for (var i = 0; i < 20; i++) {
      development = development.polish(Signature.placement);
    }
    expect(development.masteryOf(Signature.placement), Signature.maxMastery);
    expect(development.polishable([AttributeKey.shooting]), isEmpty);
  });

  test('磨くほど、噛み合った手が深くなる', () {
    var development = const Development(signatures: [Signature.placement]);
    final before = development.signatureBonus(
      AttributeKey.shooting,
      Detail.finishing,
    );
    development = development.polish(Signature.placement);
    final after = development.signatureBonus(
      AttributeKey.shooting,
      Detail.finishing,
    );
    expect(after - before, closeTo(Formulas.signaturePerMastery, 1e-9));

    // **噛み合っていない手は深くならない。**
    // 広く薄く効かせると「常に少し効く飾り」に戻る。
    expect(
      development.signatureBonus(AttributeKey.shooting, Detail.longShots),
      Formulas.signatureOnKey,
    );
  });

  test('磨きは、保存して読み直しても残る', () {
    final development = const Development(
      signatures: [Signature.placement],
    ).polish(Signature.placement);
    final back = Development.fromJson(development.toJson());
    expect(back.masteryOf(Signature.placement), 1);

    // 磨きを知らない保存データは「まだ磨いていない」で読む。
    final old = development.toJson()..remove('mastery');
    expect(Development.fromJson(old).masteryOf(Signature.placement), 0);
  });
}
