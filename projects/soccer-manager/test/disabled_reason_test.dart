import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/l10n/app_localizations.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/models/matchday_promo.dart';
import 'package:soccer_manager/models/owner_work.dart';
import 'package:soccer_manager/screens/club_screen.dart';
import 'package:soccer_manager/screens/contract_board_screen.dart';
import 'package:soccer_manager/screens/owner_work_screen.dart';
import 'package:soccer_manager/screens/transfer_screen.dart';
import 'package:soccer_manager/screens/youth_screen.dart';
import 'package:soccer_manager/state/game_state.dart';
import 'package:soccer_manager/state/settings_controller.dart';
import 'package:soccer_manager/widgets/disabled_reason.dart';
import 'package:soccer_manager/widgets/equity_card.dart';

/// 押せない(無効の)ボタンのそばに、なぜ押せないかが出ていること(2026-11-24)。
///
/// 灰色のボタンだけでは、資金が足りないのか・今季は済んだのか・窓が閉じて
/// いるのかが分からなかった。代表の画面で、実際に押せない状態を作り、
/// 「ボタンが無効」かつ「理由の文字が出ている」ことを確かめる。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => Tr.language = AppLanguage.system);

  Future<(GameState, SettingsController)> start(WidgetTester tester,
      {AppLanguage language = AppLanguage.japanese}) async {
    late final GameState game;
    late final SettingsController settings;
    await tester.runAsync(() async {
      settings = SettingsController();
      await settings.init();
      game = GameState();
      await game.startNewGame('理由FC');
    });
    Tr.language = language;
    // 横画面のスマホ(標準の向き)。はみ出しがあればテストが落ちる。
    tester.view.physicalSize = const Size(1704, 786);
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
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// [inside] の中に出ている理由(DisabledReason)の文字。
  List<String> reasonsIn(WidgetTester tester, Finder inside) => [
        for (final r in tester.widgetList<DisabledReason>(
            find.descendant(of: inside, matching: find.byType(DisabledReason))))
          if ((r.reason ?? '').isNotEmpty) r.reason!,
      ];

  /// [button] を含むいちばん内側の Card。
  Finder cardOf(Finder button) =>
      find.ancestor(of: button, matching: find.byType(Card)).first;

  testWidgets('施設の増築: 資金が足りないと押せず、足りない額が出る。足りれば出ない', (tester) async {
    final (game, settings) = await start(tester);
    game.save!.budget = 0;
    await pump(tester, game, settings,
        const ClubScreen(section: ClubSection.facilities));

    final buttons = find.ancestor(
        of: find.textContaining('で増築'), matching: find.byType(FilledButton));
    expect(buttons, findsWidgets);
    for (final b in tester.widgetList<FilledButton>(buttons)) {
      expect(b.onPressed, isNull, reason: '資金0なのに増築が押せる');
    }
    final reasons = reasonsIn(tester, cardOf(buttons.first));
    expect(reasons, hasLength(1));
    expect(reasons.single, startsWith('資金が足りません(あと '));

    // 資金が足りれば、理由は出ず、ボタンは押せる。
    game.save!.budget = 1 << 30;
    await pump(tester, game, settings,
        const ClubScreen(section: ClubSection.facilities, key: ValueKey('b')));
    expect(find.byKey(const ValueKey('upgrade-blocked')), findsNothing);
    expect(tester.widget<FilledButton>(buttons.first).onPressed, isNotNull);
    await tester.pump(GameState.persistDebounce);
  });

  testWidgets('オーナーの仕事: 資金不足は額を出し、今季済みはボタンの字だけ', (tester) async {
    final (game, settings) = await start(tester);
    final work = ownerWorks.firstWhere((w) => w.id == 'merch_drive');
    game.save!.budget = 0;
    await pump(tester, game, settings, const OwnerWorkScreen());

    final button = find.byKey(ValueKey('owner-work-do-${work.id}'));
    await tester.scrollUntilVisible(button, 120,
        scrollable: find.byType(Scrollable).first);
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    expect(find.descendant(of: button, matching: find.text('実行')),
        findsOneWidget);
    expect(reasonsIn(tester, cardOf(button)).single,
        startsWith('資金が足りません(あと '));

    // 今季もう打った手は、ボタンの字が理由になる(下に重ねて出さない)。
    game.save!.budget = 1 << 30;
    game.save!.ownerWorkDoneSeason[work.id] = game.save!.league.season;
    await pump(tester, game, settings,
        const OwnerWorkScreen(key: ValueKey('b')));
    await tester.scrollUntilVisible(button, 120,
        scrollable: find.byType(Scrollable).first);
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    expect(find.descendant(of: button, matching: find.text('今季済み')),
        findsOneWidget);
    expect(reasonsIn(tester, cardOf(button)), isEmpty);
    await tester.pump(GameState.persistDebounce);
  });

  testWidgets('試合日のイベント: 費用が払えないものは押せず、足りない額が出る', (tester) async {
    final (game, settings) = await start(tester);
    game.save!.budget = 0;
    await pump(tester, game, settings, const OwnerWorkScreen());

    final paid = matchdayPromos.firstWhere((p) => p.cost > 0);
    final button = find.byKey(ValueKey('promo-set-${paid.id}'));
    await tester.scrollUntilVisible(button, 120,
        scrollable: find.byType(Scrollable).first);
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    final column =
        find.ancestor(of: button, matching: find.byType(Column)).first;
    expect(reasonsIn(tester, column).single, startsWith('資金が足りません(あと '));

    // 無料のイベントは押せて、理由も出ない。
    final free = matchdayPromos.where((p) => p.cost == 0).firstOrNull;
    if (free != null) {
      final freeButton = find.byKey(ValueKey('promo-set-${free.id}'));
      await tester.scrollUntilVisible(freeButton, 120,
          scrollable: find.byType(Scrollable).first);
      expect(tester.widget<FilledButton>(freeButton).onPressed, isNotNull);
      expect(
          reasonsIn(
              tester,
              find
                  .ancestor(of: freeButton, matching: find.byType(Column))
                  .first),
          isEmpty);
    }
    await tester.pump(GameState.persistDebounce);
  });

  testWidgets('契約の更新: 資金不足と「延長しない」は、行の下に理由が出る', (tester) async {
    final (game, settings) = await start(tester);
    final players = game.userTeam.players;
    for (final q in players) {
      q.contractYearsRemaining = 3;
    }
    final short = players[0], refuses = players[1];
    short.contractYearsRemaining = 1;
    refuses.contractYearsRemaining = 1;
    refuses.refusesRenewal = true;
    game.save!.budget = 0;
    await pump(tester, game, settings, const ContractBoardScreen());

    for (final (p, text) in [
      (short, '資金が足りません(あと '),
      (refuses, '契約を延長しないと言っています'),
    ]) {
      final button = find.byKey(ValueKey('board-renew-${p.id}'));
      await tester.scrollUntilVisible(button, 120,
          scrollable: find.byType(Scrollable).first);
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      final row =
          find.ancestor(of: button, matching: find.byType(Container)).first;
      expect(reasonsIn(tester, row).single, startsWith(text));
    }

    // 資金が足りれば、応じない選手だけが押せないまま残る。
    game.save!.budget = 1 << 30;
    await pump(tester, game, settings,
        const ContractBoardScreen(key: ValueKey('b')));
    final ok = find.byKey(ValueKey('board-renew-${short.id}'));
    await tester.scrollUntilVisible(ok, 120,
        scrollable: find.byType(Scrollable).first);
    expect(tester.widget<FilledButton>(ok).onPressed, isNotNull);
    expect(
        reasonsIn(tester,
            find.ancestor(of: ok, matching: find.byType(Container)).first),
        isEmpty);
    await tester.pump(GameState.persistDebounce);
  });

  testWidgets('移籍の注目: 窓が閉じていると獲得が押せず、表の上に1回だけ理由が出る', (tester) async {
    final (game, settings) = await start(tester);
    final target = game.transferTargets.first;
    game.save!.watchlistPlayerIds.add(target.id);

    // 窓が開いているあいだは、理由は出ない。
    expect(game.isTransferWindowOpen, isTrue);
    // 注目は「候補」のタブの2つ目の札(2026-11-24 にタブを3つにまとめた)。
    Future<void> openWatch() async {
      await tester.tap(find.byKey(const ValueKey('chip-1')).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    await pump(tester, game, settings, const TransferScreen());
    await openWatch();
    expect(reasonsIn(tester, find.byType(TransferScreen)), isEmpty);

    // 夏の窓の締切を過ぎた秋の日。
    game.save!.today = DateTime(game.today.year, 10, 15);
    expect(game.isTransferWindowOpen, isFalse);
    await pump(tester, game, settings,
        const TransferScreen(key: ValueKey('b')));
    await openWatch();
    final sign = find.ancestor(
        of: find.text('獲得'), matching: find.byType(FilledButton));
    expect(sign, findsOneWidget);
    expect(tester.widget<FilledButton>(sign).onPressed, isNull);
    final blocked = find.byKey(const ValueKey('target-table-blocked'));
    expect(blocked, findsOneWidget);
    final reason = tester.widget<DisabledReason>(blocked).reason!;
    expect(reason, contains('閉じています'));
    expect(reason, contains('次の窓は'));
    expect(find.textContaining('獲得はそれまで押せません'), findsOneWidget);
    await tester.pump(GameState.persistDebounce);
  });

  testWidgets('持分: 外部の株主がいないと買い戻せず、理由が出る', (tester) async {
    final (game, settings) = await start(tester);
    expect(game.ownerShare, 100);
    await pump(
        tester,
        game,
        settings,
        const Scaffold(
            body: SingleChildScrollView(child: EquityCard())));
    final buyBack = find.ancestor(
        of: find.textContaining('買い戻す'), matching: find.byType(OutlinedButton));
    expect(tester.widget<OutlinedButton>(buyBack).onPressed, isNull);
    expect(find.byKey(const ValueKey('equity-buy-blocked')), findsOneWidget);
    expect(find.textContaining('買い戻す株がありません'), findsOneWidget);
    // 売るほうは押せるので、売れない理由は出ない。
    expect(find.byKey(const ValueKey('equity-sell-blocked')), findsNothing);
    await tester.pump(GameState.persistDebounce);
  });

  testWidgets('ユース: 資金が足りないと候補の更新が押せず、一覧の上に理由が出る', (tester) async {
    final (game, settings) = await start(tester);
    game.save!.budget = 0;
    await pump(tester, game, settings, const YouthScreen());

    final refresh = find.ancestor(
        of: find.byIcon(Icons.refresh), matching: find.byType(IconButton));
    await tester.scrollUntilVisible(refresh, 120,
        scrollable: find.byType(Scrollable).first);
    expect(tester.widget<IconButton>(refresh).onPressed, isNull);
    final blocked = find.byKey(const ValueKey('youth-refresh-blocked'));
    expect(blocked, findsOneWidget);
    expect(tester.widget<DisabledReason>(blocked).reason,
        contains('資金が足りません(あと '));
    // ふつうの候補(スカウトで取る)がいれば、獲得が押せない理由も1回だけ出る。
    if (game.scoutCandidates.any((p) => !game.isScoutedPro(p))) {
      final scout = tester.widget<DisabledReason>(
          find.byKey(const ValueKey('youth-scout-blocked')));
      expect(scout.reason, contains('資金が足りません(あと '));
    }
    await tester.pump(GameState.persistDebounce);
  });

  testWidgets('英語でも理由が出て、横画面ではみ出さない', (tester) async {
    final (game, settings) =
        await start(tester, language: AppLanguage.english);
    game.save!.budget = 0;
    await pump(tester, game, settings,
        const ClubScreen(section: ClubSection.facilities));
    expect(find.textContaining('Not enough funds ('), findsWidgets);

    await pump(tester, game, settings, const OwnerWorkScreen());
    final paid = matchdayPromos.firstWhere((p) => p.cost > 0);
    final button = find.byKey(ValueKey('promo-set-${paid.id}'));
    await tester.scrollUntilVisible(button, 120,
        scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('Not enough funds ('), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pump(GameState.persistDebounce);
  });
}
