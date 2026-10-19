import 'dart:math';

import 'package:basketball_career/game/game.dart';
import 'package:basketball_career/game/life.dart';
import 'package:basketball_career/game/path.dart';
import 'package:basketball_career/game/player.dart';
import 'package:basketball_career/game/rival.dart';
import 'package:basketball_career/ui/app.dart';
import 'package:basketball_career/ui/controller.dart';
import 'package:basketball_career/ui/milestone_dialog.dart';
import 'package:flutter/material.dart' hide Action, Route;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 何も保存しない(探索の途中の保存が、あとから起動時に読み込まれないように)。
class _NullStore extends SaveStore {
  @override
  Future<void> save(Map<String, dynamic> json) async {}
  @override
  Future<void> clear() async {}
  @override
  Future<Map<String, dynamic>?> load() async => null;
}

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
    // はじめてなら、先に遊び方が出る。
    expect(find.text('遊び方'), findsOneWidget);
    await tester.tap(find.text('はじめる'));
    await tester.pumpAndSettle();
    expect(find.textContaining('ミナト'), findsWidgets);
    expect(find.text('春の過ごし方'), findsOneWidget);

    await tester.tap(find.text('休養'));
    await tester.pumpAndSettle();
    expect(find.text('夏の過ごし方'), findsOneWidget);
    expect(find.text('いまの結果'), findsOneWidget);
  });

  testWidgets('遊び方は1度だけ自動で出て、あとはいつでも開ける', (tester) async {
    tall(tester);
    SharedPreferences.setMockInitialValues({howtoKey: true});
    final c = GameController(rng: Random(1), events: false);
    await tester.pumpWidget(BasketballCareerApp(controller: c));
    await tester.pumpAndSettle();
    // 見たことがあるので、すぐ始まる。
    await tester.tap(find.text('6歳から始める'));
    await tester.pumpAndSettle();
    expect(find.text('春の過ごし方'), findsOneWidget);
  });

  testWidgets('はじめの画面から遊び方をいつでも開ける', (tester) async {
    tall(tester);
    final c = GameController(rng: Random(1), events: false);
    await tester.pumpWidget(BasketballCareerApp(controller: c));
    await tester.pumpAndSettle();
    await tester.tap(find.text('遊び方'));
    await tester.pumpAndSettle();
    expect(find.text('1年は春夏秋冬の4回'), findsOneWidget);
    expect(find.text('はじめる'), findsNothing, reason: 'いつでも開く場合は開始ボタンを出さない');
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
      eventsEnabled: false,
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
    tall(tester);
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
      final t = GameController(
          store: _NullStore(), rng: Random(seed), events: false);
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
    // 大会の途中でまた勝負どころが来ることもある。終わるまで選び続ける。
    var guard = 0;
    while (c.game!.phase == Phase.clutch && guard++ < 10) {
      await tester.tap(find.textContaining('ドライブ  成功率'));
      await tester.pumpAndSettle();
    }
    expect(c.game!.records, isNotEmpty);
    expect(find.textContaining('の夏の大会'), findsWidgets);
  });

  testWidgets('エンディングで結果をコピーできる', (tester) async {
    tall(tester);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    final c = GameController(store: _NullStore(), rng: Random(1), events: false);
    final g = Game(
      eventsEnabled: false,
      player: Player(
          name: 'ユウ', age: 25, potential: 70, heightCm: 190, heightGenes: 0.5,
          abilities: {for (final a in Ability.values) a: 70}),
      rng: Random(1),
      track: Track.pro,
    )..retire();
    c.game = g;
    await tester.pumpWidget(BasketballCareerApp(controller: c));
    await tester.pumpAndSettle();
    await tester.tap(find.text('結果をコピー'));
    await tester.pumpAndSettle();
    expect(copied, contains('ユウの物語'));
    expect(copied, contains('#バスケ育成'));
    expect(find.textContaining('結果をコピーした'), findsOneWidget);
  });

  test('ライバルとはじめて戦うと出会いの節目が1度だけ出る', () {
    final c = GameController(store: _NullStore(), rng: Random(2), events: false);
    c.game = Game(
      eventsEnabled: false,
      player: Player(
        name: 'ケイ', age: 13, potential: 80, heightCm: 170, heightGenes: 0.5,
        abilities: {for (final a in Ability.values) a: 70}),
      rng: Random(2),
      slot: 1,
      rival: Rival(name: '黒瀬ユウマ', potential: 70),
    );
    // 準決勝(2戦目)まで勝ち上がれるまで、乱数を変えて探す。
    var met = false;
    for (var seed = 0; seed < 60 && !met; seed++) {
      final t = GameController(store: _NullStore(), rng: Random(seed), events: false);
      t.game = Game(
        eventsEnabled: false,
        player: Player(
          name: 'ケイ', age: 13, potential: 80, heightCm: 170, heightGenes: 0.5,
          abilities: {for (final a in Ability.values) a: 90}),
        rng: Random(seed),
        slot: 1,
        rival: Rival(name: '黒瀬ユウマ', potential: 70),
      );
      t.act(Action.rest, ask: false);
      if (t.game!.rivalMet) {
        met = true;
        expect(t.pending.where((m) => m.kind == MilestoneKind.rival).length, 1);
        expect(t.pending.firstWhere((m) => m.kind == MilestoneKind.rival).body,
            contains('黒瀬ユウマ'));
        // 次の年の対戦では、もう出ない。
        t.pending.clear();
        for (var i = 0; i < 4; i++) {
          t.act(Action.rest, ask: false);
        }
        t.act(Action.rest, ask: false);
        expect(t.pending.where((m) => m.kind == MilestoneKind.rival), isEmpty);
      }
    }
    expect(met, isTrue);
    expect(c.pending, isEmpty);
  });

  test('能力のランクが上がると知らせる', () {
    final c = GameController(store: _NullStore(), rng: Random(3), events: false);
    c.game = Game(
      eventsEnabled: false,
      player: Player(
        name: 'ケイ',
        age: 12,
        potential: 90,
        heightCm: 150,
        heightGenes: 0.5,
        abilities: {for (final a in Ability.values) a: 39},
      ),
      rng: Random(3),
    );
    var saw = false;
    for (var i = 0; i < 6 && !saw; i++) {
      c.act(Action.practice, ask: false);
      saw = c.recent.any((l) => l.startsWith('ランクアップ!'));
    }
    expect(saw, isTrue);
  });

  testWidgets('節目はダイアログで見せ、閉じると次の節目が出る', (tester) async {
    tall(tester);
    final c = GameController(store: _NullStore(), rng: Random(1), events: false);
    c.game = Game.start('ケイ', rng: Random(2), events: false);
    c.pending.addAll(const [
      Milestone(MilestoneKind.champion, '優勝!', '夏の大会を制した。'),
      Milestone(MilestoneKind.goal, '目標達成!', 'ごほうび'),
    ]);
    await tester.pumpWidget(BasketballCareerApp(controller: c));
    await tester.pumpAndSettle();
    c.notifyListeners();
    await tester.pumpAndSettle();
    expect(find.text('優勝!'), findsOneWidget);
    await tester.tap(find.text('つぎへ'));
    await tester.pumpAndSettle();
    expect(find.text('目標達成!'), findsOneWidget);
    await tester.tap(find.text('つぎへ'));
    await tester.pumpAndSettle();
    expect(find.text('つぎへ'), findsNothing);
    expect(c.pending, isEmpty);
  });

  test('中学に上がると進学の節目が出る。プロ契約・海外挑戦も', () {
    final c = GameController(store: _NullStore(), rng: Random(1), events: false);
    c.game = Game(
      eventsEnabled: false,
      player: Player(
          name: 'ケイ', age: 12, potential: 50, heightCm: 150, heightGenes: 0.5),
      rng: Random(1),
    );
    for (var i = 0; i < 4; i++) {
      c.act(Action.rest, ask: false);
    }
    expect(c.pending.any((m) => m.kind == MilestoneKind.stage), isTrue);

    final p = GameController(store: _NullStore(), rng: Random(1), events: false);
    p.game = Game(
      eventsEnabled: false,
      player: Player(
        name: 'ユウ',
        age: 21,
        potential: 90,
        heightCm: 205,
        heightGenes: 0.9,
        abilities: {for (final a in Ability.values) a: 90},
      ),
      rng: Random(1),
      pathPending: true,
    );
    p.chooseRoute(Route.pro);
    expect(p.pending.any((m) => m.kind == MilestoneKind.contract), isTrue);
    p.goAbroad();
    expect(p.pending.any((m) => m.kind == MilestoneKind.abroad), isTrue);
  });

  test('おすすめで1年進める', () async {
    final c = GameController(rng: Random(4), events: false);
    c.newGame('オート');
    await c.autoYear();
    expect(c.game!.player.age, 7);
    expect(c.recent.first, contains('1年進めた'));
  });
}
