// 新規開始画面で「生まれ持ったもの」を見て、引き直せる(2026-10-25)。
import 'dart:math';

import 'package:baseball_manager/game/player.dart';
import 'package:baseball_manager/ui/app.dart';
import 'package:baseball_manager/ui/controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('同じ種なら、見本どおりの生まれで始まる。始めたら種は使い切る', () {
    SharedPreferences.setMockInitialValues({});
    final c = GameController(rng: Random(3));
    c.rerollBirth();
    final preview = c.previewBirth('見本', Role.batter).player;
    c.newGame('見本', Role.batter);
    final p = c.game!.player;
    expect(p.potential, preview.potential);
    expect(p.traits, preview.traits);
    expect(p.gifts, preview.gifts);
    expect(p.skills, preview.skills); // 生まれつきの弱点も同じ
    expect(c.birthSeed, isNull);
  });

  test('引き直すと、生まれが変わる(何度か引けば違うものが出る)', () {
    final c = GameController(rng: Random(5));
    final seen = <String>{};
    for (var i = 0; i < 12; i++) {
      c.rerollBirth();
      final p = c.previewBirth('見本', Role.pitcher).player;
      seen.add('${p.potential}/${p.traits}/${p.skills}');
    }
    expect(seen.length, greaterThan(6));
  });

  testWidgets('はじめの画面に見本と「引き直す」が出て、押すと変わる', (t) async {
    SharedPreferences.setMockInitialValues({});
    t.view.physicalSize = const Size(900, 3000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final c = GameController(rng: Random(7));
    await t.pumpWidget(BaseballManagerApp(controller: c));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('birth-preview')), findsOneWidget);
    expect(find.byKey(const Key('birth-talent')), findsOneWidget);
    final first = c.birthSeed;
    expect(first, isNotNull);
    await t.tap(find.byKey(const Key('birth-reroll')));
    await t.pumpAndSettle();
    expect(c.birthSeed, isNot(first));
    expect(t.takeException(), isNull);
  });
}
