import 'package:baseball_manager/ui/art/story_image.dart';
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

  testWidgets('海外移籍・一軍昇格にも絵が出る(2026-11-03 夜)。合う絵の無い節目には出さない', (t) async {
    expect(
        await _hasImage(t, const Milestone(MilestoneKind.world, '海を渡る!', 'x')),
        isTrue);
    expect(
        await _hasImage(t, const Milestone(MilestoneKind.stage, '一軍昇格!', 'x')),
        isTrue);
    expect(
        await _hasImage(
            t, const Milestone(MilestoneKind.achievement, '育成ミッション達成!', 'x')),
        isTrue);
    expect(await _hasImage(t, const Milestone(MilestoneKind.world, '準優勝', 'x')),
        isFalse);
    expect(t.takeException(), isNull);
  });

  test('山場の出来事(決勝の見せ場・戦力外通告)にだけ絵を添える', () {
    expect(eventImageOf('final-moment')?.$1, finalMomentImageAsset);
    expect(eventImageOf('tryout')?.$1, tryoutImageAsset);
    expect(eventImageOf('rain-day'), isNull);
  });
}
