import 'package:flutter_test/flutter_test.dart';

import 'package:soccer_manager/logic/match_engine.dart';
import 'package:soccer_manager/models/attributes.dart';
import 'package:soccer_manager/models/player.dart';

/// 特性の効果。
///
/// 54種のうち25種は「能力値がある水準に届いて初めて発動する」形で、
/// 届いていなければ何も起きない。その条件は実装の中にしか無く、画面には
/// 出ていなかったため、**特性を持っているのに効果が無い状態が説明されない
/// まま**だった。「特性の効果が分かりにくい」という声はここが原因。
void main() {
  Player make({required String attribute, required int value}) {
    final p = Player(
      id: 'p',
      name: 'p',
      age: 26,
      position: Position.st,
      potential: 90,
      matchSharpness: 80,
    );
    for (final k in AttributeKeys.all) {
      p.setAttributeValue(k, 50);
    }
    p.setAttributeValue(attribute, value);
    return p;
  }

  group('発動条件の表', () {
    test('表に載っている特性は、すべて実在する能力値を指している', () {
      for (final entry in MatchEngine.attributeGatedTraits.entries) {
        expect(AttributeKeys.all, contains(entry.value.attribute),
            reason: '${entry.key.name} が存在しない能力値を指している');
      }
    });

    test('効果は必ず 1.0 より大きい(発動しても損をしない)', () {
      for (final entry in MatchEngine.attributeGatedTraits.entries) {
        expect(entry.value.bonus, greaterThan(1.0),
            reason: '${entry.key.name} の効果が 1.0 以下');
      }
    });

    test('閾値は達成しうる範囲にある', () {
      for (final entry in MatchEngine.attributeGatedTraits.entries) {
        expect(entry.value.threshold, inInclusiveRange(1, 100),
            reason: '${entry.key.name} の条件が達成不可能');
      }
    });
  });

  group('判定が表のとおりに効く', () {
    test('条件を満たすと効果が出る', () {
      for (final entry in MatchEngine.attributeGatedTraits.entries) {
        final p = make(
            attribute: entry.value.attribute, value: entry.value.threshold);
        final bonus =
            MatchEngine.gatedTraitBonus(entry.key, (k) => p.attributeValue(k).toDouble());
        expect(bonus, entry.value.bonus,
            reason: '${entry.key.name} が条件を満たしても発動していない');
      }
    });

    test('条件に1足りないと何も起きない', () {
      for (final entry in MatchEngine.attributeGatedTraits.entries) {
        final p = make(
            attribute: entry.value.attribute,
            value: entry.value.threshold - 1);
        final bonus =
            MatchEngine.gatedTraitBonus(entry.key, (k) => p.attributeValue(k).toDouble());
        expect(bonus, 1.0,
            reason: '${entry.key.name} が条件未満で発動している');
      }
    });

    test('表に無い特性は、この仕組みでは何も起きない', () {
      // 年齢や状況で決まる特性(oldHead など)は別の判定を通る。
      // ここで勝手に効いてしまうと二重に効く。
      final p = make(attribute: AttributeKeys.finishing, value: 99);
      expect(
        MatchEngine.gatedTraitBonus(
            PlayerTrait.oldHead, (k) => p.attributeValue(k).toDouble()),
        1.0,
      );
    });
  });

  test('全54特性のうち、能力値で発動するものは表に集約されている', () {
    // 表と判定が別々に書かれていると、片方だけ直したときに
    // 「画面の説明と実際の効果が食い違う」状態になる。
    expect(MatchEngine.attributeGatedTraits, isNotEmpty);
    expect(MatchEngine.attributeGatedTraits.length,
        lessThan(PlayerTrait.values.length),
        reason: '状況で決まる特性まで表に入っていると、条件の説明が誤りになる');
  });
}
