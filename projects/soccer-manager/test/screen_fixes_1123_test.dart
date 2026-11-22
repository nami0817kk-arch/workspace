import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/l10n/app_localizations.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/logic/economy_scale.dart';
import 'package:soccer_manager/logic/next_action_advisor.dart';
import 'package:soccer_manager/models/club_infrastructure.dart';
import 'package:soccer_manager/models/incoming_offer.dart';
import 'package:soccer_manager/screens/cup_screen.dart';
import 'package:soccer_manager/screens/player_detail_screen.dart';
import 'package:soccer_manager/screens/squad_screen.dart';
import 'package:soccer_manager/screens/transfer_screen.dart';
import 'package:soccer_manager/state/game_state.dart';
import 'package:soccer_manager/state/settings_controller.dart';
import 'package:soccer_manager/widgets/club_license_card.dart';
import 'package:soccer_manager/widgets/squad_table.dart';

/// 2026-11-23: 画面の不具合(移籍の画面の届いたオファー・カップの国内タブの
/// 見出し・選手の契約タブの割れ・ライセンスの猶予の行・0円の表示)を固定する。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => Tr.language = AppLanguage.system);

  Future<(GameState, SettingsController)> start(WidgetTester tester) async {
    late final GameState game;
    late final SettingsController settings;
    await tester.runAsync(() async {
      settings = SettingsController();
      await settings.init();
      game = GameState();
      await game.startNewGame('修正FC');
    });
    Tr.language = AppLanguage.japanese;
    // 横画面のスマホ(2列に割れる幅)。
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

  group('1. 移籍の画面に届いたオファー', () {
    testWidgets('タブに件数が出て、受ける・断るのボタンと移籍リストの一覧がある', (tester) async {
      final (game, settings) = await start(tester);
      final players = game.userTeam.players;
      final a = players[0], b = players[1];
      a.isTransferListed = true;
      b.isTransferListed = true;
      game.save!.incomingOffers
        ..clear()
        ..add(IncomingOffer(
            id: 'x1',
            playerId: a.id,
            playerName: a.name,
            buyerClubName: '北風シティ',
            amount: 1000));
      await pump(tester, game, settings,
          const TransferScreen(initialTab: TransferScreen.offersTab));

      // 左の「移籍」の印(incomingOffers の件数)と同じ数がタブに出る。
      expect(find.text('オファー (1)'), findsOneWidget);
      expect(find.byKey(const ValueKey('transfer-offers-tab')), findsOneWidget);
      expect(find.textContaining('北風シティが${a.name}に'), findsOneWidget);
      expect(find.text('拒否'), findsOneWidget);
      expect(find.text('承諾'), findsOneWidget);

      // 移籍リストに載せている2人と、外すボタン。
      expect(find.text('移籍リストに載せている選手 (2)'), findsOneWidget);
      expect(find.byKey(ValueKey('listed-${b.id}')), findsOneWidget);
      await tester.tap(find.byKey(ValueKey('unlist-${b.id}')));
      await tester.pumpAndSettle();
      expect(b.isTransferListed, isFalse);
      expect(find.text('移籍リストに載せている選手 (1)'), findsOneWidget);

      // 断ると消える。
      await tester.tap(find.text('拒否'));
      await tester.pumpAndSettle();
      expect(game.incomingOffers, isEmpty);
      expect(find.text('オファー (0)'), findsOneWidget);
      await tester.pump(GameState.persistDebounce);
    });

    test('状況の判断カードは移籍の画面の届いたオファーへ行く', () async {
      final gs = GameState();
      await gs.startNewGame('修正FC');
      final p = gs.userTeam.players.first;
      gs.save!.incomingOffers.add(IncomingOffer(
          id: 'x2',
          playerId: p.id,
          playerName: p.name,
          buyerClubName: 'X',
          amount: 100));
      // 先に来る判断(契約・予算など)を消しておく。
      gs.save!.budget = 1 << 30;
      for (final q in gs.userTeam.players) {
        q.contractYearsRemaining = 3;
      }
      final action = NextActionAdvisor.top(gs.save!, gs.userTeam);
      expect(action?.target, NextActionTarget.transferOffers);
    });
  });

  testWidgets('2. カップの国内タブ: 国内カップの回戦表の頭に大会名の見出し', (tester) async {
    final (game, settings) = await start(tester);
    await pump(tester, game, settings, const CupScreen());
    final cup = game.domesticCup!;
    final heading = find.byKey(const ValueKey('domestic-cup-heading'));
    expect(heading, findsOneWidget);
    expect(find.descendant(of: heading, matching: find.text(cup.name)),
        findsOneWidget);
    // リーグカップがあるなら、その札より下に見出しが来る(区切られている)。
    if (game.leagueCup != null) {
      final leagueCupTop =
          tester.getTopLeft(find.text(game.leagueCupName).first).dy;
      expect(tester.getTopLeft(heading).dy, greaterThan(leagueCupTop));
    }
    await tester.pump(GameState.persistDebounce);
  });

  testWidgets('4. 契約タブ: 移籍リストのボタンと説明が同じ列にある', (tester) async {
    final (game, settings) = await start(tester);
    final p = game.userTeam.players.first;
    await pump(tester, game, settings, PlayerDetailScreen(playerId: p.id));
    await tester.tap(find.text('契約'));
    await tester.pumpAndSettle();
    final block = find.byKey(const ValueKey('transfer-list-block'));
    expect(block, findsOneWidget);
    final button = find.descendant(
        of: block, matching: find.byKey(const ValueKey('transfer-list')));
    final note =
        find.descendant(of: block, matching: find.textContaining('相場は契約の残り年数'));
    expect(button, findsOneWidget);
    expect(note, findsOneWidget);
    // 同じ列(左端が同じ)で、説明はボタンのすぐ下。
    expect(tester.getTopLeft(note).dx, tester.getTopLeft(button).dx);
    expect(tester.getTopLeft(note).dy,
        greaterThan(tester.getBottomLeft(button).dy - 1));
    await tester.pump(GameState.persistDebounce);
  });

  group('9. ライセンスの猶予の行', () {
    Future<void> pumpCard(WidgetTester tester, GameState game,
        SettingsController settings) async {
      await pump(
          tester,
          game,
          settings,
          const Scaffold(
              body: SingleChildScrollView(child: ClubLicenseCard())));
    }

    testWidgets('届いていれば「達成済み」、行は見出しの下', (tester) async {
      final (game, settings) = await start(tester);
      final s = game.save!;
      s.licenseGraceTier = s.currentDivisionTier;
      s.licenseGraceSeason = s.league.season;
      s.infrastructure.facilityLevels[FacilityType.stadium] =
          ClubInfrastructure.maxLevel;
      await pumpCard(tester, game, settings);
      final grace = find.byKey(const ValueKey('license-grace'));
      expect(grace, findsOneWidget);
      expect(find.textContaining('達成済み'), findsOneWidget);
      final title = find.textContaining('クラブライセンス');
      expect(tester.getTopLeft(grace).dy,
          greaterThan(tester.getTopLeft(title).dy));
      await tester.pump(GameState.persistDebounce);
    });

    testWidgets('届いていなければ「必要(猶予中)」', (tester) async {
      final (game, settings) = await start(tester);
      final s = game.save!;
      s.licenseGraceTier = s.currentDivisionTier;
      s.licenseGraceSeason = s.league.season;
      s.infrastructure.facilityLevels[FacilityType.stadium] = 0;
      s.infrastructure.construction.clear();
      if (game.stadiumMeetsLicense(s.currentDivisionTier)) return;
      await pumpCard(tester, game, settings);
      expect(find.textContaining('猶予中'), findsOneWidget);
      expect(find.textContaining('達成済み'), findsNothing);
      await tester.pump(GameState.persistDebounce);
    });
  });

  testWidgets('10. 横画面の選手の表にも移籍リストの印', (tester) async {
    final (game, settings) = await start(tester);
    final players = [...game.userTeam.players]
      ..sort((a, b) => a.position.index.compareTo(b.position.index));
    for (final p in game.userTeam.players) {
      p.isTransferListed = false;
    }
    players.first.isTransferListed = true;
    await pump(tester, game, settings, const SquadScreen());
    expect(find.byType(SquadTable), findsOneWidget);
    expect(find.byKey(const ValueKey('squad-table-listed')), findsOneWidget);
    await tester.pump(GameState.persistDebounce);
  });

  test('11. 0円は「0円」/「0 yen」、小数ありの側にも桁区切り', () {
    Tr.language = AppLanguage.japanese;
    expect(formatMoney(0), '0円');
    expect(formatMoney(123456789), '12,345.7億');
    expect(formatMoney(35000000), '3,500億');
    Tr.language = AppLanguage.english;
    expect(formatMoney(0), '0 yen');
    expect(formatMoney(5), '50k yen');
    expect(formatMoney(123456789), '1,234.6bn yen');
  });
}
