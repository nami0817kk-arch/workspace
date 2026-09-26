/// **コツと個人技は、その選手のものか。**
///
/// 実測（`test/craft_sim.dart`）で、**GK の95%が「無回転シュート」を覚え**、
/// CM の90%が「司令塔」を掴んでいた。伸びた詳細能力に自動で付き、
/// よく選ぶカテゴリの先頭が必ず取られるので、**同じポジションなら同じ**になる。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/game/formulas.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/development.dart';
import 'package:soccer_career/models/traits.dart';

void main() {
  group('個人技はポジションのもの', () {
    test('GK はフィールドの技を覚えない', () {
      // **GK の95%が「無回転シュート」を覚えていた。**
      final gk = Signature.forPosition(Position.gk);
      expect(gk, isNot(contains(Signature.knuckle)));
      expect(gk, isNot(contains(Signature.noLook)));
      expect(gk, contains(Signature.handsUp));
    });

    test('フィールドの選手は GK の技を覚えない', () {
      for (final position in Position.values) {
        if (position == Position.gk) continue;
        final owned = Signature.forPosition(position);
        expect(owned, isNot(contains(Signature.handsUp)), reason: '$position');
        expect(owned, isNot(contains(Signature.command)), reason: '$position');
      }
    });

    test('守る選手に決める技は付かない（ヘディングだけは別）', () {
      final cb = Signature.forPosition(Position.cb);
      expect(cb, isNot(contains(Signature.placement)));
      expect(cb, isNot(contains(Signature.volley)));
      // セットプレーの的になるので、打点だけは残す。
      expect(cb, contains(Signature.attackTheBall));
    });

    test('前線の選手に止める技は付かない', () {
      final st = Signature.forPosition(Position.st);
      expect(st, isNot(contains(Signature.timing)));
      expect(st, isNot(contains(Signature.bodyPosition)));
    });

    test('どのポジションにも、上限より多い選択肢がある', () {
      // **選べる数より覚えられる数が少ないと、全員が同じ顔で揃う。**
      for (final position in Position.values) {
        expect(
          Signature.forPosition(position).length,
          greaterThan(Signature.maxOwned),
          reason: '${position.label} の選択肢が足りない',
        );
      }
    });

    test('覚えられない技は、渡しても入らない', () {
      // **入口を1つに絞って見る。** 練習の側だけ直しても、
      // ピッチ外の出来事から漏れていた（実際に漏れていた）。
      const empty = Development();
      final forced = empty.learn(Signature.knuckle, position: Position.gk);
      expect(forced.signatures, isEmpty);
      final fine = empty.learn(Signature.handsUp, position: Position.gk);
      expect(fine.signatures, contains(Signature.handsUp));
    });
  });

  group('コツは場面ごとに割れる', () {
    test('1つの場面に、複数の掴みどころがある', () {
      // 得意技だけを並べていたので、掴むものが決め打ちになっていた。
      for (final key in AttributeKey.values) {
        final fromKey = Trait.knacks.where((t) => t.knackKey == key).length;
        expect(fromKey, greaterThanOrEqualTo(2), reason: '${key.label} が1つだけ');
      }
    });

    test('生まれつきでしか手に入らないものは掴めない', () {
      for (final trait in Trait.knacks) {
        expect(trait.rare, isFalse, reason: trait.label);
        expect(trait.flaw, isFalse, reason: trait.label);
      }
      expect(Trait.knacks, isNot(contains(Trait.earlyBloomer)));
      expect(Trait.knacks, isNot(contains(Trait.lateBloomer)));
    });
  });

  group('試合への効き', () {
    test('噛み合った手だけ深く、同じカテゴリは浅いまま', () {
      // **広く薄く効かせると「常に少し効く飾り」に戻る。**
      expect(
        Formulas.signatureOnDetail,
        greaterThan(Formulas.signatureOnKey * 3),
      );
      expect(Formulas.signatureOnDetail, greaterThanOrEqualTo(0.08));
    });

    test('内訳は、噛み合う手にだけ大きく出る', () {
      const dev = Development(signatures: [Signature.noLook]);
      final onDetail = dev.signatureBonus(AttributeKey.passing, Detail.vision);
      final onKey = dev.signatureBonus(AttributeKey.passing, Detail.crossing);
      final elsewhere = dev.signatureBonus(AttributeKey.defending, null);
      expect(onDetail, greaterThan(onKey));
      expect(elsewhere, 0);
    });

    test('切り札は、覚えた技より大きい', () {
      // 1試合に1回の判断なので、常時の上乗せより重くないと意味が無い。
      expect(
        Formulas.signatureArmedBonus,
        greaterThan(Formulas.signatureOnDetail),
      );
    });
  });
}
