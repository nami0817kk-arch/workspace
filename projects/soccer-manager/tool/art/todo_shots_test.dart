/// 「やること」の一覧・印・進むボタン・押せない理由を、横画面で PNG に書き出す。
///
/// **CI では回らない。** 実行するとファイルを書く。
///
///     flutter test tool/art/todo_shots_test.dart --dart-define=OUT=<出力先>
///
/// 切り替え(どれも省略できる): `LOOK=light|dark`、`LANG=ja|en`、
/// `DEVICE=phone|ipad`。
library;

// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/l10n/app_localizations.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/logic/proposal_engine.dart';
import 'package:soccer_manager/logic/todo_advisor.dart';
import 'package:soccer_manager/main.dart';
import 'package:soccer_manager/models/club_infrastructure.dart';
import 'package:soccer_manager/models/incoming_offer.dart';
import 'package:soccer_manager/models/owner_event.dart';
import 'package:soccer_manager/models/owner_work.dart';
import 'package:soccer_manager/monetization/ad_service.dart';
import 'package:soccer_manager/monetization/monetization_controller.dart';
import 'package:soccer_manager/screens/home_screen.dart';
import 'package:soccer_manager/screens/main_shell.dart';
import 'package:soccer_manager/state/game_state.dart';
import 'package:soccer_manager/state/settings_controller.dart';
import 'package:soccer_manager/widgets/fm_panel.dart';
import 'package:soccer_manager/widgets/landscape_scale.dart';
import 'package:soccer_manager/widgets/notch_side_insets.dart';
import 'package:soccer_manager/widgets/shell_nav.dart';

import '../../test/support/app_fonts.dart';
import '../../test/support/stub_purchase_service.dart';

const _look = String.fromEnvironment('LOOK', defaultValue: 'light');
const _lang = String.fromEnvironment('LANG', defaultValue: 'ja');
const _device = String.fromEnvironment('DEVICE', defaultValue: 'phone');
const _out = String.fromEnvironment('OUT',
    defaultValue: 'build/todo_shots/${_look}_${_lang}_$_device');
const _ipad = _device == 'ipad';
const _en = _lang == 'en';
const _size = _ipad ? Size(1376, 1032) : Size(844, 390);

void main() {
  setUpAll(() async {
    await loadAppFonts();
    final root = Platform.environment['FLUTTER_ROOT'] ??
        File(Platform.resolvedExecutable).parent.parent.parent.parent.path;
    final icons = File(
        '$root/bin/cache/artifacts/material_fonts/materialicons-regular.otf');
    final loader = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.view(icons.readAsBytesSync().buffer)));
    await loader.load();
  });

  /// シェルを出し、[shots] の中で撮る。
  Future<void> run(
    WidgetTester tester,
    String scene, {
    Future<void> Function(GameState gs)? arrange,
    required Future<void> Function(
            ShellNav nav, Future<void> Function(String name) shoot)
        shots,
  }) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = _size * 2;
    if (!_ipad) {
      tester.view.padding =
          const FakeViewPadding(left: 118, right: 118, bottom: 42);
      tester.view.viewPadding = tester.view.padding;
    }
    SharedPreferences.setMockInitialValues({});
    late final SettingsController settings;
    late final MonetizationController monetization;
    late final GameState game;
    await tester.runAsync(() async {
      settings = SettingsController();
      await settings.init();
      Tr.language = _en ? AppLanguage.english : AppLanguage.japanese;
      monetization = MonetizationController(
          adService: NoOpAdService(), purchases: StubPurchaseService());
      await monetization.initialize();
      game = GameState();
      await game.startNewGame(_en ? 'Blue Storm FC' : '青嵐FC');
      game.save!.firstRunGuideDismissed = true;
      if (arrange != null) await arrange(game);
    });
    addTearDown(() => Tr.language = AppLanguage.system);
    final key = GlobalKey();
    const app = SoccerManagerApp();
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<GameState>.value(value: game),
        ChangeNotifierProvider<SettingsController>.value(value: settings),
        ChangeNotifierProvider<MonetizationController>.value(
            value: monetization),
      ],
      child: RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: const Locale(_lang),
          theme: app.buildTheme(
              _look == 'dark' ? Brightness.dark : Brightness.light,
              boldText: false),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => LandscapeScale(
            child: FmThemeScope(
              light: app.buildTheme(Brightness.light, boldText: false),
              dark: app.buildTheme(Brightness.dark, boldText: false),
              child: NotchSideInsets(child: child!),
            ),
          ),
          home: const MainShell(),
        ),
      ),
    ));
    await tester.pump();
    final old = FlutterError.onError;
    FlutterError.onError = (d) {
      // ignore: avoid_print
      print('PROBLEM $scene ${d.exceptionAsString().split('\n').first}');
    };
    addTearDown(() => FlutterError.onError = old);

    Future<void> shoot(String name) async {
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      // 読み込み中のまま・白紙のまま撮っていないこと(docs/app-pitfalls.md 4)。
      expect(find.byType(CircularProgressIndicator).hitTestable(), findsNothing,
          reason: '$name が読み込み中のまま撮られている');
      expect(find.byType(Text), findsAtLeastNWidgets(3),
          reason: '$name に文字がほとんど無い');
      final b = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
      await tester.runAsync(() async {
        final image = await b.toImage(pixelRatio: 1.5);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        Directory(_out).createSync(recursive: true);
        File('$_out/${scene}_$name.png')
            .writeAsBytesSync(data!.buffer.asUint8List());
      });
    }

    // 全面の札(大事な場面)が出ていたら、閉じてから撮る。
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 600));
      final close =
          find.textContaining(_en ? 'Tap to close' : 'タップで閉じる').hitTestable();
      if (close.evaluate().isEmpty) break;
      await tester.tap(close.first, warnIfMissed: false);
    }
    await tester.pump(const Duration(milliseconds: 600));
    final nav = ShellNav.maybeOf(
        tester.element(find.byType(HomeScreen, skipOffstage: false)))!;
    await shots(nav, shoot);
    FlutterError.onError = old;
  }

  Finder rightPane() => find
      .descendant(
          of: find.byKey(const ValueKey('two-pane-right')),
          matching: find.byType(Scrollable))
      .first;

  testWidgets('始めたばかり(必須の行とおすすめ多数)', (tester) async {
    await run(tester, 'a_new', shots: (nav, shoot) async {
      await shoot('1_status');
      await tester.drag(rightPane(), const Offset(0, -260));
      await shoot('2_status_recommended');
      final more = find.byKey(const ValueKey('todo-more'));
      if (more.hitTestable().evaluate().isNotEmpty) {
        await tester.tap(more);
        await shoot('3_status_all');
      }
      nav.go(TodoPlaces.financeFunding);
      await shoot('4_finance_funding');
      nav.go(TodoPlaces.clubStaff);
      await shoot('5_club_staff');
      nav.go(TodoPlaces.ownerFans);
      await shoot('6_owner_fans');
      nav.go(TodoPlaces.transferPicks);
      await shoot('7_transfer');
    });
  });

  testWidgets('答えを待つ札が並ぶ(事件・オファー・提案)', (tester) async {
    await run(tester, 'b_must', arrange: (gs) async {
      final s = gs.save!;
      await gs.playNextMatchdayQuickSim();
      final other = s.league.teams.firstWhere((t) => t.id != gs.userTeam.id);
      s.pendingOwnerEvent = OwnerEventKind.sponsorExit;
      s.incomingOffers = [
        for (var i = 0; i < 2; i++)
          IncomingOffer(
            id: 'o$i',
            playerId: gs.userTeam.players[i].id,
            playerName: gs.userTeam.players[i].name,
            buyerClubName: other.name,
            amount: 500,
          ),
      ];
      final p = gs.userTeam.players.first;
      s.proposals.add(ManagerProposal(
          kind: ProposalKind.renew, playerId: p.id, playerName: p.name));
      s.budget = -200;
    }, shots: (nav, shoot) async {
      await shoot('1_status');
      await tester.drag(rightPane(), const Offset(0, -300));
      await shoot('2_status_cards');
      nav.go(TodoPlaces.transferOffers);
      await shoot('3_transfer_offers');
      nav.go(TodoPlaces.financeOverview);
      await shoot('4_finance_overview');
    });
  });

  testWidgets('やること0件', (tester) async {
    await run(tester, 'c_empty', arrange: (gs) async {
      final s = gs.save!;
      await gs.playNextMatchdayQuickSim();
      if (gs.pendingOwnerEvent != null) await gs.resolveOwnerEvent(0);
      if (s.sponsorDeal == null && s.pendingSponsorOffers.isNotEmpty) {
        await gs.chooseSponsor(0);
      }
      s.pendingSponsorOffers = [];
      s.pendingNamingOffers = [];
      s.slotSponsorOffers.clear();
      await gs.setOwnerGoal(gs.selectableOwnerGoals.first);
      for (final r in StaffRole.values) {
        final c = gs.staffCandidatesFor(r);
        if (s.infrastructure.staffFor(r) == null && c.isNotEmpty) {
          s.infrastructure.staff[r] = c.first;
        }
      }
      s.staffCandidates.clear();
      for (var i = 0; i < 10 && gs.isTransferWindowOpen; i++) {
        await gs.playNextMatchdayQuickSim();
        if (gs.pendingOwnerEvent != null) await gs.resolveOwnerEvent(0);
      }
      s.pendingRumor = null;
      s.agmDemand = null;
      s.pendingBoardReviewMessage = null;
      s.incomingOffers = [];
      s.proposals.clear();
      s.youthProspects.clear();
      s.pendingYouthIntake = [];
      s.staffOffers.clear();
      s.transferTalks.clear();
      s.supporterTrail.clear();
      for (final p in gs.userTeam.players) {
        p.contractYearsRemaining = 3;
        if (s.injuryPlans[p.id] == 'pending') s.injuryPlans.remove(p.id);
      }
      s.fanWorkMonthKey = gs.currentMonthKey;
      for (final w in ownerWorks) {
        s.ownerWorkDoneSeason[w.id] = s.league.season;
      }
      await gs.setMatchdayPromo('discount_day');
      s.budget = 0;
    }, shots: (nav, shoot) async {
      await shoot('1_status');
      // 押せない理由(資金0)。
      nav.go(TodoPlaces.clubFacilities);
      await shoot('2_facilities_disabled');
      nav.go(TodoPlaces.ownerWorks);
      await shoot('3_owner_works_disabled');
      nav.go(TodoPlaces.squadContracts);
      await shoot('4_contracts');
    });
  });
}
