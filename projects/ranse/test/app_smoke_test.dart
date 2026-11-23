import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ranse/app/app.dart';
import 'package:ranse/app/controller.dart';
import 'package:ranse/engine/rng.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('タイトル→籤→幼少期の岐路→元服→大人の行動', (tester) async {
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
        await tester.ensureVisible(find.text('運命の籤を引く'));
        await tester.pump();
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

    // 幼少期は、毎年の重点の選択から始まる。選択肢には匂わせの一言が付く。
    expect(find.text('今年の重点'), findsOneWidget);
    expect(find.text('家の手伝いに励む'), findsOneWidget);
    expect(find.text('暮らしの足しになる。遊ぶ暇は減る'), findsOneWidget);

    // 幼少期を、毎回いちばん上の選択肢で最後まで進める。
    expect(find.text('岐路'), findsOneWidget); // 下のタブの名前
    var guard = 0;
    while (c.game.isChild && !c.game.finished && guard++ < 60) {
      expect(c.game.prompt, isNotNull);
      // 場面の絵が上にあるので、選択肢が画面の下に隠れることがある。
      await tester.ensureVisible(find.byType(OutlinedButton).first);
      await tester.tap(find.byType(OutlinedButton).first);
      await tester.pump();
    }
    if (c.game.finished) {
      expect(find.text('幼き命'), findsOneWidget);
      return;
    }
    expect(c.game.age, 15);

    // 元服（裳着）の画面を閉じると、大人も毎年の重点を選ぶ。
    expect(find.text('乱世へ歩み出す'), findsOneWidget);
    await tester.tap(find.text('乱世へ歩み出す'));
    await tester.pump();
    expect(find.text('今年の重点'), findsOneWidget);
    expect(find.text('学問に励む'), findsOneWidget);
    expect(find.textContaining('15歳。'), findsOneWidget);

    // 選んでいる最中でも、ほかのタブに切り替えられる（選択肢が画面を覆わない）。
    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pump();
    expect(
      find.text('縁のある人').evaluate().length + find.text('暮らし').evaluate().length,
      greaterThan(0),
    );
    await tester.tap(find.byIcon(Icons.alt_route));
    await tester.pump();
    await tester.ensureVisible(find.text('学問に励む'));
    await tester.tap(find.text('学問に励む'));
    await tester.pump();
    expect(c.game.prompt, isNotNull); // 次の岐路か、翌年の重点

    // 見聞録の画面に切り替えられる。
    expect(find.text('見聞録'), findsOneWidget); // 下のタブの名前だけ
    await tester.tap(find.byIcon(Icons.menu_book_outlined));
    await tester.pump();
    expect(find.text('見聞録'), findsNWidgets(2)); // 画面の見出しが加わる
  });
}
