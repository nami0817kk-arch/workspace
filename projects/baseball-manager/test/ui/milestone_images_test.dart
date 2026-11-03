import 'package:baseball_manager/ui/controller.dart';
import 'package:baseball_manager/ui/milestone_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<bool> _hasImage(WidgetTester t, Milestone m) async {
  await t.pumpWidget(MaterialApp(
      home: Scaffold(body: Center(child: MilestoneDialog(milestone: m)))));
  await t.pump();
  return find.byKey(const Key('milestone-image')).evaluate().isNotEmpty;
}

void main() {
  testWidgets('節目の絵(2026-11-03): タイトル・日本代表・世界一・進学・覚醒に絵が出る', (t) async {
    expect(
        await _hasImage(
            t, const Milestone(MilestoneKind.title, 'タイトル獲得!', '首位打者')),
        isTrue);
    expect(
        await _hasImage(
            t, const Milestone(MilestoneKind.national, '日本代表に選出!', 'x')),
        isTrue);
    expect(
        await _hasImage(t, const Milestone(MilestoneKind.world, '世界一!', 'x')),
        isTrue);
    expect(await _hasImage(t, const Milestone(MilestoneKind.stage, '高校へ', 'x')),
        isTrue);
    expect(
        await _hasImage(t, const Milestone(MilestoneKind.trait, '才能が覚醒!', 'x')),
        isTrue);
    expect(t.takeException(), isNull);
  });

  testWidgets('同じ種類でも絵が合わない節目には出さない(海外移籍・一軍昇格)', (t) async {
    expect(
        await _hasImage(t, const Milestone(MilestoneKind.world, '海を渡る!', 'x')),
        isFalse);
    expect(
        await _hasImage(t, const Milestone(MilestoneKind.stage, '一軍昇格!', 'x')),
        isFalse);
  });
}
