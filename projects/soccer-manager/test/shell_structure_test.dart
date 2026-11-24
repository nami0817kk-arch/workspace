// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_manager/data/quick_access_destinations.dart';
import 'package:soccer_manager/logic/proposal_engine.dart';
import 'package:soccer_manager/logic/todo_advisor.dart';
import 'package:soccer_manager/screens/contract_board_screen.dart';
import 'package:soccer_manager/screens/cup_screen.dart';
import 'package:soccer_manager/screens/finance_screen.dart';
import 'package:soccer_manager/screens/fixtures_screen.dart';
import 'package:soccer_manager/screens/main_shell.dart';
import 'package:soccer_manager/screens/owner_work_screen.dart';
import 'package:soccer_manager/screens/owner_world_screen.dart';
import 'package:soccer_manager/screens/reference_screens.dart';
import 'package:soccer_manager/screens/squad_screen.dart';
import 'package:soccer_manager/screens/transfer_screen.dart';
import 'package:soccer_manager/screens/youth_screen.dart';
import 'package:soccer_manager/widgets/advisor_card.dart';
import 'package:soccer_manager/widgets/affiliate_card.dart';
import 'package:soccer_manager/widgets/budget_plan_card.dart';
import 'package:soccer_manager/widgets/club_culture_card.dart';
import 'package:soccer_manager/widgets/club_license_card.dart';
import 'package:soccer_manager/widgets/club_look_card.dart';
import 'package:soccer_manager/widgets/club_policy_card.dart';
import 'package:soccer_manager/widgets/club_value_card.dart';
import 'package:soccer_manager/widgets/community_card.dart';
import 'package:soccer_manager/widgets/economy_card.dart';
import 'package:soccer_manager/widgets/equity_card.dart';
import 'package:soccer_manager/widgets/era_card.dart';
import 'package:soccer_manager/widgets/fan_segments_card.dart';
import 'package:soccer_manager/widgets/group_page.dart';
import 'package:soccer_manager/widgets/landscape_scale.dart';
import 'package:soccer_manager/widgets/ledger_card.dart';
import 'package:soccer_manager/widgets/media_deals_card.dart';
import 'package:soccer_manager/widgets/owner_career_card.dart';
import 'package:soccer_manager/widgets/owner_wealth_card.dart';
import 'package:soccer_manager/widgets/project_card.dart';
import 'package:soccer_manager/widgets/proposal_card.dart';
import 'package:soccer_manager/widgets/reward_funds_card.dart';
import 'package:soccer_manager/widgets/risk_card.dart';
import 'package:soccer_manager/widgets/rival_owners_card.dart';
import 'package:soccer_manager/widgets/rules_card.dart';
import 'package:soccer_manager/widgets/season_tickets_card.dart';
import 'package:soccer_manager/widgets/sponsor_slots_card.dart';

import 'support/app_fonts.dart';
import 'support/shell_harness.dart';

/// 横画面のシェルの形(左メニュー → タブ → 節)を固定する。
///
/// 2026-11-24 に、28 あったタブを 16 にまとめ、見るだけの画面を ≡ の
/// 「資料」へ移した。
/// - タブの数(左メニューごと・合計)が戻らないこと
/// - まとめる前にあった操作が、どれも新しい場所に残っていること
///   (操作を消さず、場所だけを変えた)
/// - 資料へ移した画面が、≡ から開けること
void main() {
  setUpAll(loadAppFonts);

  /// いま開いている左メニューの項目のタブの数。
  int tabCount(WidgetTester tester) {
    final group = find.byType(GroupPage).hitTestable();
    if (group.evaluate().isNotEmpty) {
      return tester.widget<GroupPage>(group.first).tabs.length;
    }
    return find.byType(Tab).hitTestable().evaluate().length;
  }

  testWidgets('左メニューは8項目、タブは 0・0・3・4・2・3・2・2、合計16', (tester) async {
    await pumpShell(tester);
    final nav = shellNavOf(tester);
    expect(TodoMenu.values.length, 8);
    const want = {
      TodoMenu.status: 0,
      TodoMenu.calendar: 0,
      TodoMenu.finance: 3,
      TodoMenu.club: 4,
      TodoMenu.squad: 2,
      TodoMenu.transfer: 3,
      TodoMenu.league: 2,
      TodoMenu.ownerRoom: 2,
    };
    var total = 0;
    for (final menu in TodoMenu.values) {
      nav.go(TodoPlace(menu));
      await settleShell(tester);
      final n = tabCount(tester);
      expect(n, want[menu], reason: '${menu.name} のタブの数');
      total += n;
    }
    expect(total, 16);
    expect(FinanceScreen.tabCount, 3);
    expect(TransferScreen.tabCount, 3);
  });

  testWidgets('まとめる前にあった操作は、どれも新しい場所にある', (tester) async {
    await pumpShell(tester, arrange: (gs) async {
      final p = gs.userTeam.players.first;
      gs.save!.proposals.add(ManagerProposal(
          kind: ProposalKind.renew, playerId: p.id, playerName: p.name));
    });
    final nav = shellNavOf(tester);

    Finder type(Type t) => find.byType(t, skipOffstage: false);
    Finder key(String k) => find.byKey(ValueKey(k), skipOffstage: false);
    Finder text(String s) => find.textContaining(s, skipOffstage: false);

    /// 行き先 → (札の番号) → そこに無ければならないもの。
    final checks = <(String, TodoPlace, int?, List<Finder>)>[
      (
        '経営 > 概要',
        TodoPlaces.financeOverview,
        null,
        [
          type(ProposalCard),
          type(RewardFundsCard),
          type(BudgetPlanCard),
        ]
      ),
      (
        '経営 > お金を作る',
        TodoPlaces.financeFunding,
        null,
        [
          text('スポンサー契約'),
          type(SponsorSlotsCard),
          type(MediaDealsCard),
          text('融資を申し込む'),
          text('定期預金を組む'),
          type(EquityCard),
          type(OwnerWealthCard),
          key('finance-to-owner-finance-works'),
        ]
      ),
      (
        '経営 > 方針と投資',
        TodoPlaces.financeProjects,
        null,
        [
          type(ClubPolicyCard),
          type(FiveYearPlanCard),
          type(ProjectCard),
          type(AdvisorCard),
          type(RiskCard),
          type(RulesCard),
          type(EconomyCard),
        ]
      ),
      ('クラブ > スタッフ', TodoPlaces.clubStaff, null, [text('スタッフ: ')]),
      (
        'クラブ > 施設',
        TodoPlaces.clubFacilities,
        null,
        [type(ClubLicenseCard), type(AffiliateCard), text('で増築')]
      ),
      (
        'クラブ > ファンと街',
        TodoPlaces.clubCommunity,
        null,
        [
          type(FanSegmentsCard),
          type(ClubLookCard),
          type(SeasonTicketsCard),
          type(CommunityCard),
          key('community-upgrade'),
          key('club-to-community-works'),
        ]
      ),
      ('クラブ > ユース', TodoPlaces.clubYouth, null, [type(YouthScreen)]),
      ('選手 > スカッド', TodoPlaces.squadList, null, [type(SquadScreen)]),
      (
        '選手 > 登録と契約',
        TodoPlaces.squadContracts,
        null,
        [type(ContractBoardScreen), text('更新の時期の選手')]
      ),
      ('移籍 > 候補 > 監督の補強案', TodoPlaces.transferPicks, 0, [text('スカッド ')]),
      ('移籍 > 候補 > 注目', TodoPlaces.transferPicks, 1, [text('注目している選手')]),
      ('移籍 > 探す > 選手を探す', TodoPlaces.transferSearch, 0, [text('スカッド')]),
      ('移籍 > 探す > フリー', TodoPlaces.transferSearch, 1, [text('年俸だけで取れる選手')]),
      (
        '移籍 > 探す > スカウトの地域',
        TodoPlaces.transferSearch,
        2,
        [type(SwitchListTile)]
      ),
      (
        '移籍 > 交渉とオファー',
        TodoPlaces.transferTalks,
        null,
        [
          key('transfer-offers-tab'),
          text('届いたオファー'),
          text('進んでいる交渉'),
          text('移籍リスト'),
        ]
      ),
      (
        'リーグ > 順位と日程',
        const TodoPlace(TodoMenu.league),
        null,
        [type(FixturesScreen)]
      ),
      ('リーグ > カップ戦', TodoPlaces.leagueCups, null, [type(CupScreen)]),
      (
        'オーナー室 > オーナーの仕事',
        TodoPlaces.ownerMatchday,
        null,
        [type(OwnerWorkScreen), text('試合日のイベント'), key('owner-work-chip-5')]
      ),
      (
        'オーナー室 > オーナーと世界',
        TodoPlaces.ownerWorld,
        null,
        [
          type(OwnerWorldScreen),
          type(ClubCultureCard),
          type(RivalOwnersCard),
          type(EraCard),
        ]
      ),
    ];
    for (final (name, place, chip, finders) in checks) {
      nav.go(place);
      await settleShell(tester);
      if (chip != null) {
        await tester
            .tap(find.byKey(ValueKey('chip-$chip')).hitTestable().first);
        await settleShell(tester);
      }
      for (final f in finders) {
        expect(f, findsWidgets, reason: '$name に $f が無い');
      }
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('入口の行を押すと、同じ用件の正の場所へ移る', (tester) async {
    await pumpShell(tester);
    final nav = shellNavOf(tester);
    // 経営 > お金を作る → オーナーの仕事の「財務・資本」。
    nav.go(TodoPlaces.financeFunding);
    await settleShell(tester);
    final link = find.byKey(const ValueKey('finance-to-owner-finance-works'),
        skipOffstage: false);
    await tester.ensureVisible(link);
    await settleShell(tester);
    await tester.tap(link);
    await settleShell(tester);
    expect(nav.menu, TodoMenu.ownerRoom);
    expect(find.text('社債の発行').hitTestable(), findsOneWidget);
    // クラブ > ファンと街 → オーナーの仕事の「地域・社会」。
    nav.go(TodoPlaces.clubCommunity);
    await settleShell(tester);
    final link2 = find.byKey(const ValueKey('club-to-community-works'),
        skipOffstage: false);
    await tester.ensureVisible(link2);
    await settleShell(tester);
    await tester.tap(link2);
    await settleShell(tester);
    expect(nav.menu, TodoMenu.ownerRoom);
    expect(find.text('学校訪問').hitTestable(), findsOneWidget);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    expect(navigator.canPop(), isFalse);
  });

  testWidgets('≡ の引き出し: 「資料」と「設定とヘルプ」に分かれ、資料の画面が開く', (tester) async {
    await pumpShell(tester);
    await tester.tap(find.byTooltip('資料・設定・ヘルプ'));
    await settleShell(tester);
    expect(
        find.byKey(const ValueKey('drawer-group-reference')), findsOneWidget);
    // 操作する画面は左メニューにあるので、横画面の引き出しには出さない。
    expect(find.byKey(const ValueKey('drawer-group-manage')), findsNothing);
    final drawer = find.byType(Drawer);
    final scroll =
        find.descendant(of: drawer, matching: find.byType(Scrollable)).first;
    // 資料と設定の項目が、全部ある(iPhone 横の高さではスクロールして届く)。
    // 引き出しに並ぶ順(資料 → 設定とヘルプ)に下へ送りながら確かめる。
    final shown = [
      for (final g in [QuickAccessGroup.reference, QuickAccessGroup.help])
        for (final d in quickAccessDestinations)
          if (d.group == g) d,
    ];
    expect(shown.length, greaterThanOrEqualTo(14));
    // 並びの外(下)の項目は、一覧を送ると出てくる。
    final seen = <String>{};
    for (var i = 0; i < 6; i++) {
      for (final d in shown) {
        final item = find.descendant(
            of: drawer,
            matching: find.text(d.label, skipOffstage: false),
            skipOffstage: false);
        if (item.evaluate().isNotEmpty) seen.add(d.label);
      }
      await tester.drag(scroll, const Offset(0, -200));
      await settleShell(tester);
    }
    expect(seen, {for (final d in shown) d.label});
    final position = tester.state<ScrollableState>(scroll).position;
    expect(position.maxScrollExtent, greaterThan(0),
        reason: 'iPhone 横の高さでは、引き出しをスクロールできる');
    await tester.drag(scroll, const Offset(0, 2000));
    await settleShell(tester);
    // 資料の3つの新しい画面。
    for (final (label, t) in <(String, Type)>[
      ('収支の詳しい表', LedgerCard),
      ('クラブの記録', ClubValueCard),
      ('オーナーの記録', OwnerCareerCard),
    ]) {
      final item = find.descendant(of: drawer, matching: find.text(label));
      await tester.scrollUntilVisible(item, -120, scrollable: scroll);
      await tester.tap(item);
      await settleShell(tester);
      expect(find.byType(t, skipOffstage: false), findsWidgets, reason: label);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await settleShell(tester);
      await tester.tap(find.byTooltip('資料・設定・ヘルプ'));
      await settleShell(tester);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('カレンダーは左メニューの2番目。上の帯の日付を押すと切り替わる(重ねない)',
      (tester) async {
    await pumpShell(tester);
    final nav = shellNavOf(tester);
    // 状況のすぐ下に「カレンダー」がある。
    final status = tester.getRect(find.byKey(const ValueKey('menu-item-status')));
    final cal = tester.getRect(find.byKey(const ValueKey('menu-item-calendar')));
    expect(cal.top, closeTo(status.bottom, 0.5));
    expect(find.descendant(
            of: find.byKey(const ValueKey('menu-item-calendar')),
            matching: find.text('カレンダー')),
        findsOneWidget);
    // 上の帯の日付から: 左メニューの項目が切り替わり、画面は重ならない。
    expect(find.byKey(const ValueKey('topbar-calendar-icon')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('topbar-date')));
    await settleShell(tester);
    expect(nav.menu, TodoMenu.calendar);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    expect(navigator.canPop(), isFalse, reason: '重ねて開いていない');
    expect(find.byType(CalendarHubScreen).hitTestable(), findsOneWidget);
    // 見出しの帯(戻るボタン)は出さない。
    expect(find.byType(BackButton).hitTestable(), findsNothing);
    expect(find.text('月').hitTestable(), findsWidgets);
    await tester.tap(find.text('1年の予定').hitTestable());
    await settleShell(tester);
    expect(tester.takeException(), isNull);
    // リーグのタブは今のまま2つ(カレンダーはリーグに入れない)。
    nav.go(const TodoPlace(TodoMenu.league));
    await settleShell(tester);
    expect(find.text('カレンダー').hitTestable(), findsOneWidget,
        reason: '左メニューの項目だけ');
  });

  testWidgets('左メニューの8項目は iPhone 横の高さに 48 のままスクロールなしで入る', (tester) async {
    for (final size in [shellPhone, const Size(667, 375), const Size(1180, 820)]) {
      await pumpShell(tester, size: size);
      final items = [
        for (final m in TodoMenu.values)
          tester.getRect(find.byKey(ValueKey('menu-item-${m.name}'))),
      ];
      // 組むときの大きさ(画面全体は LandscapeScale で縮めて描く)。
      final h = items.first.height / LandscapeScale.scaleFor(size);
      // 押せる高さ 48。左メニューは画面の上から下までを使うので、iPhone 横
      // でも詰めずに入る(上の帯の下に置いていたときは約366しかなかった)。
      expect(h, closeTo(48, 0.01), reason: '$size');
      // 最後の項目まで画面の中にある(スクロールしなくても届く)。
      final screen = tester.getRect(find.byType(MainShell));
      expect(items.last.bottom, lessThanOrEqualTo(screen.bottom + 0.5),
          reason: '$size');
      for (final m in TodoMenu.values) {
        expect(find.byKey(ValueKey('menu-item-${m.name}')).hitTestable(),
            findsOneWidget,
            reason: '$size ${m.name}');
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('上の帯: 日付は切れない(日本語・英語)', (tester) async {
    for (final en in [false, true]) {
      await pumpShell(tester, en: en);
      final date = find.byKey(const ValueKey('topbar-date'));
      final para = tester.renderObject<RenderParagraph>(
          find.descendant(of: date, matching: find.byType(RichText)));
      expect(para.didExceedMaxLines, isFalse);
      final text = tester.widget<Text>(date).data!;
      expect(text, isNot(contains('…')));
      // 帯は日付と節だけ。部と季は出さない(部は状況の順位の札にある)。
      expect(text, en ? contains('MD ') : contains('節'));
      expect(text, en ? isNot(contains('Tier')) : isNot(contains('部')));
      expect(text, en ? isNot(contains('S1')) : isNot(contains('季')));
      // 縮めすぎて読めない大きさになっていない。
      expect(tester.getRect(date).width, greaterThan(60),
          reason: en ? 'en' : 'ja');
      await tester.pumpWidget(const SizedBox());
    }
  });
}
