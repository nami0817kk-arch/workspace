import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/game/formulas.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/player.dart';

/// **衰えの行き先は、その週の練習で選ぶ**（2026-11-15）。
///
/// 以前は一定の確率で無作為の1項目が落ちるだけで、31歳から35歳でも
/// 総合力が 0.6 しか下がらず、後半の練習に「何を守るか」という意味が無かった。
Player _veteran({Position position = Position.cm, int age = 34}) => Player(
  name: 'V',
  age: age,
  position: position,
  attributes: Attributes.fromDetails({for (final d in Detail.values) d: 80}),
  potential: 80,
);

Map<AttributeKey, int> _declines({
  required List<AttributeKey> protect,
  Position position = Position.cm,
  int seeds = 600,
}) {
  final counts = <AttributeKey, int>{};
  for (var seed = 0; seed < seeds; seed++) {
    MatchEngine(random: Random(seed)).grow(
      _veteran(position: position),
      7.0,
      protect: protect,
      declined: (detail, _) =>
          counts[detail.category] = (counts[detail.category] ?? 0) + 1,
    );
  }
  return counts;
}

void main() {
  test('練習しているカテゴリには、衰えが当たらない', () {
    final counts = _declines(protect: const [AttributeKey.pace]);
    expect(counts[AttributeKey.pace] ?? 0, 0);
    expect(counts.values.fold(0, (a, b) => a + b), greaterThan(100));
  });

  test('衰えは走力と身体から来る', () {
    final counts = _declines(protect: const []);
    expect(
      counts[AttributeKey.pace]! / 2,
      greaterThan(counts[AttributeKey.passing]! / 3),
    );
    expect(
      counts[AttributeKey.physical]!,
      greaterThan(counts[AttributeKey.passing]!),
    );
  });

  test('フィールドの選手の衰えは、GK の能力に空振りしない', () {
    expect(_declines(protect: const [])[AttributeKey.goalkeeping], isNull);
    expect(
      _declines(protect: const [], position: Position.gk)[
          AttributeKey.goalkeeping],
      greaterThan(0),
    );
  });

  test('歳とともに衰えが速くなり、上限で止まる', () {
    expect(Formulas.declineChanceFor(0), Formulas.declineChanceBase);
    expect(Formulas.declineChanceFor(3), greaterThan(Formulas.declineChanceFor(0)));
    expect(Formulas.declineChanceFor(30), Formulas.declineChanceMax);
  });

  test('守っても、落ちる回数は変わらない', () {
    int total(List<AttributeKey> protect) =>
        _declines(protect: protect).values.fold(0, (a, b) => a + b);
    expect(total(const [AttributeKey.pace, AttributeKey.physical]),
        total(const []));
  });
}
