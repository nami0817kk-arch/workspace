import 'dart:math';

import 'package:basketball_career/game/game.dart';
import 'package:basketball_career/game/life.dart';
import 'package:basketball_career/game/path.dart';
import 'package:basketball_career/game/player.dart';
import 'package:basketball_career/ui/app.dart';
import 'package:basketball_career/ui/controller.dart';
import 'package:flutter/material.dart' hide Action, Route;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// ListView は画面外を作らないので、縦長の画面にして全部を作らせる。
  void tall(WidgetTester t) {
    t.view.physicalSize = const Size(800, 4000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
  }

  testWidgets('はじめの画面から始めて、季節を進められる', (tester) async {
    tall(tester);
    final c = GameController(rng: Random(1));
    await tester.pumpWidget(BasketballCareerApp(controller: c));
    await tester.pumpAndSettle();
    expect(find.text('6歳から始める'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'ミナト');
    await tester.tap(find.text('6歳から始める'));
    await tester.pumpAndSettle();
    expect(find.textContaining('ミナト'), findsWidgets);
    expect(find.text('春の過ごし方'), findsOneWidget);

    await tester.tap(find.text('休養'));
    await tester.pumpAndSettle();
    expect(find.text('夏の過ごし方'), findsOneWidget);
    expect(find.text('いまの結果'), findsOneWidget);
  });

  testWidgets('進路の画面から契約を選べる', (tester) async {
    final c = GameController(rng: Random(1));
    tall(tester);
    c.game = Game(
      player: Player(
        name: 'ケイ',
        age: 19,
        potential: 90,
        heightCm: 205,
        heightGenes: 0.9,
        abilities: {for (final a in Ability.values) a: 90},
      ),
      rng: Random(1),
      pathPending: true,
    );
    await tester.pumpWidget(BasketballCareerApp(controller: c));
    await tester.pumpAndSettle();
    expect(find.text(Route.pro.label), findsOneWidget);
    await tester.tap(find.text(Route.pro.label));
    await tester.pumpAndSettle();
    expect(c.game!.track, Track.pro);
    expect(find.text('プロ契約を勝ち取った!'), findsOneWidget);
  });

  testWidgets('引退するとエンディングが出て、新しい選手を始められる', (tester) async {
    final c = GameController(rng: Random(1));
    c.game = Game(
      player: Player(
        name: 'ユウ',
        age: 25,
        potential: 70,
        heightCm: 190,
        heightGenes: 0.5,
        abilities: {for (final a in Ability.values) a: 70},
      ),
      rng: Random(1),
      track: Track.pro,
    );
    c.game!.retire();
    await tester.pumpWidget(BasketballCareerApp(controller: c));
    await tester.pumpAndSettle();
    expect(find.text('ユウの物語'), findsOneWidget);
    await tester.tap(find.text('新しい選手を育てる'));
    await tester.pumpAndSettle();
    expect(find.text('6歳から始める'), findsOneWidget);
  });

  test('操作のたびに保存され、読み戻せる', () async {
    final c = GameController(rng: Random(2));
    c.newGame('セーブ');
    c.act(Action.practice);
    await pumpEventQueue();
    final d = GameController(rng: Random(3));
    expect(await d.loadSaved(), isTrue);
    expect(d.game!.slot, 1);
    expect(d.game!.player.name, 'セーブ');
  });

  test('おすすめで1年進める', () {
    final c = GameController(rng: Random(4));
    c.newGame('オート');
    c.autoYear();
    expect(c.game!.player.age, 7);
    expect(c.recent.first, contains('1年進めた'));
  });
}
