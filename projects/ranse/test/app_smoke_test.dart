import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ranse/app/app.dart';
import 'package:ranse/app/controller.dart';
import 'package:ranse/engine/rng.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('タイトル→籤→人生開始→子ども期の行動→一年進む', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final c = AppController(rng: Rng(11));
    await tester.pumpWidget(RanseApp(controller: c));
    await tester.pump();
    expect(find.text('乱世下剋上'), findsOneWidget);

    // 乳幼児で亡くなる人生もあるので、生き延びるまで引き直す。
    for (var i = 0; i < 12; i++) {
      if (i == 0) {
        await tester.tap(find.text('運命の籤を引く'));
      } else {
        c.draw();
      }
      await tester.pump();
      await tester.pump(const Duration(seconds: 2)); // 演出が終わるまで
      expect(find.text('この人生を生きる'), findsOneWidget);
      expect(find.textContaining('分の 1'), findsOneWidget);
      await tester.tap(find.text('この人生を生きる'));
      await tester.pump();
      if (!c.game.finished) break;
      expect(find.text('幼き命'), findsOneWidget);
    }
    expect(c.game.finished, isFalse, reason: '12回引いても生き延びなかった');

    expect(find.text('行動'), findsOneWidget);
    expect(find.text('見聞録'), findsOneWidget);
    expect(find.text('家の手伝い'), findsOneWidget);
    final before = c.game.age;
    await tester.tap(find.text('家の手伝い'));
    await tester.pump();
    expect(c.game.age, before + 1);

    // 一年のあいだにできごと（選択肢）が起きることがある。画面を覆うので先に選ぶ。
    if (c.game.prompt != null) {
      expect(find.byType(OutlinedButton), findsWidgets);
      await tester.tap(find.byType(OutlinedButton).first);
      await tester.pump();
      expect(c.game.prompt, isNull);
    }

    // 見聞録の画面に切り替えられる。
    expect(find.text('見聞録'), findsOneWidget); // 下のタブの名前だけ
    await tester.tap(find.byIcon(Icons.menu_book_outlined));
    await tester.pump();
    expect(find.text('見聞録'), findsNWidgets(2)); // 画面の見出しが加わる
  });
}
