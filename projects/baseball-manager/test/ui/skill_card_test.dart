// 能力タブの特殊能力の欄: 絞り込み(コツあり/すべて)・並べ替え・取りどきをまとめて取る(2026-10-25)。
import 'dart:math';

import 'package:baseball_manager/game/player.dart';
import 'package:baseball_manager/game/skills.dart';
import 'package:baseball_manager/ui/app.dart';
import 'package:baseball_manager/ui/controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<GameController> _open(WidgetTester t, {Size size = const Size(900, 3000), double text = 1.0}) async {
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
  c.newGame('欄', Role.batter);
  c.recent = [];
  final g = c.game!;
  g.player = g.player.copyWith(skills: {});
  c.notifyListeners();
  await t.pumpAndSettle();
  await t.tap(find.byKey(const Key('tab-ability')));
  await t.pumpAndSettle();
  return c;
}

void main() {
  testWidgets('既定はコツのあるものだけ。無ければ案内と「すべて」で一覧が出る', (t) async {
    final c = await _open(t);
    await t.scrollUntilVisible(find.byKey(const Key('skill-filter')), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.byKey(const Key('skill-none-yet')), findsOneWidget);
    expect(find.byKey(const Key('skill-tips-chance')), findsNothing);
    await t.tap(find.text('すべて'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('skill-tips-chance')), findsOneWidget);
    // コツが付くと、「コツあり」で出る
    await t.tap(find.text('コツあり'));
    c.game!.skillTips[Skill.stealer] = 2;
    c.notifyListeners();
    await t.pumpAndSettle();
    expect(find.byKey(const Key('skill-tips-stealer')), findsOneWidget);
    expect(find.byKey(const Key('skill-tips-chance')), findsNothing);
  });

  testWidgets('取りどきは上に並び、「取りどきを取る」でまとめて取れる', (t) async {
    final c = await _open(t);
    final g = c.game!;
    g.skillTips[Skill.stealer] = 4;
    g.skillTips[Skill.chance] = 3;
    g.skillTips[Skill.powerHitter] = 1;
    g.adminAddExp(500);
    c.notifyListeners();
    await t.pumpAndSettle();
    expect(g.skillsInSeason.toSet(), {Skill.stealer, Skill.chance});
    await t.scrollUntilVisible(find.byKey(const Key('skill-buy-ready')), 300,
        scrollable: find.byType(Scrollable).first);
    // 取りどきの2つが、コツ1のパワーヒッターより上
    final yStealer = t.getTopLeft(find.byKey(const Key('skill-tips-stealer'))).dy;
    final yPower = t.getTopLeft(find.byKey(const Key('skill-tips-powerHitter'))).dy;
    expect(yStealer, lessThan(yPower));
    await t.tap(find.byKey(const Key('skill-buy-ready')));
    await t.pumpAndSettle();
    expect(g.player.skills.containsAll({Skill.stealer, Skill.chance}), isTrue);
    expect(g.player.skills, isNot(contains(Skill.powerHitter)));
  });

  testWidgets('せまい画面(幅320)・大きい文字(1.6倍)でも、特殊能力の欄が溢れない', (t) async {
    final c = await _open(t, size: const Size(320, 1600), text: 1.6);
    final g = c.game!;
    g.skillTips[Skill.stealer] = 4;
    g.adminAddExp(500);
    c.notifyListeners();
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.byKey(const Key('skill-filter')), 300,
        scrollable: find.byType(Scrollable).first);
    await t.tap(find.text('すべて'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
}
