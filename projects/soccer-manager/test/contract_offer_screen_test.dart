import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/logic/contract_engine.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/screens/contract_offer_screen.dart';
import 'package:soccer_manager/state/game_state.dart';
import 'package:soccer_manager/state/settings_controller.dart';

/// FM 風の契約の画面(2026-11-22)。更新・移籍・仮契約を同じ画面で話す。
void main() {
  tearDown(() => Tr.language = AppLanguage.system);

  Future<GameState> newGame(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    late GameState game;
    await tester.runAsync(() async {
      game = GameState();
      await game.startNewGame('自分FC');
      game.save!.budget = 1 << 40;
    });
    return game;
  }

  Future<NavigatorState> pumpHost(
      WidgetTester tester, GameState game, Size size,
      {double textScale = 1.0}) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<GameState>.value(value: game),
        ChangeNotifierProvider<SettingsController>(
            create: (_) => SettingsController()),
      ],
      child: MaterialApp(
        navigatorKey: navKey,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const Scaffold(),
      ),
    ));
    return navKey.currentState!;
  }

  for (final (name, size, scale, lang) in [
    ('横画面', const Size(852, 393), 1.0, AppLanguage.japanese),
    ('狭い縦画面・文字130%', const Size(320, 568), 1.3, AppLanguage.japanese),
    ('英語・横画面', const Size(852, 393), 1.0, AppLanguage.english),
  ]) {
    testWidgets('3つの種類とも、$nameで はみ出さずに出る', (tester) async {
      Tr.language = lang;
      final game = await newGame(tester);
      final nav = await pumpHost(tester, game, size, textScale: scale);
      final mine = game.userTeam.players.first;
      final other = game.save!.league.teams
          .firstWhere((t) => t.id != game.save!.userTeamId);
      for (final (p, kind) in [
        (mine, ContractKind.renewal),
        (game.save!.freeAgents.first, ContractKind.signing),
        (other.players.first, ContractKind.preContract),
      ]) {
        openContractOffer(nav.context, player: p, kind: kind);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$kind');
        expect(find.byKey(const ValueKey('contract-offer-submit')),
            findsOneWidget);
        nav.pop();
        await tester.pumpAndSettle();
      }
    });
  }

  testWidgets('更新は画面で年俸を話して決める(年俸が据え置きにならない)', (tester) async {
    Tr.language = AppLanguage.japanese;
    final game = await newGame(tester);
    final nav = await pumpHost(tester, game, const Size(852, 393));
    final p = game.userTeam.players
        .firstWhere((p) => game.renewalBlockReason(p) == null);
    final before = p.wage;
    final endBefore = p.contractEndYear;
    openContractOffer(nav.context, player: p, kind: ContractKind.renewal);
    await tester.pumpAndSettle();
    expect(game.pendingContractNegotiation!.counterWage, greaterThan(before),
        reason: '選手は今より上を求める');
    // 低めに出すと、代理人の返事が帯に出て、交渉が続く。
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byTooltip('下げる').first);
      await tester.pump();
    }
    expect(find.text('要求に合わせる'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('contract-offer-submit')));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('なら考えます'), findsOneWidget);
    expect(game.pendingContractNegotiation!.roundsUsed, 1);
    final want = game.pendingContractNegotiation!.counterWage;
    // 要求どおりに出すと、その年俸で更新される。
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('contract-offer-submit')));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(p.wage, want);
    expect(p.contractEndYear, greaterThan(endBefore));
    expect(game.pendingContractNegotiation, isNull);
    expect(find.byType(ContractOfferScreen), findsNothing);
    expect(ContractEngine.untilLabel(p.contractEndYear), isNotEmpty);
  });

  testWidgets('仮契約は年数とオプションを選んで結べる', (tester) async {
    Tr.language = AppLanguage.japanese;
    final game = await newGame(tester);
    final nav = await pumpHost(tester, game, const Size(852, 393));
    final other = game.save!.league.teams
        .firstWhere((t) => t.id != game.save!.userTeamId);
    final Player p = other.players.first;
    openContractOffer(nav.context,
        player: p, kind: ContractKind.preContract, fromClubName: other.name);
    await tester.pumpAndSettle();
    expect(find.text(other.name), findsOneWidget);
    expect(find.text('仮契約を結ぶ'), findsOneWidget);
  });
}
