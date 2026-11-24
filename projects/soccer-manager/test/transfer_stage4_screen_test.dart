import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/l10n/app_localizations.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/screens/player_detail_screen.dart';
import 'package:soccer_manager/screens/transfer_bid_screen.dart';
import 'package:soccer_manager/screens/transfer_screen.dart';
import 'package:soccer_manager/state/game_state.dart';
import 'package:soccer_manager/state/settings_controller.dart';
import 'package:soccer_manager/widgets/estimate_stars.dart';

/// 画面の直し 第4段: 移籍の画面(2026-11-25)。
/// - 一覧の行から選手の詳しい画面が開き、「操作」から入札の画面へ進める
/// - 入札の画面: 資金を超えると「提示する」が押せず、足りない額が出る
/// - 窓が閉じているあいだは「注目」が先
/// - 空の交渉から、売りに出ている選手を探す入口
/// - 所属クラブの字を縮めない
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => Tr.language = AppLanguage.system);

  Future<(GameState, SettingsController)> start(WidgetTester tester,
      {Size size = const Size(1704, 786)}) async {
    late final GameState game;
    late final SettingsController settings;
    await tester.runAsync(() async {
      settings = SettingsController();
      await settings.init();
      game = GameState();
      await game.startNewGame('四段FC');
    });
    Tr.language = AppLanguage.japanese;
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    return (game, settings);
  }

  Future<void> pump(WidgetTester tester, GameState game,
      SettingsController settings, Widget home) async {
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<GameState>.value(value: game),
        ChangeNotifierProvider<SettingsController>.value(value: settings),
      ],
      child: MaterialApp(
        locale: Locale(Tr.isEnglish ? 'en' : 'ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('探すの行を押すと詳しい画面、操作から入札の画面へ', (tester) async {
    final (game, settings) = await start(tester);
    await pump(tester, game, settings, const TransferScreen(initialTab: 1));
    expect(tester.takeException(), isNull, reason: '探すの一覧');
    final row = find.byWidgetPredicate((w) =>
        w.key is ValueKey<String> &&
        (w.key! as ValueKey<String>).value.startsWith('target-row-'));
    expect(row, findsWidgets);
    final id = ((tester.widget(row.first).key! as ValueKey<String>).value)
        .substring('target-row-'.length);
    // 所属クラブの字は縮めない(FittedBox に入れない・12)。
    final club = game.clubNameOf(id)!;
    final clubText = find.descendant(of: row.first, matching: find.text(club));
    expect(clubText, findsOneWidget);
    expect(tester.widget<Text>(clubText).style!.fontSize, 12);
    expect(find.ancestor(of: clubText, matching: find.byType(FittedBox)),
        findsNothing);
    // 見立ては星で出る。
    expect(find.descendant(of: row.first, matching: find.byType(EstimateStars)),
        findsWidgets);

    await tester.tap(row.first);
    await tester.pumpAndSettle();
    expect(find.byType(PlayerDetailScreen), findsOneWidget);
    expect(tester.takeException(), isNull, reason: '詳しい画面');
    expect(find.byKey(const ValueKey('detail-estimate')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('player-actions')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: '操作の一覧');
    expect(find.byKey(const ValueKey('action-watch')), findsOneWidget);
    expect(find.byKey(const ValueKey('action-scout')), findsOneWidget);
    expect(find.byKey(const ValueKey('action-compare')), findsOneWidget);
    final bid = find.byKey(const ValueKey('action-bid'));
    expect(bid, findsOneWidget);
    await tester.tap(bid);
    await tester.pumpAndSettle();
    expect(find.byType(TransferBidScreen), findsOneWidget);
    // 交換・出来高・上乗せの行がある。
    for (final k in [
      'bid-fee',
      'bid-pay',
      'bid-addon',
      'bid-sellon',
      'bid-exchange'
    ]) {
      expect(find.byKey(ValueKey(k)), findsOneWidget, reason: k);
    }
    expect(tester.takeException(), isNull);
    await tester.pump(GameState.persistDebounce);
  });

  testWidgets('入札: いま払う額が資金を超えると押せず、足りない額が出る', (tester) async {
    final (game, settings) = await start(tester);
    final p = game.transferTargets.first;
    game.save!.budget = 0;
    await pump(tester, game, settings, TransferBidScreen(playerId: p.id));
    final submit = find.byKey(const ValueKey('bid-submit'));
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    expect(find.byKey(const ValueKey('bid-blocked')), findsOneWidget);
    expect(find.textContaining('あと'), findsWidgets);
    // 資金があれば押せる。
    game.save!.budget = 1 << 40;
    await pump(tester, game, settings,
        TransferBidScreen(key: const ValueKey('b'), playerId: p.id));
    expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('bid-submit')))
            .onPressed,
        isNotNull);
    expect(tester.takeException(), isNull);
    await tester.pump(GameState.persistDebounce);
  });

  testWidgets('窓が閉じているあいだは、候補の最初の札が注目', (tester) async {
    final (game, settings) = await start(tester);
    game.save!.today = DateTime(game.today.year, 10, 15);
    expect(game.isTransferWindowOpen, isFalse);
    await pump(tester, game, settings, const TransferScreen());
    final first =
        tester.widget<ChoiceChip>(find.byKey(const ValueKey('chip-0')));
    expect((first.label as Text).data, startsWith('注目'));
    expect(first.selected, isTrue);
    expect(find.byKey(const ValueKey('watch-closed-hint')), findsOneWidget);
    await tester.pump(GameState.persistDebounce);
  });

  testWidgets('空の交渉から、売りに出ている選手の一覧へ', (tester) async {
    final (game, settings) = await start(tester);
    expect(game.transferTalks, isEmpty);
    await pump(tester, game, settings,
        const TransferScreen(initialTab: TransferScreen.offersTab));
    final go = find.byKey(const ValueKey('talks-empty-listed'));
    await tester.scrollUntilVisible(go, 120,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(go);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('search-active-filters')), findsOneWidget);
    expect(find.text('移籍リスト入り'), findsOneWidget);
    await tester.pump(GameState.persistDebounce);
  });

  test('探すの絞り込み: 年齢・売りに出ている・地域', () async {
    SharedPreferences.setMockInitialValues({});
    final game = GameState();
    await game.startNewGame('絞りFC');
    final all = game.transferTargets;
    final young = TransferScreen.searchPlayers(
        game, all, TransferSearchFilter()..maxAge = 21);
    expect(young, isNotEmpty);
    expect(young.every((p) => p.age <= 21), isTrue);
    final listed = TransferScreen.searchPlayers(
        game, all, TransferSearchFilter()..listedOnly = true);
    expect(listed.every(game.isListedByClub), isTrue);
    final region = game.scoutRegions.first;
    final inRegion = TransferScreen.searchPlayers(
        game, all, TransferSearchFilter()..region = region.key);
    final ids = {
      for (final t in region.teams)
        for (final p in t.players) p.id
    };
    expect(inRegion, isNotEmpty);
    expect(inRegion.every((p) => ids.contains(p.id)), isTrue);
    // 星の下限を付けると、見えていない選手は外れる。
    final starred = TransferScreen.searchPlayers(
        game, all, TransferSearchFilter()..minOverallStars = 2);
    expect(starred.every((p) => game.overallEstimate(p) != null), isTrue);
  });
}
