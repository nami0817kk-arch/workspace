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
    final c = GameController(rng: Random(1), events: false);
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
    final c = GameController(rng: Random(1), events: false);
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
    final c = GameController(rng: Random(1), events: false);
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
    final c = GameController(rng: Random(2), events: false);
    c.newGame('セーブ');
    c.act(Action.practice);
    await pumpEventQueue();
    final d = GameController(rng: Random(3));
    expect(await d.loadSaved(), isTrue);
    expect(d.game!.slot, 1);
    expect(d.game!.player.name, 'セーブ');
  });

  testWidgets('出来事が起きたら選べて、結果が出る', (tester) async {
    tall(tester);
    final c = GameController(rng: Random(1), events: false);
    c.game = Game.start('イベント', rng: Random(1), events: false)
      ..pendingEventId = 'friends';
    await tester.pumpWidget(BasketballCareerApp(controller: c));
    await tester.pumpAndSettle();
    expect(find.text('友だちの誘い'), findsOneWidget);
    await tester.tap(find.text('遊びに行く'));
    await tester.pumpAndSettle();
    expect(c.game!.pendingEventId, isNull);
    expect(find.textContaining('「遊びに行く」を選んだ'), findsOneWidget);
    expect(find.text('春の過ごし方'), findsOneWidget);
  });

  testWidgets('勝負どころで止まり、その場でプレーを選べる', (tester) async {
    tall(tester);
    GameController? c;
    for (var seed = 0; seed < 400 && c == null; seed++) {
      final t = GameController(rng: Random(seed), events: false);
      t.game = Game(
        eventsEnabled: false,
        player: Player(
          name: 'ケイ',
          age: 15,
          potential: 80,
          heightCm: 195,
          heightGenes: 0.5,
          abilities: {for (final a in Ability.values) a: 80},
        ),
        rng: Random(seed),
        slot: 1,
      );
      t.act(Action.rest);
      if (t.game!.phase == Phase.clutch) c = t;
    }
    expect(c, isNotNull, reason: '勝負どころになる乱数が見つからない');
    await tester.pumpWidget(BasketballCareerApp(controller: c!));
    await tester.pumpAndSettle();
    expect(find.textContaining('勝負どころ!'), findsOneWidget);
    expect(find.textContaining('成功率'), findsNWidgets(4));
    await tester.tap(find.textContaining('ドライブ  成功率'));
    await tester.pumpAndSettle();
    expect(c.game!.records, isNotEmpty);
    expect(find.textContaining('の夏の大会'), findsWidgets);
  });

  test('おすすめで1年進める', () async {
    final c = GameController(rng: Random(4), events: false);
    c.newGame('オート');
    await c.autoYear();
    expect(c.game!.player.age, 7);
    expect(c.recent.first, contains('1年進めた'));
  });
}
