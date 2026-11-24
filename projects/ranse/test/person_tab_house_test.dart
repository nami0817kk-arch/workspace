import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ranse/app/app.dart';
import 'package:ranse/app/controller.dart';
import 'package:ranse/engine/birth.dart';
import 'package:ranse/engine/life.dart';
import 'package:ranse/engine/rng.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 人物のタブの「家臣」の欄と「子の育て方」（2026-11-25）。育て方は年の初めの問いのときだけ選べる。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('人物のタブ: 家臣の欄と、子の育て方（年の初めだけ選べる）', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final c = AppController(rng: Rng(5));
    // 元服まで生きる人生を、エンジンだけで進める。
    for (var i = 0; i < 40; i++) {
      c.birth = rollBirth(c.rng, asFemale: false);
      c.begin();
      var n = 0;
      while (!c.game.finished && c.game.isChild && n++ < 200) {
        c.game.choose(0);
      }
      if (!c.game.finished) break;
    }
    final g = c.game;
    expect(g.finished, isFalse);
    g.choose(0); // 元服の問いを閉じる → 大人の最初の年の初め
    expect(g.prompt!.title, 'この年の心がけ');
    final l = g.l;
    l.rank = 6;
    l.lord = g.alive.first.name;
    l.married = true;
    g.meet('伴侶', 'お春', 50);
    final kid = l.addKid(g.year - 8, female: false, name: '藤助');
    l.retainers.add(Retainer('中村弥吉', RetainerTemper.loyal, bond: 80, head: true));

    await tester.pumpWidget(RanseApp(controller: c));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pump();

    await tester.scrollUntilVisible(find.text('家臣'), 300, scrollable: _list);
    expect(find.text('家臣'), findsOneWidget);
    expect(find.textContaining('中村弥吉'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('子の育て方'), -300, scrollable: _list);
    expect(find.text('子の育て方'), findsOneWidget);
    expect(find.text('藤助（8歳）'), findsOneWidget);

    // 年の初めなら選べる。
    await tester.tap(find.text('決める'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('寺へ預ける'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(kid.raising, KidRaising.tera);
    expect(find.text('寺で学ぶ'), findsOneWidget);

    // 年の途中（何か選んだあと）は押せず、そのことを出す。
    g.choiceLog.add((0, 'x'));
    g.changed();
    await tester.pump();
    expect(find.textContaining('年の初め（この年の心がけを選ぶ前）にだけ'), findsOneWidget);
    await tester.tap(find.text('寺で学ぶ'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('家で育てる'), findsNothing);
  });
}

/// 人物のタブの縦の一覧。
final _list = find
    .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
    .first;
