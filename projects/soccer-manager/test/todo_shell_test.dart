// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/l10n/app_localizations.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/logic/day_events.dart';
import 'package:soccer_manager/logic/proposal_engine.dart';
import 'package:soccer_manager/logic/todo_advisor.dart';
import 'package:soccer_manager/main.dart';
import 'package:soccer_manager/models/club_infrastructure.dart';
import 'package:soccer_manager/models/incoming_offer.dart';
import 'package:soccer_manager/models/owner_event.dart';
import 'package:soccer_manager/models/owner_work.dart';
import 'package:soccer_manager/monetization/ad_service.dart';
import 'package:soccer_manager/monetization/monetization_controller.dart';
import 'package:soccer_manager/screens/contract_board_screen.dart';
import 'package:soccer_manager/screens/cup_screen.dart';
import 'package:soccer_manager/screens/home_screen.dart';
import 'package:soccer_manager/screens/main_shell.dart';
import 'package:soccer_manager/screens/owner_work_screen.dart';
import 'package:soccer_manager/screens/youth_screen.dart';
import 'package:soccer_manager/state/game_state.dart';
import 'package:soccer_manager/state/settings_controller.dart';
import 'package:soccer_manager/widgets/club_policy_card.dart';
import 'package:soccer_manager/widgets/disabled_reason.dart';
import 'package:soccer_manager/widgets/fm_panel.dart';
import 'package:soccer_manager/widgets/landscape_scale.dart';
import 'package:soccer_manager/widgets/owner_event_card.dart';
import 'package:soccer_manager/widgets/proposal_card.dart';
import 'package:soccer_manager/widgets/season_tickets_card.dart';
import 'package:soccer_manager/widgets/shell_nav.dart';
import 'package:soccer_manager/widgets/todo_list.dart';

import 'support/app_fonts.dart';
import 'support/stub_purchase_service.dart';

/// 横画面のシェルで、「やること」の一覧・印・行き先・進むボタンが、同じ源
/// (TodoAdvisor)から出ていること。
///
/// - 状況の右の欄に、必須とおすすめが件数つきで出る
/// - 行を押すと、左メニューの項目とタブが切り替わり、画面は重ならない
/// - 印の付く場所を開けば、必ずその用件が見つかる(事件の印はオーナー室
///   ではなく状況)
/// - 進むボタンは、どこまで進むかを動詞つきで書き、必須が残っていれば
///   件数の札を出す(進むのは止めない)
/// - 押せないボタンのそばに理由が出る
const _phone = Size(844, 390);

void main() {
  setUpAll(loadAppFonts);

  Future<GameState> pumpShell(
    WidgetTester tester, {
    bool en = false,
    Size size = _phone,
    Future<void> Function(GameState gs)? arrange,
  }) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = size * 2;
    SharedPreferences.setMockInitialValues({});
    late final SettingsController settings;
    late final MonetizationController monetization;
    late final GameState game;
    await tester.runAsync(() async {
      settings = SettingsController();
      await settings.init();
      Tr.language = en ? AppLanguage.english : AppLanguage.japanese;
      monetization = MonetizationController(
          adService: NoOpAdService(), purchases: StubPurchaseService());
      await monetization.initialize();
      game = GameState();
      await game.startNewGame('Seiran FC');
      game.save!.firstRunGuideDismissed = true;
      if (arrange != null) await arrange(game);
    });
    addTearDown(() => Tr.language = AppLanguage.system);
    const app = SoccerManagerApp();
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<GameState>.value(value: game),
        ChangeNotifierProvider<SettingsController>.value(value: settings),
        ChangeNotifierProvider<MonetizationController>.value(
            value: monetization),
      ],
      child: MaterialApp(
        locale: Locale(en ? 'en' : 'ja'),
        theme: app.buildTheme(Brightness.light, boldText: false),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => LandscapeScale(
          child: FmThemeScope(
            dark: app.buildTheme(Brightness.dark, boldText: false),
            child: child!,
          ),
        ),
        home: const MainShell(),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    return game;
  }

  ShellNav navOf(WidgetTester tester) => ShellNav.maybeOf(
      tester.element(find.byType(HomeScreen, skipOffstage: false)))!;

  List<TodoItem> todosOf(WidgetTester tester) =>
      tester.widget<TodoScope>(find.byType(TodoScope)).items;

  /// 画面が重なっていない(シェルの上に何も積まれていない)。
  void expectNothingPushed(WidgetTester tester) {
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    expect(navigator.canPop(), isFalse, reason: '画面が重ねて開かれている');
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> addOffers(GameState gs, int n) async {
    final other =
        gs.save!.league.teams.firstWhere((t) => t.id != gs.userTeam.id);
    gs.save!.incomingOffers = [
      for (var i = 0; i < n; i++)
        IncomingOffer(
          id: 'o$i',
          playerId: gs.userTeam.players[i].id,
          playerName: gs.userTeam.players[i].name,
          buyerClubName: other.name,
          amount: 500,
        ),
    ];
  }

  testWidgets('状況の右の欄: 見出しの件数は一覧と同じ。今週の決断の札は無い', (tester) async {
    await pumpShell(tester);
    final items = todosOf(tester);
    expect(items.mustCount, greaterThan(0));
    expect(items.recommendedCount, greaterThan(0));
    expect(
        find.text('やること  必須${items.mustCount}・おすすめ${items.recommendedCount}'),
        findsOneWidget);
    // スポンサー未契約は、必須の行として出る(以前は別の札)。
    expect(find.byKey(const ValueKey('todo-sponsor')), findsOneWidget);
    expect(find.text('スポンサー未契約'), findsNothing);
    expect(find.text('今週の決断'), findsNothing);
    // おすすめが多いときは、上の数件と「ほか N件」。
    final rec = items.recommended.toList();
    expect(rec.length, greaterThan(TodoRecommendedList.foldAt + 1));
    expect(
        find.descendant(
            of: find.byType(TodoRecommendedList),
            matching: find.byType(TodoRow)),
        findsNWidgets(TodoRecommendedList.foldAt));
    final more = find.byKey(const ValueKey('todo-more'));
    expect(find.text('ほか ${rec.length - TodoRecommendedList.foldAt}件'),
        findsOneWidget);
    await tester.ensureVisible(more);
    await tester.pump();
    await tester.tap(more);
    await tester.pump();
    expect(
        find.descendant(
            of: find.byType(TodoRecommendedList),
            matching: find.byType(TodoRow, skipOffstage: false),
            skipOffstage: false),
        findsNWidgets(rec.length));
  });

  testWidgets('何も無いときは1行だけ', (tester) async {
    await pumpShell(tester, arrange: (gs) async {
      // 「やること」が0件になるまで片付ける。
      final s = gs.save!;
      await gs.playNextMatchdayQuickSim();
      if (gs.pendingOwnerEvent != null) await gs.resolveOwnerEvent(0);
      if (s.sponsorDeal == null && s.pendingSponsorOffers.isNotEmpty) {
        await gs.chooseSponsor(0);
      }
      s.pendingSponsorOffers = [];
      s.pendingNamingOffers = [];
      s.slotSponsorOffers.clear();
      s.pendingRumor = null;
      s.agmDemand = null;
      s.pendingBoardReviewMessage = null;
      s.incomingOffers = [];
      s.proposals.clear();
      s.youthProspects.clear();
      s.pendingYouthIntake = [];
      for (final p in gs.userTeam.players) {
        p.contractYearsRemaining = 3;
      }
      await gs.setOwnerGoal(gs.selectableOwnerGoals.first);
      for (final r in StaffRole.values) {
        final c = gs.staffCandidatesFor(r);
        if (s.infrastructure.staffFor(r) == null && c.isNotEmpty) {
          s.infrastructure.staff[r] = c.first;
        }
      }
      s.staffCandidates.clear();
      // 移籍の窓が閉じるまで進める(締切の知らせを外す)。
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
    });
    final items = todosOf(tester);
    expect(items, isEmpty, reason: items.map((t) => t.kind.name).join(', '));
    expect(find.byKey(const ValueKey('todo-empty')), findsOneWidget);
    expect(find.text('やること'), findsOneWidget);
    // 必須が無いので、進むボタンに件数の札は付かない。
    expect(find.byKey(const ValueKey('advance-todo')), findsNothing);
  });

  testWidgets('行を押すと、左メニューとタブが切り替わる(画面を重ねない)', (tester) async {
    await pumpShell(tester);
    final nav = navOf(tester);
    expect(nav.menu, TodoMenu.status);
    // スポンサー → 経営の「資金・取引」。
    await tester.tap(find.byKey(const ValueKey('todo-sponsor')));
    await settle(tester);
    expect(nav.menu, TodoMenu.finance);
    expect(nav.tabOf(TodoMenu.finance), TodoPlaces.financeFunding.tab);
    expectNothingPushed(tester);
    expect(find.text('スポンサー契約').hitTestable(), findsOneWidget);
    expect(find.byType(HomeScreen).hitTestable(), findsNothing);
  });

  testWidgets('行き先の番号は、実際のタブの並びと合っている', (tester) async {
    final gs = await pumpShell(tester, arrange: (gs) async {
      final p = gs.userTeam.players.first;
      gs.save!.proposals.add(ManagerProposal(
          kind: ProposalKind.renew, playerId: p.id, playerName: p.name));
    });
    final nav = navOf(tester);
    final checks = <(TodoPlace, Finder)>[
      (TodoPlaces.financeOverview, find.byType(ProposalCard)),
      (TodoPlaces.financeFunding, find.text('スポンサー契約')),
      (TodoPlaces.financeProjects, find.byType(ClubPolicyCard)),
      (TodoPlaces.clubStaff, find.textContaining('スタッフ: ')),
      (TodoPlaces.clubFacilities, find.text('施設')),
      (TodoPlaces.clubCommunity, find.byType(SeasonTicketsCard)),
      (TodoPlaces.clubYouth, find.byType(YouthScreen)),
      (TodoPlaces.squadContracts, find.byType(ContractBoardScreen)),
      (TodoPlaces.transferPicks, find.textContaining('スカッド ')),
      (TodoPlaces.transferTalks, find.textContaining('交渉')),
      (TodoPlaces.transferOffers, find.textContaining('オファー')),
      (TodoPlaces.leagueCups, find.byType(CupScreen)),
      (TodoPlaces.ownerMatchday, find.textContaining('試合日のイベント')),
      (TodoPlaces.ownerFans, find.text('ファン感謝祭')),
      (TodoPlaces.ownerWorks, find.byType(OwnerWorkScreen)),
      (TodoPlaces.status, find.byType(HomeScreen)),
    ];
    for (final (place, finder) in checks) {
      nav.go(place);
      await settle(tester);
      expect(nav.menu, place.menu);
      expect(finder.hitTestable(), findsWidgets, reason: '$place');
      expectNothingPushed(tester);
    }
    // オーナーの仕事の「打てる手」は、広報以外の分野の札を開く。
    nav.go(TodoPlaces.ownerWorks);
    await settle(tester);
    final fans = OwnerWorkCategory.values.indexOf(OwnerWorkCategory.fans) + 1;
    final chips = tester
        .widgetList<ChoiceChip>(find.byType(ChoiceChip).hitTestable())
        .toList();
    final selected = chips.indexWhere((c) => c.selected);
    expect(selected, greaterThan(0));
    expect(selected, isNot(fans));
    expect(gs.save, isNotNull);
  });

  testWidgets('用件のある場所を開けば、その用件が見つかる(経営の概要・移籍のオファー)', (tester) async {
    await pumpShell(tester, arrange: (gs) async {
      final p = gs.userTeam.players.first;
      gs.save!.proposals.add(ManagerProposal(
          kind: ProposalKind.renew, playerId: p.id, playerName: p.name));
      await addOffers(gs, 2);
    });
    final items = todosOf(tester);
    final nav = navOf(tester);
    // 監督からの提案(おすすめ) → 経営の概要に承認のボタン。
    final proposals =
        items.firstWhere((t) => t.kind == TodoKind.managerProposals);
    expect(items.recommendedAt(TodoMenu.finance, proposals.place.tab),
        greaterThan(0));
    nav.go(proposals.place);
    await settle(tester);
    expect(find.text('承認').hitTestable(), findsWidgets);
    // 届いたオファー(必須) → 移籍のオファーのタブに、同じ選手が出ている。
    expect(items.mustAt(TodoMenu.transfer, TodoPlaces.transferOffers.tab), 2);
    nav.go(TodoPlaces.transferOffers);
    await settle(tester);
    expect(find.textContaining('オファー (2)').hitTestable(), findsOneWidget);
    expectNothingPushed(tester);
  });

  testWidgets('事件の印は状況に付く(オーナー室には付かない)。札は状況に出る', (tester) async {
    await pumpShell(tester, arrange: (gs) async {
      gs.save!.pendingOwnerEvent = OwnerEventKind.sponsorExit;
      await addOffers(gs, 2);
    });
    final items = todosOf(tester);
    expect(items.any((t) => t.kind == TodoKind.ownerEvent), isTrue);
    expect(find.byType(OwnerEventCard), findsOneWidget);

    Finder mustMark(String key) => find.descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.byKey(const ValueKey('todo-mark-must')));
    String numberIn(Finder mark) => tester
        .widget<Text>(find.descendant(of: mark, matching: find.byType(Text)))
        .data!;

    // 状況: 必須の合計。
    expect(numberIn(mustMark('menu-mark-status')), '${items.mustCount}');
    // オーナー室: 赤い印は無い(おすすめの青い点は付いてよい)。
    expect(mustMark('menu-mark-ownerRoom'), findsNothing);
    // 移籍: 届いたオファー2件。
    expect(numberIn(mustMark('menu-mark-transfer')), '2');
    // 左メニューの印は、一覧から数えた数と同じ。
    for (final menu in TodoMenu.values) {
      final must = items.mustAt(menu);
      final rec = items.recommendedAt(menu);
      final key = 'menu-mark-${menu.name}';
      if (must > 0) {
        expect(numberIn(mustMark(key)), '$must', reason: key);
      } else if (rec > 0) {
        expect(
            find.descendant(
                of: find.byKey(ValueKey(key)),
                matching: find.byKey(const ValueKey('todo-mark-recommended'))),
            findsOneWidget,
            reason: key);
      } else {
        expect(find.byKey(ValueKey(key)), findsNothing, reason: key);
      }
    }
    // タブの印: 移籍のオファーのタブ(3番目)に赤い2。
    navOf(tester).go(TodoPlaces.transferPicks);
    await settle(tester);
    expect(
        numberIn(find.descendant(
            of: find.byKey(const ValueKey('tab-mark-3')).hitTestable(),
            matching: find.byKey(const ValueKey('todo-mark-must')))),
        '2');
    // タブの印: クラブのスタッフ(0番目)に、空席のおすすめの青い点。
    navOf(tester).go(TodoPlaces.clubFacilities);
    await settle(tester);
    expect(items.recommendedAt(TodoMenu.club, 0), greaterThan(0));
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('tab-mark-club-0')),
            matching: find.byKey(const ValueKey('todo-mark-recommended'))),
        findsOneWidget);
  });

  for (final en in [false, true]) {
    testWidgets('進むボタン: 行き先を動詞つきで書き、必須の件数の札を出す(${en ? '英語' : '日本語'})',
        (tester) async {
      final gs = await pumpShell(tester, en: en);
      final items = todosOf(tester);
      final button = find.byKey(const ValueKey('advance-button'));
      // 状況の札の側の進むボタンは、横画面では出さない(上の帯の1つだけ)。
      expect(button, findsOneWidget);
      final label = tester
          .widget<Text>(
              find.descendant(of: button, matching: find.byType(Text)))
          .data!;
      final stop = gs.nextStop!;
      if (stop.kind.isMatch) {
        expect(label, startsWith(en ? 'Next match' : '次の試合へ'));
      } else {
        expect(label,
            en ? startsWith('Skip to ') : contains('${stop.buttonLabel}まで進む'));
      }
      // 以前の「7/31(金) 給料日」の形(日付が先・動詞なし)ではない。
      expect(label, isNot(startsWith('7/')));
      // 字は切れていない(帯の幅に収まっている)。
      final para = tester.renderObject<RenderParagraph>(
          find.descendant(of: button, matching: find.byType(RichText)).last);
      expect(para.didExceedMaxLines, isFalse, reason: label);
      // 必須が残っているので、件数の札が左に付く。ボタンは押せるまま。
      expect(items.mustCount, greaterThan(0));
      final tag = find.byKey(const ValueKey('advance-todo'));
      expect(tag, findsOneWidget);
      expect(
          find.descendant(
              of: tag,
              // スマホの幅では数字だけ(日付と節の字を残すため)。読み上げと
              // 広い画面では「やること N件」。
              matching:
                  find.text(en ? '${items.mustCount}' : '${items.mustCount}件')),
          findsOneWidget);
      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
      // 札を押すと、どのページからでも一覧(状況)へ戻る。
      final nav = navOf(tester);
      nav.go(TodoPlaces.clubFacilities);
      await settle(tester);
      await tester.tap(tag);
      await settle(tester);
      expect(nav.menu, TodoMenu.status);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('必須が残っていても、進むボタンは進める(止めない)', (tester) async {
    final gs = await pumpShell(tester);
    expect(todosOf(tester).mustCount, greaterThan(0));
    final before = gs.today;
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('advance-button')));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(gs.today.isAfter(before), isTrue);
  });

  testWidgets('押せない理由: 答えを待つものがあると「決めることが出るまで進む」は押せず、理由が出る', (tester) async {
    await pumpShell(tester);
    final b = find.byKey(const ValueKey('advance-to-decision'));
    // 右の欄(2つ目の一覧)を、ボタンが出るまで送る。
    final right = find
        .descendant(
            of: find.byKey(const ValueKey('two-pane-right')),
            matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(b, 200, scrollable: right);
    await tester.pump();
    expect(tester.widget<OutlinedButton>(b).onPressed, isNull);
    expect(
        find.descendant(
            of: find.byType(DisabledReason),
            matching: find.textContaining('答えを待つものがあります')),
        findsOneWidget);
  });

  testWidgets('縦画面では、行を押すと今までどおり画面を重ねて開く', (tester) async {
    await pumpShell(tester, size: const Size(390, 844));
    final row = find.byKey(const ValueKey('todo-sponsor'));
    await tester.ensureVisible(row);
    await tester.pump();
    await tester.tap(row);
    await settle(tester);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    expect(navigator.canPop(), isTrue);
    // 「資金・取引」のタブが開いている。
    expect(find.text('スポンサー契約').hitTestable(), findsOneWidget);
  });
}
