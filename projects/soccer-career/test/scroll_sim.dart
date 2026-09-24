// ignore_for_file: avoid_print
/// 各タブが**スマホ1画面の何倍あるか**を測る道具。
///
/// `flutter test test/scroll_sim.dart`。`_test.dart` で終わらないので CI では走らない。
///
/// 画面構成を触ったら回す。**「多い気がする」を数字にしないと直せない。**
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/ui/screens/hub_screen.dart';

import 'ui_test.dart' as ui_test;

void main() {
  testWidgets('tab heights', (tester) async {
    final controller = await ui_test.newCareer(
      age: 24,
      hallRepository: ui_test.MemoryHall(),
    );
    for (var i = 0; i < 9; i++) {
      if (controller.pendingEvent != null) {
        await controller.resolveEvent(controller.pendingEvent!.choices.first);
      }
      await controller.simulateMatch();
    }
    while (controller.state!.pendingInternational ||
        controller.state!.pendingCup != null) {
      await controller.simulateMatch();
    }

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: HubScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    // タブバーと見出しを引いた、実際に見えている高さ。
    const viewport = 844.0 - 56.0 - 48.0;
    print('viewport ${viewport.toStringAsFixed(0)}px');
    print('');
    print('tab      extent  screens');
    const keys = {
      '今週': 'tab-match',
      '選手': 'tab-player',
      '育成': 'tab-training',
      'クラブ': 'tab-club',
      '記録': 'tab-career',
    };
    for (final tab in keys.keys) {
      await tester.tap(find.widgetWithText(Tab, tab));
      await tester.pumpAndSettle();
      final list = find.byKey(PageStorageKey(keys[tab]!));
      final state = tester.state<ScrollableState>(
        find.descendant(of: list, matching: find.byType(Scrollable)).first,
      );
      // ListView は遅延構築なので、底まで落とさないと
      // maxScrollExtent は見積もりのまま。
      var last = 0.0;
      for (var i = 0; i < 40; i++) {
        final max = state.position.maxScrollExtent;
        if (max <= last) break;
        last = max;
        state.position.jumpTo(max);
        await tester.pumpAndSettle();
      }
      // 直の子を上から順に、高さと最初の文字で並べる。
      // Card だけを数えると Card でないもの（選手証・能力の形）が漏れる。
      final seen = <int>{};
      final rows = <String>[];
      var bottom = 0.0;
      for (var offset = 0.0; offset <= last; offset += 200) {
        state.position.jumpTo(offset);
        await tester.pumpAndSettle();
        final sliver = tester
            .renderObject<RenderViewport>(
              find.descendant(of: list, matching: find.byType(Viewport)),
            )
            .firstChild!;
        final listSliver = sliver is RenderSliverPadding
            ? sliver.child! as RenderSliverList
            : sliver as RenderSliverList;
        RenderBox? child = listSliver.firstChild;
        while (child != null) {
          final data = child.parentData! as SliverMultiBoxAdaptorParentData;
          final foot = (data.layoutOffset ?? 0) + child.size.height;
          if (foot > bottom) bottom = foot;
          if (seen.add(data.index!)) {
            final texts = find
                .descendant(
                  of: find.byElementPredicate((e) => e.renderObject == child),
                  matching: find.byType(Text),
                )
                .evaluate();
            final label = texts.isEmpty
                ? ''
                : ((texts.first.widget as Text).data ?? '');
            if (child.size.height >= 40) {
              rows.add(
                '${data.index.toString().padLeft(2)} '
                '@${(data.layoutOffset ?? -1).toStringAsFixed(0).padLeft(5)} '
                '${child.size.height.toStringAsFixed(0).padLeft(4)}px  '
                '${label.length > 20 ? '${label.substring(0, 20)}…' : label}',
              );
            }
          }
          child = listSliver.childAfter(child);
        }
      }
      // 一番下の子の底 ＋ 上下の余白。
      final extent = 16 + bottom + 96;
      print(
        '${tab.padRight(8)} ${extent.toStringAsFixed(0).padLeft(5)}px '
        '${(extent / viewport).toStringAsFixed(1).padLeft(6)}',
      );
      for (final row in rows) {
        print('    $row');
      }
      state.position.jumpTo(0);
      await tester.pumpAndSettle();
    }
  });
}
