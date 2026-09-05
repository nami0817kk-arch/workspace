import 'package:flutter_test/flutter_test.dart';

import 'package:soccer_manager/logic/attribute_context_engine.dart';
import 'package:soccer_manager/logic/match_engine.dart';
import 'package:soccer_manager/models/attributes.dart';
import 'package:soccer_manager/models/league.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/models/team.dart';

/// 「この選手で効いている能力」。
///
/// 能力値は全員に42項目ある。FW のタックルも GK のクロスも並んでいて、
/// どれを見ればいいのかが分からない。数字は出ているのに判断に使えない
/// 状態だった。
///
/// ここで拾うのは、**実際に計算へ使われているもの**だけ。それらしい指標を
/// 見繕うと、画面の説明と試合の結果が結びつかなくなる。
void main() {
  Player make({
    Position position = Position.st,
    PlayerRole role = PlayerRole.standard,
    PlayerTrait? trait,
    int value = 50,
  }) {
    final p = Player(
      id: 'p',
      name: 'p',
      age: 25,
      position: position,
      potential: 85,
      matchSharpness: 80,
    );
    for (final k in AttributeKeys.all) {
      p.setAttributeValue(k, value);
    }
    p.role = role;
    p.trait = trait;
    return p;
  }

  group('拾う根拠', () {
    test('ロールが見ている能力が入る', () {
      final role = PlayerRole.values.firstWhere(
        (r) => r.keyAttributes.isNotEmpty,
      );
      final p = make(position: Position.gk, role: role);

      final keys =
          AttributeContextEngine.keyAttributesFor(p).map((k) => k.key).toSet();

      for (final expected in role.keyAttributes) {
        expect(keys, contains(expected),
            reason: 'ロールが見ている $expected が拾われていない');
      }
    });

    test('特性の発動条件になっている能力が入る', () {
      final entry = MatchEngine.attributeGatedTraits.entries.first;
      final p = make(trait: entry.key);

      final keys =
          AttributeContextEngine.keyAttributesFor(p).map((k) => k.key).toSet();

      expect(keys, contains(entry.value.attribute));
    });

    test('ポジションの総合力に効く能力が入る', () {
      final p = make(position: Position.st);
      final keys =
          AttributeContextEngine.keyAttributesFor(p).map((k) => k.key).toSet();
      expect(keys, contains(AttributeKeys.finishing));
    });

    test('同じ能力が二重に並ばない', () {
      final p = make(position: Position.st, trait: PlayerTrait.clinicalFinisher);
      final result = AttributeContextEngine.keyAttributesFor(p);
      final keys = result.map((k) => k.key).toList();
      expect(keys.length, keys.toSet().length,
          reason: '同じ行が並ぶと読みづらいだけ');
    });

    test('特性の条件は、ポジションの理由より優先して説明される', () {
      // 決定力は FW の総合力にも効くが、特性の発動条件でもある。
      // 「特性が死んでいる」ことの方が重要なので、そちらを出す。
      final p = make(position: Position.st, trait: PlayerTrait.clinicalFinisher);
      final finishing = AttributeContextEngine.keyAttributesFor(p)
          .firstWhere((k) => k.key == AttributeKeys.finishing);
      expect(finishing.reason, AttributeReason.traitGate);
    });
  });

  group('リーグとの比較', () {
    League leagueOf(int othersValue) {
      final others = [
        for (int i = 0; i < 10; i++)
          (make(value: othersValue)..setAttributeValue(AttributeKeys.finishing,
              othersValue)),
      ];
      return League(
        teams: [Team(id: 'o', name: 'O', players: others)],
        fixtures: const [],
      );
    }

    test('リーグの同じポジション大分類の平均と比べる', () {
      final avg = AttributeContextEngine.leagueAverageFor(
          leagueOf(40), PositionGroup.att, AttributeKeys.finishing);
      expect(avg, 40);
    });

    test('比べる相手がいなければ null（無理に順位を付けない）', () {
      final empty = League(
        teams: [Team(id: 'e', name: 'E', players: const [])],
        fixtures: const [],
      );
      expect(
        AttributeContextEngine.leagueAverageFor(
            empty, PositionGroup.att, AttributeKeys.finishing),
        isNull,
      );
    });

    test('平均より大きく上なら、上位として示す', () {
      final p = make(position: Position.st, value: 80);
      final k = AttributeContextEngine.keyAttributesFor(p, league: leagueOf(40))
          .firstWhere((k) => k.key == AttributeKeys.finishing);
      expect(k.standingLabel, isNotNull);
      expect(k.leagueAverage, 40);
    });

    test('リーグを渡さなければ、比較は出さない', () {
      final p = make(position: Position.st);
      final k = AttributeContextEngine.keyAttributesFor(p)
          .firstWhere((k) => k.key == AttributeKeys.finishing);
      expect(k.leagueAverage, isNull);
      expect(k.standingLabel, isNull);
    });
  });

  test('拾う能力はすべて実在する項目', () {
    for (final position in Position.values) {
      for (final key in AttributeContextEngine.positionKeyAttributes(position)) {
        expect(AttributeKeys.all, contains(key),
            reason: '$position が存在しない能力を指している');
      }
    }
  });
}
