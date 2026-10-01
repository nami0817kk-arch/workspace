/// **遊び方ガイドが、実装と食い違っていないか。**
///
/// 2026-09-22 に見直したら、9/10 以降に入れた仕組みの大半が載っておらず、
/// 残っていた記述のうち5か所が嘘になっていた。仕組みを足すときに
/// ガイドを書き忘れても、ここで落ちるようにする。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/game/formulas.dart';
import 'package:soccer_career/ui/fixture_banner.dart';
import 'package:soccer_career/ui/pitch_view.dart';
import 'package:soccer_career/ui/screens/guide_screen.dart';
import 'package:soccer_career/ui/stat_tile.dart';

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
      '2つ以上で達成',
      '出た試合',
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

  // 「実際の画面」は、**絵ではなく本物のウィジェット**でなければならない。
  // 写真を貼ると、画面を直したときにガイドだけが黙って古くなる——
  // 数字を手で書き写すのと同じ腐り方。ここが落ちたら、貼った絵を疑う。
  for (final (section, widget) in <(String, Type)>[
    ('1週間の流れ', FixtureBanner),
    ('試合で選ぶ', PitchView),
    ('評価点と出場機会', StatTile),
  ]) {
    testWidgets('$section の「実際の画面」は、本物の $widget が描いている', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: GuideScreen()));
      expect(find.byType(widget), findsNothing);

      // 節は畳んであるので、見出しまでスクロールしてから開く。
      await tester.scrollUntilVisible(find.text(section), 200);
      // scrollUntilVisible は「組み立てられた」ところで止まるので、
      // 画面の外に半分出たままのことがある（実際に 607.5px で落ちた）。
      await tester.ensureVisible(find.text(section));
      await tester.pumpAndSettle();
      await tester.tap(find.text(section));
      await tester.pumpAndSettle();

      expect(find.text('実際の画面'), findsOneWidget);
      expect(find.byType(widget), findsWidgets);
    });
  }

  test('能力1の効きは、判定と同じ定数から出ている', () {
    // 手で書き写していた頃は、傾きを 0.009 → 0.012 にしても 0.9% のままだった。
    expect(
      text,
      contains('約${(Formulas.attributeChanceSlope * 100).toStringAsFixed(1)}%'),
    );
  });
}
