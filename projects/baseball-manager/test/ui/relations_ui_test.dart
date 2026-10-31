// 関係タブの「関係を生かす」(交流の相手・頼みごと)(2026-10-28)。
import 'dart:math';

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
  c.newGame('絆', Role.batter);
  c.recent = [];
  c.notifyListeners();
  await t.pumpAndSettle();
  await t.tap(find.byKey(const Key('tab-relations')));
  await t.pumpAndSettle();
  return c;
}

void main() {
  testWidgets('絆が育った家族に頼むと、疲れが抜けて、今年はもう頼めない', (t) async {
    final c = await _open(t);
    final g = c.game!;
    final fam = g.cast.family!;
    expect(find.byKey(const Key('relation-actions')), findsOneWidget);
    expect(find.byKey(Key('favor-block-${fam.id}')), findsOneWidget);
    fam.bond = 60;
    g.condition = g.condition.copyWith(fatigue: 60);
    c.notifyListeners();
    await t.pumpAndSettle();
    await t.tap(find.byKey(Key('favor-${fam.id}')));
    await t.pumpAndSettle();
    expect(g.condition.fatigue, 35);
    expect(find.text('今年はもう頼んだ'), findsOneWidget);
  });

  testWidgets('交流の相手を選ぶと、交流のタイルに名前が出る', (t) async {
    final c = await _open(t);
    final mate = c.game!.cast.teammates.first;
    await t.tap(find.byKey(Key('social-target-${mate.id}')));
    await t.pumpAndSettle();
    expect(c.game!.socialTargetId, mate.id);
    await t.tap(find.byKey(const Key('tab-train')));
    await t.pumpAndSettle();
    expect(find.text('${mate.name.split(' ').first}と'), findsOneWidget);
  });

  testWidgets('狭い画面・大きい文字でも、関係タブが溢れない', (t) async {
    await _open(t, size: const Size(320, 1600), text: 1.6);
    expect(t.takeException(), isNull);
  });
}
