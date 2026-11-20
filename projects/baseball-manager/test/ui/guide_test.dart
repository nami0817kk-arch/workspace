import 'dart:math';

import 'package:baseball_manager/game/player.dart';
import 'package:baseball_manager/ui/app.dart';
import 'package:baseball_manager/ui/controller.dart';
import 'package:baseball_manager/ui/guide_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void _tall(WidgetTester t) {
  t.view.physicalSize = const Size(900, 3000);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('最初の選手を始めたとき、ガイドが出る。最後まで進めると二度と出ない', (t) async {
    SharedPreferences.setMockInitialValues({});
    _tall(t);
    final c = GameController(rng: Random(1), autoGuide: true);
    await c.loadSaved();
    await t.pumpWidget(BaseballManagerApp(controller: c));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('guide-dialog')), findsNothing);
    c.newGame('テスト', Role.batter);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('guide-dialog')), findsOneWidget);
    expect(find.text(guidePages.first.title), findsOneWidget);
    // 次へ、で最後のページまで進める
    for (var i = 0; i < guidePages.length - 1; i++) {
      await t.tap(find.byKey(const Key('guide-next')));
      await t.pumpAndSettle();
    }
    expect(find.text(guidePages.last.title), findsOneWidget);
    expect(find.text('はじめる'), findsOneWidget);
    await t.tap(find.byKey(const Key('guide-next')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('guide-dialog')), findsNothing);
    expect(c.guideSeen, isTrue);
    // 保存され、次の選手・次の起動では出ない
    final c2 = GameController(rng: Random(2), autoGuide: true);
    await c2.loadSaved();
    expect(c2.guideSeen, isTrue);
    c2.newGame('二人目', Role.pitcher);
    expect(c2.guidePending, isFalse);
  });

  testWidgets('スキップでも閉じて、見たことになる。設定からもう一度見られる', (t) async {
    SharedPreferences.setMockInitialValues({});
    _tall(t);
    final c = GameController(rng: Random(1), autoGuide: true);
    await c.loadSaved();
    await t.pumpWidget(BaseballManagerApp(controller: c));
    await t.pumpAndSettle();
    c.newGame('テスト', Role.batter);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('guide-skip')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('guide-dialog')), findsNothing);
    expect(c.guideSeen, isTrue);
    // 設定から開く
    await t.tap(find.byKey(const Key('settings-open')));
    await t.pumpAndSettle();
    await t.ensureVisible(find.byKey(const Key('guide-open')));
    await t.tap(find.byKey(const Key('guide-open')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('guide-dialog')), findsOneWidget);
    await t.tap(find.byKey(const Key('guide-skip')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('guide-dialog')), findsNothing);
  });

  testWidgets('テスト用の既定(autoGuide なし)では、出ない', (t) async {
    SharedPreferences.setMockInitialValues({});
    _tall(t);
    final c = GameController(rng: Random(1));
    await t.pumpWidget(BaseballManagerApp(controller: c));
    await t.pumpAndSettle();
    c.newGame('テスト', Role.batter);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('guide-dialog')), findsNothing);
  });

  testWidgets('狭い画面・大きい文字でも、ガイドが溢れない', (t) async {
    SharedPreferences.setMockInitialValues({});
    t.view.physicalSize = const Size(320, 700);
    t.view.devicePixelRatio = 1.0;
    t.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    final c = GameController(rng: Random(1), autoGuide: true);
    await c.loadSaved();
    await t.pumpWidget(BaseballManagerApp(controller: c));
    await t.pumpAndSettle();
    c.newGame('テスト', Role.batter);
    await t.pumpAndSettle();
    for (var i = 0; i < guidePages.length; i++) {
      expect(t.takeException(), isNull, reason: 'ページ$i');
      await t.tap(find.byKey(const Key('guide-next')));
      await t.pumpAndSettle();
    }
  });
}
