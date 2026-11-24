// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/data/glossary_entries.dart';
import 'package:soccer_manager/data/guide_sections.dart';
import 'package:soccer_manager/l10n/app_localizations.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/logic/economy_scale.dart';
import 'package:soccer_manager/logic/manager_report_engine.dart';
import 'package:soccer_manager/logic/sponsor_slots.dart';
import 'package:soccer_manager/main.dart';
import 'package:soccer_manager/models/club_infrastructure.dart';
import 'package:soccer_manager/models/sponsor.dart';
import 'package:soccer_manager/models/staff_offer.dart';
import 'package:soccer_manager/monetization/ad_service.dart';
import 'package:soccer_manager/monetization/funds_pack.dart';
import 'package:soccer_manager/monetization/monetization_controller.dart';
import 'package:soccer_manager/monetization/purchase_service.dart';
import 'package:soccer_manager/screens/club_screen.dart';
import 'package:soccer_manager/screens/finance_screen.dart';
import 'package:soccer_manager/screens/main_shell.dart';
import 'package:soccer_manager/state/game_state.dart';
import 'package:soccer_manager/state/settings_controller.dart';
import 'package:soccer_manager/widgets/fm_panel.dart';
import 'package:soccer_manager/widgets/group_page.dart';
import 'package:soccer_manager/widgets/landscape_scale.dart';
import 'package:soccer_manager/widgets/media_deals_card.dart';
import 'package:soccer_manager/widgets/notch_side_insets.dart';
import 'package:soccer_manager/widgets/sponsor_slots_card.dart';

import 'support/app_fonts.dart';

/// 品質改善の10回目(2026-11-23): 画面に出る額・割合・文が、実際に計算に
/// 使われる値や今の仕組みと食い違っていた所。
void main() {
  setUpAll(loadAppFonts);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Tr.language = AppLanguage.japanese;
  });
  tearDown(() => Tr.language = AppLanguage.system);

  Future<GameState> newGame(WidgetTester? tester,
      [String name = '十回目FC']) async {
    late final GameState gs;
    Future<void> make() async {
      gs = GameState();
      await gs.startNewGame(name);
    }

    if (tester == null) {
      await make();
    } else {
      await tester.runAsync(make);
    }
    return gs;
  }

  Future<void> pumpScreen(WidgetTester tester, GameState gs, Widget home,
      {Size size = const Size(1600, 1200), bool en = false}) async {
    late final SettingsController settings;
    late final MonetizationController monetization;
    await tester.runAsync(() async {
      settings = SettingsController();
      await settings.init();
      monetization = MonetizationController(
          adService: NoOpAdService(), purchases: _NoStore());
      await monetization.initialize();
    });
    Tr.language = en ? AppLanguage.english : AppLanguage.japanese;
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<GameState>.value(value: gs),
        ChangeNotifierProvider<SettingsController>.value(value: settings),
        ChangeNotifierProvider<MonetizationController>.value(
            value: monetization),
      ],
      child: MaterialApp(
        locale: Locale(en ? 'en' : 'ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    ));
    await tester.pump();
  }

  /// ファンの需要を変えて、観客収入が上限に届く/届かない状態を作る。
  void setDemand(GameState gs, int demand) {
    gs.save!.fanDemand = demand;
    gs.save!.infrastructure.facilityLevels[FacilityType.stadium] = 8;
  }

  group('1 商業施設は、上限に届いた観客収入を増やさない', () {
    test('「上限に届いている」なら1段上げても観客収入は同じ、届いていなければ増える', () async {
      final gs = await newGame(null);
      final infra = gs.save!.infrastructure;
      final seen = <bool>{};
      for (final demand in [600, 3000, 12000, 30000, 60000, 120000]) {
        setDemand(gs, demand);
        infra.facilityLevels[FacilityType.commercialFacility] = 3;
        final atCap = gs.isGateAtCap;
        final before = gs.weeklyIncomeParts(gs.save!.userTeamId);
        infra.facilityLevels[FacilityType.commercialFacility] = 4;
        final after = gs.weeklyIncomeParts(gs.save!.userTeamId);
        seen.add(atCap);
        if (atCap) {
          expect(after.gate, before.gate, reason: 'demand $demand');
        } else {
          expect(after.gate, greaterThan(before.gate),
              reason: 'demand $demand');
        }
        // スポンサー・グッズはいつでも伸びる(グッズにも掛かっている)。
        expect(after.merchandise, greaterThan(before.merchandise));
      }
      expect(seen, {true, false}, reason: '両方の場合を試せていない');
    });

    testWidgets('施設の画面は、上限に届いていれば「増えません」と書く', (tester) async {
      final gs = await newGame(tester);
      setDemand(gs, 600);
      expect(gs.isGateAtCap, isTrue);
      await pumpScreen(
          tester, gs, const ClubScreen(section: ClubSection.facilities));
      expect(find.textContaining('いま: スポンサー・グッズ収入'), findsOneWidget);
      expect(
          find.textContaining('上限(入る人数×1人の単価)に届いているので増えません'), findsOneWidget);
      // 以前の「観客・スポンサー収入+X%」は出さない。
      expect(find.textContaining('観客・スポンサー収入'), findsNothing);
    });

    testWidgets('届いていなければ「観客収入にも同じだけ効きます」', (tester) async {
      final gs = await newGame(tester);
      setDemand(gs, 120000);
      expect(gs.isGateAtCap, isFalse);
      await pumpScreen(
          tester, gs, const ClubScreen(section: ClubSection.facilities));
      expect(find.textContaining('観客収入にも同じだけ効きます'), findsOneWidget);
      expect(find.textContaining('増えません'), findsNothing);
    });

    test('施設の説明・ガイドも、グッズと上限のことを書く', () {
      expect(FacilityType.commercialFacility.description, contains('グッズ'));
      expect(FacilityType.commercialFacility.description, contains('上限'));
      final topics = [
        for (final s in guideSections) ...s.topics,
      ];
      final commercial = topics.firstWhere((t) => t.title == '商業施設');
      expect(commercial.description, contains('上限'));
    });
  });

  group('2 経営の画面とホームの収支は同じ数', () {
    test('支出は人件費・運営費・返済で、収入−支出が収支になる', () async {
      final gs = await newGame(null);
      final md = gs.matchdaysPerSeason;
      expect(gs.matchdayRunningCost, greaterThan(0));
      final wages = (gs.matchdayPlayerWageCost + gs.matchdayStaffWageCost) * md;
      expect(gs.annualExpenseForecast, wages + gs.matchdayRunningCost * md,
          reason: '借入れが無いときは人件費+運営費');
      expect(gs.annualNetForecast,
          gs.projectedMatchdayIncome * md - gs.annualExpenseForecast);
    });

    test('ホームの報告の行は「1年の収支」(週ではない)', () {
      final r = ManagerReportEngine.build(
        rank: 3,
        teamCount: 20,
        tier: 1,
        supporter: 50,
        shareholder: 50,
        budget: 1000,
        weeklyNet: 120,
      );
      expect(r.lines.any((l) => l.contains('1年の収支')), isTrue);
      expect(r.lines.any((l) => l.contains('週の収支')), isFalse);
    });

    testWidgets('経営の画面の「支出」は運営費を含み、収入−支出=収支', (tester) async {
      final gs = await newGame(tester);
      await pumpScreen(tester, gs, const FinanceScreenHost());
      final md = gs.matchdaysPerSeason;
      final income = gs.projectedMatchdayIncome * md;
      expect(find.text('人件費・運営費'), findsOneWidget);
      expect(find.text('-${formatMoney(gs.annualExpenseForecast)}'),
          findsOneWidget);
      final net = gs.annualNetForecast;
      expect(income - gs.annualExpenseForecast, net);
      expect(
          find.text('${net >= 0 ? '+' : ''}${formatMoney(net)}'), findsWidgets);
    });
  });

  group('3 枠のスポンサー・命名権の額は胸のスポンサーと同じく1年あたり', () {
    testWidgets('札は「年X」(1節の額 × 節の数)で、「週」と書かない', (tester) async {
      final gs = await newGame(tester);
      final s = gs.save!;
      final md = gs.matchdaysPerSeason;
      s.slotSponsors[SponsorSlot.sleeve.name] =
          SponsorDeal(name: '袖社', weeklyIncome: 7, yearsRemaining: 2);
      s.slotSponsorOffers[SponsorSlot.back.name] =
          SponsorDeal(name: '背中社', weeklyIncome: 5, yearsRemaining: 1);
      s.namingDeal =
          SponsorDeal(name: '命名社', weeklyIncome: 11, yearsRemaining: 3);
      await pumpScreen(
          tester,
          gs,
          const Scaffold(
              body: SingleChildScrollView(
                  child: Column(
                      children: [SponsorSlotsCard(), MediaDealsCard()]))));
      expect(find.textContaining('年${formatMoney(7 * md)}'), findsOneWidget);
      expect(find.textContaining('年${formatMoney(5 * md)}'), findsOneWidget);
      expect(find.textContaining('年${formatMoney(11 * md)}'), findsOneWidget);
      expect(find.textContaining(RegExp(r'・週')), findsNothing);
    });

    testWidgets('英語では「a year」と年数の単数・複数', (tester) async {
      final gs = await newGame(tester);
      final s = gs.save!;
      s.slotSponsors[SponsorSlot.sleeve.name] =
          SponsorDeal(name: 'Sleeve Co', weeklyIncome: 7, yearsRemaining: 1);
      await pumpScreen(
          tester,
          gs,
          const Scaffold(
              body: SingleChildScrollView(child: SponsorSlotsCard())),
          en: true);
      expect(find.textContaining('a year, 1 year left'), findsOneWidget);
      expect(find.textContaining('/week'), findsNothing);
    });

    test('結んだときの知らせも1年あたり', () async {
      final gs = await newGame(null);
      final s = gs.save!;
      final md = gs.matchdaysPerSeason;
      s.slotSponsorOffers[SponsorSlot.sleeve.name] =
          SponsorDeal(name: '袖社', weeklyIncome: 7, yearsRemaining: 2);
      expect(await gs.signSlotSponsor(SponsorSlot.sleeve), isTrue);
      expect(s.newsLog.first.text, contains('年${formatMoney(7 * md)}'));
      s.pendingNamingOffers = [
        SponsorDeal(name: '命名社', weeklyIncome: 11, yearsRemaining: 3),
      ];
      expect(await gs.chooseNamingRights(0), isTrue);
      expect(s.newsLog.first.text, contains('年${formatMoney(11 * md)}'));
    });

    test('締切で自動で結んだときの知らせも1年あたり', () async {
      final gs = await newGame(null);
      final s = gs.save!;
      final md = gs.matchdaysPerSeason;
      s.sponsorDeal = null;
      s.pendingSponsorOffers = [
        SponsorDeal(name: 'A社', weeklyIncome: 10, yearsRemaining: 2),
      ];
      for (var i = 0; i < GameStateDecisions.decisionDeadlineMatchdays; i++) {
        await gs.debugTickDecisionDeadlines();
      }
      expect(gs.lastAutoDecisions.single, contains('年${formatMoney(10 * md)}'));
      expect(gs.lastAutoDecisions.single, isNot(contains('(週')));
    });
  });

  group('4 用語集・ガイドが今の仕組みと合う', () {
    String glossary(String term) =>
        glossaryEntries.firstWhere((e) => e.term == term).description;

    test('セットプレーの担当は監督が決める', () {
      expect(glossary('守備セットプレー担当'), contains('監督が毎節'));
      expect(glossary('監督が決める戦い方'), contains('セットプレーの担当'));
    });

    test('給与予算は補強の配分と方針でも動く', () {
      expect(glossary('給与予算'), contains('補強の配分'));
      expect(glossary('給与予算'), contains('方針'));
    });

    test('ガイドの施設: 工期・建て方・メディカルセンターがある', () {
      final topics = [
        for (final s in guideSections) ...s.topics,
      ];
      final build = topics.firstWhere((t) => t.title == '建て方と工期');
      expect(build.description,
          contains('${ClubInfrastructure.stadiumSeatsPerLevel}席'));
      expect(build.description, contains('来季の開幕'));
      expect(
          build.description, contains('${ClubInfrastructure.buildMonths}か月'));
      expect(topics.any((t) => t.title == 'メディカルセンター'), isTrue);
      final youth = topics.firstWhere((t) => t.title == 'ユース施設');
      expect(youth.description, contains('受け入れ枠'));
    });

    test('ガイドの経営: 運営費とグッズ・放映権を書き、スポンサーは毎節', () {
      final finance =
          guideSections.firstWhere((s) => s.title == 'クラブ経営(ファイナンス)画面');
      expect(finance.overview, contains('運営費'));
      final sponsor = finance.topics.firstWhere((t) => t.title == 'スポンサー契約');
      expect(sponsor.description, contains('毎節'));
    });
  });

  group('5 スタッフの引き抜き: 残すと契約も1年延びる', () {
    testWidgets('ボタンに「契約+1年」と書く', (tester) async {
      final gs = await newGame(tester);
      final st = gs.save!.staffCandidates
          .firstWhere((c) => c.role != StaffRole.manager);
      gs.save!.staffCandidates.remove(st);
      gs.save!.infrastructure.staff[st.role] = st;
      gs.save!.staffOffers.add(StaffOffer(
        id: 'o1',
        role: st.role,
        staffId: st.id,
        staffName: st.name,
        clubId: 'x',
        clubName: '大きいFC',
        compensation: 100,
        raisePercent: GameStateStaffMoves.staffKeepRaisePercent,
        expiresOn: gs.today.add(const Duration(days: 14)),
      ));
      await pumpScreen(
          tester, gs, const ClubScreen(section: ClubSection.staff));
      expect(
          find.text(
              '昇給(+${GameStateStaffMoves.staffKeepRaisePercent}%)・契約+1年で残す'),
          findsOneWidget);
      final years = st.contractYears;
      await tester.runAsync(() => gs.keepStaffWithRaise('o1'));
      expect(st.contractYears, years + 1);
    });
  });

  group('6 小さい横画面(iPhone SE 相当 667x375)で、どのページもはみ出さない', () {
    for (final en in [false, true]) {
      testWidgets('SE landscape ${en ? 'en' : 'ja'}', (tester) async {
        addTearDown(tester.view.reset);
        tester.view.devicePixelRatio = 2;
        tester.view.physicalSize = const Size(667, 375) * 2;
        late final SettingsController settings;
        late final MonetizationController monetization;
        late final GameState game;
        await tester.runAsync(() async {
          settings = SettingsController();
          await settings.init();
          Tr.language = en ? AppLanguage.english : AppLanguage.japanese;
          monetization = MonetizationController(
              adService: NoOpAdService(), purchases: _NoStore());
          await monetization.initialize();
          game = GameState();
          await game.startNewGame('Seiran FC');
          game.save!.firstRunGuideDismissed = true;
        });
        final problems = <String>[];
        var where = '';
        final old = FlutterError.onError;
        FlutterError.onError = (d) {
          final at = RegExp(r'lib/[\w/]+\.dart:\d+')
              .allMatches(d.toString())
              .map((m) => m.group(0))
              .toSet()
              .take(3)
              .join(', ');
          problems
              .add('$where: ${d.exceptionAsString().split('\n').first} [$at]');
        };
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
                child: NotchSideInsets(child: child!),
              ),
            ),
            home: const MainShell(),
          ),
        ));
        await tester.pump();
        final pages = en
            ? [
                'Status',
                'Finance',
                'Club',
                'Players',
                'Transfers',
                'League',
                'Office'
              ]
            : ['状況', '経営', 'クラブ', '選手', '移籍', 'リーグ', 'オーナー室'];
        for (final p in pages) {
          where = p;
          final f = find.text(p).hitTestable();
          if (f.evaluate().isEmpty) {
            problems.add('sidebar item $p is not reachable');
            continue;
          }
          await tester.tap(f.first);
          await tester.pump(const Duration(milliseconds: 300));
          final labels = <String>[
            for (final e in find
                .descendant(
                    of: find.byType(GroupPage), matching: find.byType(InkWell))
                .hitTestable()
                .evaluate())
              for (final t in find
                  .descendant(
                      of: find.byWidget(e.widget), matching: find.byType(Text))
                  .evaluate())
                (t.widget as Text).data ?? '',
            for (final e in find.byType(Tab).hitTestable().evaluate())
              (e.widget as Tab).text ?? '',
          ]..removeWhere((s) => s.isEmpty);
          for (final l in labels) {
            where = '$p/$l';
            final tf = find.text(l).hitTestable();
            if (tf.evaluate().isEmpty) continue;
            await tester.tap(tf.first, warnIfMissed: false);
            await tester.pump(const Duration(milliseconds: 300));
            // 字の中には、押すと別の画面を重ねて開くもの(リーグの個人成績の
            // クラブ名・選手名。2026-11-25 の第5段から)がある。ここで見るのは
            // タブだけなので、重なった画面は閉じて左メニューに戻る。閉じないと
            // 次のページの左メニューが隠れて「not reachable」になっていた。
            final navigator =
                tester.state<NavigatorState>(find.byType(Navigator).first);
            if (navigator.canPop()) {
              navigator.pop();
              await tester.pump(const Duration(milliseconds: 600));
            }
          }
        }
        FlutterError.onError = old;
        expect(problems, isEmpty, reason: problems.toSet().join('\n'));
      });
    }
  });
}

/// 経営の画面を単独で開く(下タブの外。戻るボタンつき)。
class FinanceScreenHost extends StatelessWidget {
  const FinanceScreenHost({super.key});

  @override
  Widget build(BuildContext context) => const FinanceScreen();
}

class _NoStore implements PurchaseService {
  @override
  set onDelivered(
      Future<void> Function(String productId, String? purchaseId)? cb) {}

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<String?> priceLabel() async => null;

  @override
  Future<PurchaseOutcome> buySupporter() async => PurchaseOutcome.unavailable;

  @override
  Future<String?> priceLabelFor(FundsPack pack) async => null;

  @override
  Future<PurchaseOutcome> buyFundsPack(FundsPack pack) async =>
      PurchaseOutcome.unavailable;

  @override
  Future<PurchaseOutcome> restorePurchases() async =>
      PurchaseOutcome.unavailable;

  @override
  void dispose() {}
}
