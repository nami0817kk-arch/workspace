// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/main.dart';
import 'package:soccer_manager/models/incoming_offer.dart';
import 'package:soccer_manager/state/game_state.dart';
import 'package:soccer_manager/state/settings_controller.dart';
import 'package:soccer_manager/widgets/incoming_offers_card.dart';
import 'package:soccer_manager/widgets/supporter_month_card.dart';

import 'support/app_fonts.dart';

/// 大きな文字(1.5倍)・狭い欄で、ホームの札が崩れないこと(2026-11-23)。
///
/// - 最後通告の札: 見出しが細い列に押し込まれず、残りの日数は下の行へ回る
/// - 月ごとの期待の札: 見出しの月名が「…」に消えない
/// - 届いたオファー: 窓が閉じている間は、承諾できない理由といつ開くかを書く
void main() {
  setUpAll(loadAppFonts);
  tearDown(() => Tr.language = AppLanguage.system);

  Future<GameState> setUpGame(WidgetTester tester, AppLanguage lang) async {
    SharedPreferences.setMockInitialValues({});
    late GameState game;
    await tester.runAsync(() async {
      Tr.language = lang;
      game = GameState();
      await game.startNewGame('Seiran FC');
    });
    final s = game.save!;
    final t = game.today;
    // 窓の外(10月)で、期待が10を割って最後通告が出ている。
    s.today = DateTime(t.year, 10, 15);
    s.confidence = 8;
    s.supporterUltimatumUntil = DateTime(t.year, 11, 30);
    s.supporterLastMonthKey = t.year * 12 + 8; // 9月
    final mine = game.userTeam.players.first;
    s.incomingOffers = [
      IncomingOffer(
        id: 'o1',
        playerId: mine.id,
        playerName: mine.name,
        buyerClubName: 'Northbridge Athletic',
        amount: 1200000,
      ),
    ];
    return game;
  }

  Future<void> pumpCards(WidgetTester tester, GameState game) async {
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<GameState>.value(value: game),
        ChangeNotifierProvider<SettingsController>(
            create: (_) => SettingsController()),
      ],
      child: MaterialApp(
        // アプリの書体(同梱フォント)で測る。既定の書体は試験用の四角い字で、
        // 字の幅が実際と違う。
        theme: const SoccerManagerApp()
            .buildTheme(Brightness.dark, boldText: false),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: const Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              // 横画面のホームの左の欄くらいの幅。
              width: 330,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    SupporterUltimatumCard(),
                    SupporterMonthCard(),
                    IncomingOffersCard(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  for (final lang in [AppLanguage.japanese, AppLanguage.english]) {
    testWidgets('1.5倍の文字で札が崩れない $lang', (tester) async {
      final game = await setUpGame(tester, lang);
      await pumpCards(tester, game);
      expect(tester.takeException(), isNull);

      // 最後通告: 見出しは1行目にあり、残りの日数は見出しより下の行。
      final title = find
          .text(Tr.pick('サポーターからの最後通告', 'Final warning from the supporters'));
      final days = find.byKey(const ValueKey('ultimatum-days-left'));
      expect(title, findsOneWidget);
      expect(days, findsOneWidget);
      expect(
          tester.getTopLeft(days).dy, greaterThan(tester.getTopLeft(title).dy),
          reason: '残りの日数が見出しの横に並び、見出しを細い列に押し込んでいる');
      // 見出しは欄の幅の半分以上を使える(細い列に押し込まれていない)。
      expect(tester.getSize(title).width, greaterThan(330 * 0.5));

      // 月ごとの期待: 見出しが1行に収まる(「…」で月名が消えない)。
      final month = find.text(Tr.pick('9月の期待', 'Fans in September'));
      expect(month, findsOneWidget);
      final para = tester.renderObject<RenderParagraph>(month);
      expect(para.didExceedMaxLines, isFalse, reason: '見出しの月名が「…」に消えている');

      // 窓が閉じている間は、承諾できない理由を書く。
      expect(
          find.byKey(const ValueKey('offers-window-closed')), findsOneWidget);
      expect(
          find.textContaining(Tr.pick('移籍の窓が開くと承諾できます', 'You can accept once')),
          findsOneWidget);
    });
  }
}
