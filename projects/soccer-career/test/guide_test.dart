/// **遊び方ガイドが、実装と食い違っていないか。**
///
/// 2026-09-22 に見直したら、9/10 以降に入れた仕組みの大半が載っておらず、
/// 残っていた記述のうち5か所が嘘になっていた。仕組みを足すときに
/// ガイドを書き忘れても、ここで落ちるようにする。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/game/formulas.dart';
import 'package:soccer_career/ui/screens/guide_screen.dart';

void main() {
  final text = guideText();

  test('今ある仕組みが、全部ガイドに載っている', () {
    for (final name in [
      'ノリ',
      '布石',
      '仕留め',
      '切り札',
      '役割',
      '約束',
      'コツ',
      '磨く',
      '1つ狙える',
      'じっくりやる試合',
      '構想外',
      '経験点',
      'どこまで踏み込むか',
      '誰と組むか',
      '控えとして呼ぶクラブ',
      '自分が出る試合',
      '契約が残っていても話が来る',
      '名前で選ぶ',
      '空く能力が1つ',
      '出場給',
    ]) {
      expect(text, contains(name), reason: name);
    }
  });

  test('もう嘘になった記述が残っていない', () {
    for (final stale in [
      '3つの局面',
      '約0.9%',
      '狙って取りには行けない',
      '長所が2つ付く',
      'ポテンシャルと特性は選べない',
    ]) {
      expect(text, isNot(contains(stale)), reason: stale);
    }
  });

  test('能力1の効きは、判定と同じ定数から出ている', () {
    // 手で書き写していた頃は、傾きを 0.009 → 0.012 にしても 0.9% のままだった。
    expect(
      text,
      contains('約${(Formulas.attributeChanceSlope * 100).toStringAsFixed(1)}%'),
    );
  });
}
