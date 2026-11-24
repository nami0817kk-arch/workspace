import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ranse/app/app.dart';
import 'package:ranse/app/controller.dart';
import 'package:ranse/app/save.dart';
import 'package:ranse/engine/birth.dart';
import 'package:ranse/engine/game.dart';
import 'package:ranse/engine/life_record.dart';
import 'package:ranse/engine/rng.dart';
import 'package:ranse/ui/how_to_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 画面と記録まわりの作り込み（2026-11-25）の画面のテスト。遊び方・これまでの人生・見聞録の絞り込み・縁の言葉。

Future<void> _flush() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// アプリの入り口から人生を一つ最後まで遊ぶ（二十歳を越えるまで引き直す）。
Future<void> _finishLife(AppController c, int seed) async {
  final pick = Rng(seed + 1);
  for (var tries = 0; tries < 100; tries++) {
    c.birth = rollBirth(c.rng);
    c.begin();
    var n = 0;
    while (!c.game.finished && n++ < 3000) {
      c.game.choose(pick.range(0, c.game.prompt!.choices.length - 1));
    }
    if (c.game.age >= 20) return;
  }
  throw StateError('人生が見つからない');
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('人生が終わると、これまでの人生に一度だけ記される', () async {
    final c = AppController(rng: Rng(4));
    await _finishLife(c, 4);
    await _flush();
    // 終わったあとに区切りがまた来ても（画面の更新など）、二度は記さない。
    c.game.changed();
    await _flush();
    final lives = await c.store.lives();
    expect(lives.length, greaterThanOrEqualTo(1));
    expect(lives.first.name, c.game.l.name);
    expect(lives.where((r) => r.id == lives.first.id).length, 1);
  });

  testWidgets('初めて開くと遊び方が一度だけ出て、タイトルからも開ける', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final c = AppController(rng: Rng(1), autoGuide: true);
    await tester.pumpWidget(RanseApp(controller: c));
    await tester.pumpAndSettle();
    expect(c.screen, AppScreen.guide);
    expect(find.text(kHowToPages.first.title), findsOneWidget);
    // 下剋上の説明は、今の作り（城主〜宿老・兵が主家に比べて多いほど）に合わせてある。
    final all = [
      for (final p in kHowToPages)
        for (final (_, note) in p.items) note,
    ].join();
    expect(all, contains('城主から宿老'));
    expect(all, contains('主家に比べて自分の兵が多いほど'));
    for (var i = 0; i < kHowToPages.length - 1; i++) {
      await tester.tap(find.text('次へ'));
      await tester.pumpAndSettle();
    }
    expect(find.text(kHowToPages.last.title), findsOneWidget);
    await tester.tap(find.text('乱世へ'));
    await tester.pumpAndSettle();
    expect(c.screen, AppScreen.title);
    expect(await SaveStore().guideSeen(), isTrue);

    // 一度見たら、次に開いたときは出ない。
    final c2 = AppController(rng: Rng(2), autoGuide: true);
    await c2.init();
    expect(c2.screen, AppScreen.title);

    // タイトルの「遊び方」から開いて、閉じられる。
    await tester.ensureVisible(find.text('遊び方'));
    await tester.tap(find.text('遊び方'));
    await tester.pumpAndSettle();
    expect(c.screen, AppScreen.guide);
    await tester.tap(find.text('閉じる'));
    await tester.pumpAndSettle();
    expect(c.screen, AppScreen.title);
    expect(tester.takeException(), isNull);
  });

  testWidgets('タイトルの「これまでの人生」から一覧と詳しい画面を開ける', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final c = AppController(rng: Rng(6));
    await _finishLife(c, 6);
    final rec = LifeRecord.of(c.game);
    await tester.pumpWidget(RanseApp(controller: c));
    await tester.pump();
    c.toTitle();
    await tester.pumpAndSettle();
    expect(find.textContaining('これまでの人生　'), findsOneWidget);
    await tester.ensureVisible(find.textContaining('これまでの人生　'));
    await tester.tap(find.textContaining('これまでの人生　'));
    await tester.pumpAndSettle();
    expect(c.screen, AppScreen.lives);
    final tile = find.textContaining('${rec.name}　享年${rec.age}');
    expect(tile, findsWidgets);
    await tester.tap(tile.first);
    await tester.pumpAndSettle();
    expect(find.text(rec.text), findsOneWidget);
    expect(find.text(rec.cause), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('見聞録を絞り込め、縁のある人の絆は言葉で出る', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final c = AppController(rng: Rng(8));
    final pick = Rng(9);
    Game g = c.game;
    for (var tries = 0; tries < 200; tries++) {
      c.birth = rollBirth(c.rng);
      c.begin();
      g = c.game;
      var n = 0;
      while (!g.finished && n++ < 3000) {
        if (g.age >= 22 &&
            g.l.people.isNotEmpty &&
            g.prompt?.title == 'この年の心がけ') {
          break;
        }
        g.choose(pick.range(0, g.prompt!.choices.length - 1));
      }
      if (!g.finished && g.l.people.isNotEmpty) break;
    }
    expect(g.finished, isFalse);
    await tester.pumpWidget(RanseApp(controller: c));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pump();
    expect(find.textContaining('絆 '), findsNothing);

    await tester.tap(find.byIcon(Icons.menu_book_outlined));
    await tester.pump();
    for (final k in ['self', 'world', 'people', 'all']) {
      await tester.tap(find.byKey(ValueKey('log-filter-$k')));
      await tester.pump();
    }
    expect(tester.takeException(), isNull);
  });
}
