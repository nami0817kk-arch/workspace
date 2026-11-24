import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/logic/continental_cup_engine.dart';
import 'package:soccer_manager/logic/lineup_utils.dart';
import 'package:soccer_manager/logic/player_generator.dart';
import 'package:soccer_manager/main.dart';
import 'package:soccer_manager/screens/cup_screen.dart';
import 'package:soccer_manager/state/game_state.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // これらのテストは日本語の文言で要素を探す。テスト環境の既定ロケールは
  // en なので、指定しないと英語のUIが出て見つからなくなる。表示言語を
  // 日本語に固定して、ロケールに左右されないようにする。
  // MaterialApp が見るのは locales (複数形) の方なので、そちらも設定する。
  // 上書きはテストごとに戻るため setUp で毎回入れる。
  setUp(() {
    final dispatcher =
        TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher;
    dispatcher.localeTestValue = const Locale('ja');
    dispatcher.localesTestValue = const [Locale('ja')];
  });

  tearDown(() {
    final dispatcher =
        TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher;
    dispatcher.clearLocaleTestValue();
    dispatcher.clearLocalesTestValue();
  });

  testWidgets('start screen shows save slot list', (WidgetTester tester) async {
    await tester.pumpWidget(const SoccerManagerApp());
    await tester.pumpAndSettle();

    // 初回の5枚の説明は無く、すぐタイトルが出る(2026-11-25)。セーブが
    // まだ無いので「続きから」は出ず、「新しく始める」が主役。
    expect(find.text('サッカー経営マネージャー'), findsOneWidget);
    expect(find.text('新しく始める'), findsOneWidget);
    expect(find.text('続きから'), findsNothing);
  });

  testWidgets('creating a club navigates to the home dashboard',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SoccerManagerApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('新しく始める').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'テストFC');
    await tester.tap(find.text('創設する'));
    await tester.pumpAndSettle();

    expect(find.text('テストFC'), findsWidgets);
    expect(find.text('選手'), findsOneWidget); // 左メニューの項目
  });

  testWidgets(
      'pressing back while on a non-home tab returns to the home tab '
      'instead of exiting to the title screen', (WidgetTester tester) async {
    await tester.pumpWidget(const SoccerManagerApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('新しく始める').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'テストFC');
    await tester.tap(find.text('創設する'));
    await tester.pumpAndSettle();

    // ホームから「選手」へ切り替える(ルートは積まれない)。横画面の左メニュー。
    // 上のバーには常にクラブ名があるので、画面の見出しで切り替わりを確かめる。
    expect(find.text('選手'), findsOneWidget);
    await tester.tap(find.text('選手'));
    await tester.pumpAndSettle();
    // 上バーの進むボタン(行き先の日付が書いてある)は残る。
    expect(find.byKey(const ValueKey('advance-button')), findsOneWidget);

    // ブラウザ/端末の戻る操作を発火する。
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    // タイトル画面まで戻るのではなく、ホームに戻るだけであるべき。
    expect(find.text('新しく始める'), findsNothing);
    expect(find.text('テストFC'), findsWidgets);

    // ホームタブの状態でもう一度戻る操作をすると、今度はタイトル画面へ戻る。
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('新しく始める'), findsWidgets);
  });

  testWidgets(
      'CupScreen announces the user club in the continental group table to '
      'screen readers, not just via background color',
      (WidgetTester tester) async {
    final handle = tester.ensureSemantics();
    // グループ表がListViewの遅延構築で画面外に隠れないよう、十分縦長な
    // ビューポートにしておく。
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    // GameStateのシーズン進行処理は実際の非同期I/O(SharedPreferences等)を
    // 伴うため、テストのフェイクタイムゾーンの外(runAsync)で実行する。
    late final String userId;
    final gameState = await tester.runAsync(() async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      userId = gs.userTeam.id;
      // 大陸カップは通常、5部制ピラミッドを1部優勝まで何シーズンもかけて
      // 昇格した末に生成される。このテストが検証したいのはCupScreenの
      // グループ表アクセシビリティのみなので、昇格を何シーズンも消化する
      // 代わりに大陸カップの状態を直接組み立てる。
      final opponents = [
        for (int i = 0; i < 7; i++)
          PlayerGenerator.generateSquad(
              id: 'continental-test-$i', name: '大陸クラブ$i', strengthTier: 65 + i),
      ];
      for (final t in opponents) {
        LineupUtils.autoFill(t);
      }
      gs.save!.continentalTeams = opponents;
      gs.save!.continentalCup = ContinentalCupEngine.create(
        name: '大陸チャンピオンズカップ',
        teamIds: [userId, ...opponents.map((t) => t.id)],
      );
      return gs;
    });
    expect(gameState!.continentalCup, isNotNull);

    await tester.pumpWidget(MaterialApp(
      home: ChangeNotifierProvider<GameState>.value(
        value: gameState,
        child: const CupScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('大陸カップ'));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel(RegExp('自クラブ。')), findsOneWidget);

    handle.dispose();
  });

  testWidgets(
      'the advance button shows a result dialog with the score '
      'instead of only a snackbar', (WidgetTester tester) async {
    // ホーム画面のListViewの遅延構築で次節カードが画面外にならないよう、
    // 十分縦長なビューポートにしておく。
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(const SoccerManagerApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('新しく始める').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'テストFC');
    await tester.tap(find.text('創設する'));
    await tester.pumpAndSettle();

    // 試合はいつも数秒のダイジェスト(結果のダイアログ)で見せる。
    // 進むボタンは次の予定の日に止まる(給料日など)ので、試合の日まで押す。
    for (var i = 0; i < 6; i++) {
      await tester.tap(find.byKey(const ValueKey('advance-button')).first);
      await tester.pumpAndSettle();
      if (find.textContaining('結果: ').evaluate().isNotEmpty) break;
    }

    expect(find.textContaining('結果: '), findsOneWidget);
    expect(find.text('閉じる'), findsOneWidget);

    await tester.tap(find.text('閉じる'));
    await tester.pumpAndSettle();

    expect(find.textContaining('結果: '), findsNothing);
  });
}
