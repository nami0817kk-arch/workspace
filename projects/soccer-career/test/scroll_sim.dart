// ignore_for_file: avoid_print
/// 各タブが**スマホ1画面の何倍あるか**を測る道具。
///
/// `flutter test test/scroll_sim.dart`。`_test.dart` で終わらないので CI では走らない。
///
/// 画面構成を触ったら回す。**「多い気がする」を数字にしないと直せない。**
///
/// **英語でも測る**（`--dart-define=LANG=en`）。英語は手の名前が長く、
/// 日本語なら1行で収まるものが2行になるので、同じ画面でも高さが違う。
/// `shots.dart` と同じ形。
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/l10n/lang.dart';
import 'package:soccer_career/ui/screens/hub_screen.dart';
import 'package:soccer_career/ui/fixture_banner.dart';
import 'package:soccer_career/ui/pitch_view.dart';
import 'package:soccer_career/ui/screens/match_screen.dart';
import 'package:soccer_career/ui/stat_tile.dart';

import 'ui_test.dart' as ui_test;

const String _lang = String.fromEnvironment('LANG');

void main() {
  setUpAll(() {
    if (_lang == 'en') Language.setForTest(Lang.en);
  });

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
    // 節に割ったタブは、札を押して両方測る。
    // **タブの字は言語で変わる。** 鍵（`tab-match` ほか）は日本語版と英語版を
    // 1行ずつ突き合わせるためのものなので、ASCII のまま固定する（`shots.dart`
    // が絵の名前を日本語で固定してあるのと同じ理屈）。
    final keys = {
      tr('今週', 'Week'): 'tab-match',
      '${tr('選手', 'Player')}|${tr('能力', 'Attributes')}': 'tab-player',
      '${tr('選手', 'Player')}|${tr('人となり', 'The person')}': 'tab-player-person',
      '${tr('育成', 'Training')}|${tr('今週決める', 'Decide this week')}': 'tab-training',
      '${tr('育成', 'Training')}|${tr('長い目で狙う', 'The long game')}': 'tab-training-aim',
      '${tr('クラブ', 'Club')}|${tr('立ち位置', 'Where you stand')}': 'tab-club',
      '${tr('クラブ', 'Club')}|${tr('この国と、世界', 'This country, and the world')}': 'tab-club-world',
      '${tr('記録', 'Record')}|${tr('今季', 'This season')}': 'tab-career',
      '${tr('記録', 'Record')}|${tr('これまで', 'So far')}': 'tab-career-total',
    };
    for (final tab in keys.keys) {
      final parts = tab.split('|');
      await tester.tap(find.widgetWithText(Tab, parts.first));
      await tester.pumpAndSettle();
      if (parts.length > 1) {
        await tester.tap(find.text(parts[1]));
        await tester.pumpAndSettle();
      }
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

  /// 試合画面で、**3つの手がスクロールせずに全部見えるか**。
  ///
  /// このゲームの中核は「試合中の選択」なのに、比べる相手が画面の外にあると
  /// 比べようがない。見えている高さ（844 − 下の帯）に対して、
  /// 各手の上端・下端がどこに来るかを測る。
  testWidgets('match screen fold', (tester) async {
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

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // 出られない週だと局面が立たない（shots.dart と同じ穴）。
    for (var i = 0; i < 80; i++) {
      while (controller.state!.pendingInternational ||
          controller.state!.pendingCup != null) {
        await controller.simulateMatch();
      }
      controller.startNextMatch();
      final m = controller.currentMatch;
      if (m != null && !m.isFinished) break;
      await controller.simulateMatch();
    }

    var folded = 0;
    var samples = 0;
    final match = controller.currentMatch!;
    while (!match.isFinished) {
      await tester.pumpWidget(
        MaterialApp(home: MatchScreen(controller: controller)),
      );
      await tester.pumpAndSettle();
      final buttons = find.byType(OutlinedButton).evaluate().toList();
      if (buttons.length >= 3) {
        samples++;
        if (true) {
          // 手より上に、何が何px積まれているか。
          for (final part in {
            '対戦カード': find.byType(FixtureBanner),
            '数字の行': find.byType(StatTile),
            'ピッチ': find.byType(PitchView),
            '局面のカード': find.byType(Card),
          }.entries) {
            final found = part.value.evaluate();
            if (found.isEmpty) continue;
            final box = found.first.renderObject! as RenderBox;
            print(
              '  ${part.key.padRight(8)} '
              '上${box.localToGlobal(Offset.zero).dy.toStringAsFixed(0).padLeft(4)} '
              '高${box.size.height.toStringAsFixed(0).padLeft(4)}px',
            );
          }
        }
        print(
          '局面 ${match.currentIndex + 1}/${match.scenarios.length}'
          '',
        );
        for (var i = 0; i < buttons.length; i++) {
          final box = buttons[i].renderObject! as RenderBox;
          final top = box.localToGlobal(Offset.zero).dy;
          final foot = top + box.size.height;
          // **見えている高さは測る。** 「下の帯でおよそ90px」と当て推量で
          // 置いていたが、実際に見えているのはスクロールの枠そのもの
          // （指標そのものを疑う）。
          final view = tester.renderObject<RenderBox>(
            find.byType(SingleChildScrollView).first,
          );
          final fold = view.localToGlobal(Offset.zero).dy + view.size.height;
          final hidden = foot > fold;
          if (hidden) folded++;
          print(
            '  手${i + 1}  上${top.toStringAsFixed(0).padLeft(4)} '
            '下${foot.toStringAsFixed(0).padLeft(4)} '
            '高${box.size.height.toStringAsFixed(0).padLeft(3)}px'
            '${hidden ? '  ← 画面の外' : ''}',
          );
        }
      }
      controller.choose(0);
    }
    print('');
    print('局面 $samples 個のうち、画面の外に出た手 $folded');
  });
}
