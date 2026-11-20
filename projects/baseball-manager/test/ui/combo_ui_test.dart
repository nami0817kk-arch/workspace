// 行動の連携の印(鎖)と、行動カードの1行(2026-10-28)。
import 'dart:math';

import 'package:baseball_manager/game/life.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:baseball_manager/ui/app.dart';
import 'package:baseball_manager/ui/controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<GameController> _open(WidgetTester t,
    {Size size = const Size(900, 3000), double text = 1.0}) async {
  SharedPreferences.setMockInitialValues({});
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1.0;
  t.platformDispatcher.textScaleFactorTestValue = text;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  final c = GameController(rng: Random(3));
  await t.pumpWidget(BaseballManagerApp(controller: c));
  await t.pumpAndSettle();
  c.newGame('鎖', Role.batter);
  c.recent = [];
  c.notifyListeners();
  await t.pumpAndSettle();
  return c;
}

void main() {
  testWidgets('研究のあとは、練習と特訓に鎖の印と連携の1行が出る', (t) async {
    final c = await _open(t);
    expect(find.byKey(const Key('combo-line')), findsNothing);
    c.game!.lastPlan = Plan.study;
    c.notifyListeners();
    await t.pumpAndSettle();
    expect(find.byKey(const Key('combo-train')), findsOneWidget);
    expect(find.byKey(const Key('combo-special')), findsOneWidget);
    expect(find.byKey(const Key('combo-rest')), findsNothing);
    expect(find.textContaining('研究の成果'), findsOneWidget);
  });

  testWidgets('狭い画面・大きい文字でも、連携の1行が溢れない', (t) async {
    final c = await _open(t, size: const Size(320, 900), text: 1.6);
    c.game!.lastPlan = Plan.special;
    c.notifyListeners();
    await t.pumpAndSettle();
    expect(find.byKey(const Key('combo-rest')), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
