import 'dart:math';

import 'package:basketball_career/game/game.dart';
import 'package:basketball_career/game/traits.dart';
import 'package:basketball_career/game/life.dart';
import 'package:basketball_career/game/match.dart';
import 'package:basketball_career/game/path.dart';
import 'package:basketball_career/game/player.dart';
import 'package:basketball_career/game/rival.dart';
import 'package:basketball_career/ui/app.dart';
import 'package:basketball_career/ui/controller.dart';
import 'package:basketball_career/ui/game_screen.dart' show resultStripText;
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

  testWidgets('はじめの画面に難易度の選択は無く、特性のくじと振り直しがある', (tester) async {
    tall(tester);
    final c = GameController(rng: Random(1), events: false);
    await tester.pumpWidget(BasketballCareerApp(controller: c));
    await tester.pumpAndSettle();
    for (final d in ['やさしい', 'ふつう', 'むずかしい']) {
      expect(find.text(d), findsNothing, reason: '難易度の選択は無くした');
    }
    expect(find.text('生まれつきの特性(くじ引き)'), findsOneWidget);
    expect(find.text('振り直す'), findsOneWidget);
    await tester.tap(find.text('振り直す'));
    await tester.pumpAndSettle();
    expect(find.text('6歳から始める'), findsOneWidget);
  });

  test('始めるときに渡した生まれつきの特性が、そのまま選手に入る(空でもよい)', () {
    final c = GameController(rng: Random(1), events: false);
    c.newGame('くじ', traits: {Trait.genius, Trait.lefty});
    expect(c.game!.player.traits, {Trait.genius, Trait.lefty});
    final d = GameController(rng: Random(1), events: false);
    d.newGame('なし', traits: <Trait>{});
    expect(d.game!.player.traits, isEmpty);
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

  testWidgets('はじめの画面で背番号を選べる', (tester) async {
    tall(tester);
    SharedPreferences.setMockInitialValues({howtoKey: true});
    final c = GameController(rng: Random(1), events: false);
    await tester.pumpWidget(BasketballCareerApp(controller: c));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '23'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('6歳から始める'));
    await tester.pumpAndSettle();
    expect(c.game!.number, 23);
    expect(find.textContaining('#23'), findsOneWidget);
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
    expect(find.textContaining('「遊びに行く」を選んだ'), findsWidgets); // 結果のカードと下の帯
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
      while (t.game!.phase == Phase.halftime) {
        t.game!.resolveHalftime(Halftime.keep);
      }
      if (t.game!.phase == Phase.clutch) c = t;
    }
    expect(c, isNotNull, reason: '勝負どころになる乱数が見つからない');
    await tester.pumpWidget(BasketballCareerApp(controller: c!));
    await tester.pumpAndSettle();
    expect(find.textContaining('勝負どころ!'), findsOneWidget);
    expect(find.textContaining('成功率'), findsNWidgets(Clutch.values.length));
    // 大会の途中でまた勝負どころが来ることもある。終わるまで選び続ける。
    var guard = 0;
    while ((c.game!.phase == Phase.clutch || c.game!.phase == Phase.halftime) &&
        guard++ < 20) {
      if (c.game!.phase == Phase.halftime) {
        await tester.tap(find.textContaining('このまま続ける'));
      } else {
        await tester.tap(find.textContaining('ドライブ  成功率'));
      }
      await tester.pumpAndSettle();
    }
    expect(c.game!.records, isNotEmpty);
    expect(find.textContaining('の夏の大会'), findsWidgets);
  });

  testWidgets('ハーフタイムで作戦を選べる', (tester) async {
    tall(tester);
    GameController? c;
    for (var seed = 0; seed < 400 && c == null; seed++) {
      final t = GameController(store: _NullStore(), rng: Random(seed), events: false);
      t.game = Game(
        eventsEnabled: false,
        player: Player(
          name: 'ケイ', age: 15, potential: 80, heightCm: 195, heightGenes: 0.5,
          abilities: {for (final a in Ability.values) a: 70}),
        rng: Random(seed),
        slot: 1,
      );
      t.act(Action.rest);
      if (t.game!.phase == Phase.halftime) c = t;
    }
    expect(c, isNotNull, reason: 'ハーフタイムで止まる乱数が見つからない');
    await tester.pumpWidget(BasketballCareerApp(controller: c!));
    await tester.pumpAndSettle();
    expect(find.textContaining('ハーフタイム'), findsWidgets);
    expect(find.textContaining('後半の作戦を選ぼう'), findsOneWidget);
    for (final h in Halftime.values) {
      expect(find.textContaining(h.label), findsWidgets);
    }
    expect(find.textContaining('(おすすめ)'), findsOneWidget);
    // 相手の持ち味の説明文にも「守りを固めて…」と出るので、ボタンの中の文字を押す。
    final defense = find.descendant(
        of: find.byType(FilledButton), matching: find.textContaining('守りを固める'));
    await tester.ensureVisible(defense);
    await tester.pumpAndSettle();
    await tester.tap(defense);
    await tester.pumpAndSettle();
    // 作戦を選んだので、次の止まりどころ(勝負どころか次の試合のハーフタイム)か終了へ進む。
    // (接戦なら勝負どころで止まり、まだ試合の結果は無い。ハーフタイムのままでなければ進んでいる。)
    final moved = c.game!.phase != Phase.halftime ||
        (c.game!.run?.matches.length ?? c.game!.records.length) > 0;
    expect(moved, isTrue);
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

  testWidgets('過ごし方のボタンは画面の下に固定され、スクロールしなくても押せる', (tester) async {
    // ふつうのスマホの大きさ(縦長にしない)。
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = GameController(store: _NullStore(), rng: Random(1), events: false);
    c.game = Game.start('ケイ', rng: Random(2), events: false);
    await tester.pumpWidget(BasketballCareerApp(controller: c));
    await tester.pumpAndSettle();
    for (final a in Action.values) {
      final f = find.text(a.label);
      expect(f, findsOneWidget, reason: a.label);
      final r = tester.getRect(f);
      expect(r.bottom, lessThanOrEqualTo(844), reason: '${a.label} が画面の外にある');
    }
    // 「重点を変える」で、重点の設定まで送られる。
    await tester.tap(find.text('重点を変える'));
    await tester.pumpAndSettle();
    final chip = tester.getRect(find.textContaining('① 大きく伸ばす能力'));
    expect(chip.top, lessThan(844));
    // 下までスクロールしたまま練習しても(春なので大会は無い)、結果はボタンのすぐ上の帯で読める。
    expect(c.game!.slot, 0);
    await tester.tap(find.text('練習'));
    await tester.pumpAndSettle();
    expect(c.game!.slot, 1, reason: 'スクロールせずに押せて、季節が進む');
    final strip = find.textContaining('練習した。');
    expect(strip, findsWidgets);
    final stripRect = tester.getRect(strip.last);
    expect(stripRect.bottom, lessThanOrEqualTo(844));
    expect(stripRect.top, greaterThan(844 - 260), reason: '帯は画面の下(ボタンの上)にある');
    expect(resultStripText(c.recent), contains('成長'), reason: '何が伸びたかも帯に出る');
    // 帯を押すと「いまの結果」のカードまで戻る。
    await tester.tap(strip.last);
    await tester.pumpAndSettle();
    final card = tester.getRect(find.text('いまの結果'));
    expect(card.top, greaterThanOrEqualTo(0));
    expect(card.top, lessThan(844 - 260));
  });

  test('結果の帯は最初の2行をつなぐ', () {
    expect(resultStripText(const ['練習した。', '成長: 3Pシュート +2', 'ほか']), '練習した。  成長: 3Pシュート +2');
    expect(resultStripText(const ['休養した。']), '休養した。');
  });

  testWidgets('勝負どころ・出来事の選択肢も、ふつうのスマホの画面に収まる(スクロールしなくても押せる)', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // 勝負どころ
    GameController? found;
    for (var seed = 0; seed < 400 && found == null; seed++) {
      final c = GameController(store: _NullStore(), rng: Random(seed), events: false);
      c.game = Game(
        eventsEnabled: false,
        player: Player(name: 'ケイ', age: 15, potential: 70, heightCm: 178, heightGenes: 0.5,
            abilities: {for (final a in Ability.values) a: 55}),
        rng: Random(seed),
        slot: 1,
      );
      c.act(Action.rest);
      while (c.game!.phase == Phase.halftime) {
        c.game!.resolveHalftime(Halftime.keep);
      }
      if (c.game!.phase == Phase.clutch) found = c;
    }
    await tester.pumpWidget(BasketballCareerApp(controller: found!));
    await tester.pumpAndSettle();
    for (final k in Clutch.values) {
      final r = tester.getRect(find.textContaining('${k.label}  成功率'));
      expect(r.bottom, lessThanOrEqualTo(844), reason: '${k.label} が画面の外');
    }
    // 出来事
    final ev = GameController(store: _NullStore(), rng: Random(1), events: false);
    ev.game = Game.start('ケイ', rng: Random(1), events: false)..pendingEventId = 'friends';
    await tester.pumpWidget(const SizedBox()); // 前の画面の状態を持ち越さない
    await tester.pumpWidget(BasketballCareerApp(controller: ev));
    await tester.pumpAndSettle();
    final e = ev.game!.pendingEvent!;
    for (final o in e.options) {
      final r = tester.getRect(find.text(o.label));
      expect(r.bottom, lessThanOrEqualTo(844), reason: '${o.label} が画面の外');
    }
    // ハーフタイム
    GameController? half;
    for (var seed = 0; seed < 400 && half == null; seed++) {
      final c = GameController(store: _NullStore(), rng: Random(seed), events: false);
      c.game = Game(
        eventsEnabled: false,
        player: Player(name: 'ケイ', age: 15, potential: 70, heightCm: 178, heightGenes: 0.5,
            abilities: {for (final a in Ability.values) a: 55}),
        rng: Random(seed),
        slot: 1,
      );
      c.act(Action.rest);
      if (c.game!.phase == Phase.halftime) half = c;
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(BasketballCareerApp(controller: half!));
    await tester.pumpAndSettle();
    for (final h in Halftime.values) {
      final r = tester.getRect(find.textContaining(h.label).first);
      expect(r.bottom, lessThanOrEqualTo(844), reason: '${h.label} が画面の外');
    }
    // 進路
    final p = GameController(store: _NullStore(), rng: Random(1), events: false);
    p.game = Game(
      eventsEnabled: false,
      player: Player(name: 'ユウ', age: 19, potential: 70, heightCm: 185, heightGenes: 0.5,
          abilities: {for (final a in Ability.values) a: 60}),
      rng: Random(1),
      pathPending: true,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(BasketballCareerApp(controller: p));
    await tester.pumpAndSettle();
    // 画面外は作られないので、名前で探して見つかること自体も確かめる。
    for (final route in p.game!.availableRoutes) {
      final r = tester.getRect(find.text(route.label));
      expect(r.bottom, lessThanOrEqualTo(844), reason: '${route.label} が画面の外');
    }
  });

  testWidgets('おすすめの過ごし方に印が付き、状態で変わる', (tester) async {
    tall(tester);
    final c = GameController(store: _NullStore(), rng: Random(1), events: false);
    c.game = Game.start('ケイ', rng: Random(2), events: false);
    await tester.pumpWidget(BasketballCareerApp(controller: c));
    await tester.pumpAndSettle();
    // 画面の下に固定したボタンのうち、おすすめの1つにだけ「おすすめ」が付く。
    expect(find.text('おすすめ'), findsOneWidget);
    // 疲れていれば休養がおすすめになる。
    c.game!.condition = const Condition(fatigue: 90);
    c.notifyListeners();
    await tester.pumpAndSettle();
    expect(find.text('おすすめ'), findsOneWidget);
    final recButton = find.ancestor(of: find.text('おすすめ'), matching: find.byType(FilledButton));
    expect(find.descendant(of: recButton, matching: find.text('休養')), findsOneWidget);
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

  test('おすすめで3年まとめて進める(止まる場面があれば、そこまで)', () async {
    final c = GameController(rng: Random(4), events: false);
    c.newGame('オート');
    await c.autoYears(3);
    expect(c.game!.player.age, 9);
    expect(c.recent.first, contains('3年進めた'));
    // 進路の画面など、季節の画面でなくなったら、それ以上は進まない。
    final d = GameController(rng: Random(5), events: false);
    d.newGame('オート');
    await d.autoYears(40);
    expect(d.game!.phase, isNot(Phase.season), reason: '進路・引退などで止まる');
    expect(d.game!.player.age, lessThan(60));
  });
}
