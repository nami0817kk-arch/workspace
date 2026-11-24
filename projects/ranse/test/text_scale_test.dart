import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ranse/app/app.dart';
import 'package:ranse/app/controller.dart';
import 'package:ranse/engine/birth.dart';
import 'package:ranse/engine/rng.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// iPhone の「文字を大きく」を最大にした人でも、画面がはみ出さない（はみ出すとテストが例外で落ちる）。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<AppController> openAt(
    WidgetTester tester, {
    required int seed,
    int? stopAtAge,
  }) async {
    tester.view.physicalSize = const Size(375 * 3, 667 * 3); // 小さめの iPhone
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final c = AppController(rng: Rng(seed));
    final pick = Rng(seed + 1);
    for (var tries = 0; tries < 100; tries++) {
      c.birth = rollBirth(c.rng);
      c.begin();
      var n = 0;
      while (!c.game.finished && n++ < 3000) {
        if (stopAtAge != null &&
            c.game.age >= stopAtAge &&
            c.game.prompt?.title == 'この年の心がけ') {
          break;
        }
        c.game.choose(pick.range(0, c.game.prompt!.choices.length - 1));
      }
      if (stopAtAge == null ? c.game.age >= 20 : !c.game.finished) break;
    }
    await tester.pumpWidget(RanseApp(controller: c));
    await tester.pump();
    return c;
  }

  testWidgets('文字を大きくしても、遊ぶ画面の4つのタブがはみ出さない', (tester) async {
    await openAt(tester, seed: 3, stopAtAge: 25);
    for (final tab in ['人物', '天下', '見聞録', '岐路']) {
      await tester.tap(find.text(tab).last);
      await tester.pump();
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('文字を大きくしても、人生の終わりの画面がはみ出さない', (tester) async {
    await openAt(tester, seed: 9);
    // 文字が大きいと結果カードが伸び、ボタンは画面の下に押し出される。見えるところまで動かす。
    await tester.scrollUntilVisible(find.text('結果を写す'), 300);
    expect(find.text('結果を写す'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -3000));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('文字を大きくしても、タイトルと生まれの画面がはみ出さない', (tester) async {
    tester.view.physicalSize = const Size(375 * 3, 667 * 3);
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final c = AppController(rng: Rng(5));
    await tester.pumpWidget(RanseApp(controller: c));
    await tester.pump();
    await tester.ensureVisible(find.text('運命の籤を引く'));
    await tester.pump();
    await tester.tap(find.text('運命の籤を引く'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('この人生を生きる'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
