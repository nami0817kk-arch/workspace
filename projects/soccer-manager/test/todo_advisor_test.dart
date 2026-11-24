// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/logic/agm_engine.dart';
import 'package:soccer_manager/logic/next_action_advisor.dart';
import 'package:soccer_manager/logic/proposal_engine.dart';
import 'package:soccer_manager/logic/season_tickets.dart';
import 'package:soccer_manager/logic/todo_advisor.dart';
import 'package:soccer_manager/models/club_infrastructure.dart';
import 'package:soccer_manager/models/incoming_offer.dart';
import 'package:soccer_manager/models/matchday_promo.dart';
import 'package:soccer_manager/models/owner_event.dart';
import 'package:soccer_manager/models/owner_work.dart';
import 'package:soccer_manager/models/staff_offer.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 「やること」の一覧(TodoAdvisor)の検査。
///
/// 以前は、左メニューの印・状況の「決めること」・「今週の決断」が別々の
/// 条件で数えていて、どこにも出ない用件があった。源を1つにしたので、
/// - 既存の2つ(受信箱の答えを待つもの・今週の決断)が拾うものを全部含む
/// - どこにも出ていなかったものが、条件どおり出る・出ない
/// - いま実行できないおすすめは出さない
/// - 印の件数が一覧と合う
/// を止める。
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Tr.language = AppLanguage.japanese;
  });
  tearDown(() => Tr.language = AppLanguage.system);

  Future<GameState> newGame() async {
    final gs = GameState();
    await gs.startNewGame('やることFC');
    return gs;
  }

  List<TodoItem> build(GameState gs) =>
      TodoAdvisor.build(gs, hasSigningProposals: false);

  TodoItem? find(List<TodoItem> items, TodoKind kind) =>
      items.where((t) => t.kind == kind).firstOrNull;

  /// 開幕した後の、何も起きていないクラブにする(開幕前だけの用件・最初の
  /// 用意を外す)。
  Future<GameState> quietGame() async {
    final gs = await newGame();
    final s = gs.save!;
    s.budget = 1000000;
    // 開幕前の用件が出ないよう、リーグ戦を1節済ませる。
    await gs.playNextMatchdayQuickSim();
    if (gs.pendingOwnerEvent != null) await gs.resolveOwnerEvent(0);
    if (s.pendingSponsorOffers.isNotEmpty && s.sponsorDeal == null) {
      await gs.chooseSponsor(0);
    }
    s.pendingSponsorOffers = [];
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
    return gs;
  }

  group('既存の2つが拾うものを全部含む', () {
    /// 受信箱の種類 → 「やること」の種類。
    const inboxToTodo = {
      InboxKind.ownerEvent: TodoKind.ownerEvent,
      InboxKind.rumor: TodoKind.rumor,
      InboxKind.surgery: TodoKind.surgery,
      InboxKind.agmDemand: TodoKind.agmDemand,
      InboxKind.incomingOffers: TodoKind.incomingOffers,
      InboxKind.counterOffers: TodoKind.counterOffers,
      InboxKind.agreedTalks: TodoKind.agreedTalks,
      InboxKind.staffOffers: TodoKind.staffOffers,
      InboxKind.sponsor: TodoKind.sponsor,
    };

    /// 今週の決断の種類 → 「やること」の種類。
    const actionToTodo = {
      NextActionKind.ultimatum: TodoKind.ultimatum,
      NextActionKind.staffVacant: TodoKind.staffVacant,
      NextActionKind.sponsor: TodoKind.sponsor,
      NextActionKind.ownerGoal: TodoKind.ownerGoal,
      NextActionKind.rolloverShortfall: TodoKind.rolloverShortfall,
      NextActionKind.supporterFalling: TodoKind.supporterFalling,
      NextActionKind.transferDeadline: TodoKind.transferDeadline,
      NextActionKind.signingProposals: TodoKind.signingProposals,
      NextActionKind.incomingOffer: TodoKind.incomingOffers,
      NextActionKind.budgetNegative: TodoKind.budgetNegative,
      NextActionKind.youthAtRisk: TodoKind.youthAtRisk,
      NextActionKind.contractExpiring: TodoKind.contractRenewals,
    };

    test('対応の表は、種類を1つも落としていない', () {
      expect(inboxToTodo.keys.toSet(), InboxKind.values.toSet());
      expect(actionToTodo.keys.toSet(), NextActionKind.values.toSet());
    });

    void expectCovers(GameState gs, {bool signing = false}) {
      final items = TodoAdvisor.build(gs, hasSigningProposals: signing);
      final kinds = items.map((t) => t.kind).toSet();
      for (final e in gs.inboxEntries) {
        expect(kinds, contains(inboxToTodo[e.kind]),
            reason: '受信箱の「${e.text}」が一覧に無い');
      }
      // 受信箱の件数の合計と、対応する「やること」の件数の合計が合う。
      for (final kind in InboxKind.values) {
        final want = gs.inboxEntries
            .where((e) => e.kind == kind)
            .fold<int>(0, (n, e) => n + e.count);
        final got = find(items, inboxToTodo[kind]!)?.count ?? 0;
        expect(got, want, reason: '$kind の件数');
      }
      final actions = NextActionAdvisor.all(
        gs.save!,
        gs.userTeam,
        hasSigningProposals: signing,
        transferDeadlineDaysLeft: gs.transferWindowDaysLeft,
        transferDeadlineBeforeNextMatch: gs.isTransferDeadlineDay,
        includeSetup: true,
        supporterTrend: gs.supporterTrend,
        rolloverShortfall: gs.rolloverShortfall,
        supporterUltimatumDaysLeft: gs.supporterUltimatumDaysLeft,
      );
      for (final a in actions) {
        expect(kinds, contains(actionToTodo[a.kind]),
            reason: '今週の決断の「${a.message}」が一覧に無い');
      }
      if (gs.save!.pendingBoardReviewMessage != null) {
        expect(kinds, contains(TodoKind.boardReview));
      }
    }

    test('始めたばかりのクラブ(スタッフ・スポンサー・目標)', () async {
      final gs = await newGame();
      expectCovers(gs);
      final items = build(gs);
      expect(find(items, TodoKind.staffVacant), isNotNull);
      expect(find(items, TodoKind.sponsor)?.level, TodoLevel.must);
      expect(find(items, TodoKind.ownerGoal), isNotNull);
    });

    test('答えを待つものを全部積んだクラブ', () async {
      final gs = await quietGame();
      final s = gs.save!;
      final star = gs.userTeam.players.first;
      final other = s.league.teams.firstWhere((t) => t.id != gs.userTeam.id);
      s.pendingOwnerEvent = OwnerEventKind.sponsorExit;
      s.pendingRumor = [star.id, star.name, other.name];
      s.agmDemand = AgmDemand.payout.name;
      s.pendingBoardReviewMessage = '理事会の言葉';
      s.incomingOffers = [
        for (var i = 0; i < 3; i++)
          IncomingOffer(
            id: 'o$i',
            playerId: gs.userTeam.players[i].id,
            playerName: gs.userTeam.players[i].name,
            buyerClubName: other.name,
            amount: 500,
          ),
      ];
      final staff = s.infrastructure.staffFor(StaffRole.values.first);
      s.staffOffers.add(StaffOffer(
        id: 's1',
        role: StaffRole.values.first,
        staffId: staff?.id ?? 'x',
        staffName: staff?.name ?? 'スタッフ',
        clubId: other.id,
        clubName: other.name,
        compensation: 100,
        raisePercent: 10,
        expiresOn: gs.today.add(const Duration(days: 30)),
      ));
      expect(gs.inboxEntries.length, greaterThanOrEqualTo(5));
      expectCovers(gs);

      final items = build(gs);
      // 答えを待つものは全部「必須」。
      for (final k in [
        TodoKind.ownerEvent,
        TodoKind.rumor,
        TodoKind.agmDemand,
        TodoKind.boardReview,
        TodoKind.incomingOffers,
        TodoKind.staffOffers,
      ]) {
        expect(find(items, k)?.level, TodoLevel.must, reason: '$k');
      }
      expect(find(items, TodoKind.incomingOffers)!.count, 3);
      // その場で答える札があるものは、状況が行き先。
      expect(find(items, TodoKind.ownerEvent)!.place, TodoPlaces.status);
      expect(find(items, TodoKind.ownerEvent)!.inline, isTrue);
      expect(find(items, TodoKind.staffOffers)!.place, TodoPlaces.clubStaff);
      expect(find(items, TodoKind.staffOffers)!.inline, isFalse);
    });

    test('資金マイナス・期待の低下・締切・補強候補・契約切れ', () async {
      final gs = await quietGame();
      final s = gs.save!;
      s.budget = -100;
      s.supporterTrail
        ..clear()
        ..addAll([60, 58, 55, 52, 49, 46, 45]);
      final best =
          gs.userTeam.players.reduce((a, b) => a.overall >= b.overall ? a : b);
      best.contractYearsRemaining = 1;
      expectCovers(gs, signing: true);
      final items = TodoAdvisor.build(gs, hasSigningProposals: true);
      expect(find(items, TodoKind.budgetNegative)?.level, TodoLevel.must);
      expect(
          find(items, TodoKind.signingProposals)?.level, TodoLevel.recommended);
      expect(find(items, TodoKind.contractRenewals), isNotNull);
      expect(find(items, TodoKind.supporterFalling), isNotNull);
    });

    test('最後通告は、必須のいちばん上', () async {
      final gs = await quietGame();
      final s = gs.save!;
      s.confidence = 12;
      gs.debugChangeSupporters(-5, SupporterReason.results);
      expect(gs.supporterUltimatumDaysLeft, isNotNull);
      s.pendingOwnerEvent = OwnerEventKind.sponsorExit;
      expectCovers(gs);
      final items = build(gs);
      expect(items.first.kind, TodoKind.ultimatum);
      expect(items.first.level, TodoLevel.must);
      expect(items.first.place.menu, TodoMenu.ownerRoom);
    });

    test('期待の低下は、まだ余裕があればおすすめ・低ければ必須', () async {
      final gs = await quietGame();
      final s = gs.save!;
      s.supporterTrail
        ..clear()
        ..addAll([80, 78, 75, 72, 69, 66, 65]);
      s.confidence = 65;
      expect(find(build(gs), TodoKind.supporterFalling)?.level,
          TodoLevel.recommended);
      s.confidence = 30;
      expect(find(build(gs), TodoKind.supporterFalling)?.level, TodoLevel.must);
    });
  });

  group('どこにも出ていなかったもの', () {
    test('開幕前だけの決めごと(年間シート・クラブの方針)は、開幕したら消える', () async {
      final gs = await newGame();
      var items = build(gs);
      expect(
          find(items, TodoKind.seasonTickets)?.place, TodoPlaces.clubCommunity);
      expect(
          find(items, TodoKind.clubPolicy)?.place, TodoPlaces.ownerWorld);
      await gs.playNextMatchdayQuickSim();
      items = build(gs);
      expect(find(items, TodoKind.seasonTickets), isNull);
      expect(find(items, TodoKind.clubPolicy), isNull);
    });

    test('年間シートは、売ったら消える', () async {
      final gs = await newGame();
      expect(find(build(gs), TodoKind.seasonTickets), isNotNull);
      expect(
          await gs.sellSeasonTickets(
              SeasonTicketEngine.shares.firstWhere((x) => x > 0)),
          isTrue);
      expect(find(build(gs), TodoKind.seasonTickets), isNull);
    });

    test('開幕前の海外ツアーは、未決のあいだ必須(状況の札)', () async {
      final gs = await newGame();
      gs.save!.preseasonCampPending = true;
      final item = find(build(gs), TodoKind.preseasonTour);
      expect(item?.level, TodoLevel.must);
      expect(item?.inline, isTrue);
      gs.save!.preseasonCampPending = false;
      expect(find(build(gs), TodoKind.preseasonTour), isNull);
    });

    test('監督からの提案は、経営の概要が行き先', () async {
      final gs = await quietGame();
      final p = gs.userTeam.players.first;
      gs.save!.proposals.add(ManagerProposal(
          kind: ProposalKind.renew, playerId: p.id, playerName: p.name));
      final item = find(build(gs), TodoKind.managerProposals);
      expect(item?.place, TodoPlaces.financeOverview);
      expect(item?.count, 1);
      expect(item?.note, contains(p.name));
    });

    test('ユースインテークは必須(状況の札)', () async {
      final gs = await quietGame();
      gs.save!.pendingYouthIntake = [gs.userTeam.players.first];
      final item = find(build(gs), TodoKind.youthIntake);
      expect(item?.level, TodoLevel.must);
      expect(item?.inline, isTrue);
    });

    test('オーナーの目標は、決めたら消える', () async {
      final gs = await quietGame();
      expect(find(build(gs), TodoKind.ownerGoal)?.place, TodoPlaces.ownerGoal);
      await gs.setOwnerGoal(gs.selectableOwnerGoals.first);
      expect(find(build(gs), TodoKind.ownerGoal), isNull);
    });

    test('今月の広報は、打ったら来月まで消える', () async {
      final gs = await quietGame();
      expect(find(build(gs), TodoKind.monthlyPr)?.place, TodoPlaces.ownerFans);
      final pr = ownerWorks.firstWhere((w) => w.monthly);
      expect(await gs.doOwnerWork(pr.id), isTrue);
      expect(gs.fanWorkDoneThisMonth, isTrue);
      expect(find(build(gs), TodoKind.monthlyPr), isNull);
    });

    test('試合日のイベントは、決めたら消える', () async {
      final gs = await quietGame();
      expect(find(build(gs), TodoKind.matchdayEvent)?.place,
          TodoPlaces.ownerMatchday);
      expect(await gs.setMatchdayPromo(matchdayPromos.first.id), isTrue);
      expect(find(build(gs), TodoKind.matchdayEvent), isNull);
    });

    test('オーナーの仕事は1件ずつ並べず、打てる数をまとめて1行', () async {
      final gs = await quietGame();
      final items = build(gs);
      final works = items.where((t) => t.kind == TodoKind.ownerWorks).toList();
      expect(works, hasLength(1));
      final can =
          ownerWorks.where((w) => !w.monthly && gs.canDoOwnerWork(w)).length;
      expect(works.single.count, can);
      expect(works.single.title, contains('$can件'));
    });

    test('スタッフの空席は、開幕後でも挙げる(候補がいる役だけ数える)', () async {
      final gs = await quietGame();
      final s = gs.save!;
      // 全部の役を埋めると消える。
      for (final r in StaffRole.values) {
        final c = gs.staffCandidatesFor(r);
        if (s.infrastructure.staffFor(r) == null && c.isNotEmpty) {
          s.infrastructure.staff[r] = c.first;
        }
      }
      final allFilled =
          StaffRole.values.every((r) => s.infrastructure.staffFor(r) != null);
      if (allFilled) {
        expect(find(build(gs), TodoKind.staffVacant), isNull);
      }
      // 1つ空けると、その役の名前つきで出る(開幕後でも)。
      final role = StaffRole.values
          .firstWhere((r) => gs.staffCandidatesFor(r).isNotEmpty);
      s.infrastructure.staff.remove(role);
      final item = find(build(gs), TodoKind.staffVacant);
      expect(item?.place, TodoPlaces.clubStaff);
      expect(item?.count, 1);
      expect(item?.note, contains(role.label));
    });
  });

  group('いま実行できないおすすめは出さない', () {
    test('資金が足りないと、施設の増築を挙げない', () async {
      final gs = await quietGame();
      final s = gs.save!;
      s.budget = 1 << 40;
      final rich = find(build(gs), TodoKind.facilities);
      expect(rich, isNotNull);
      expect(rich!.place, TodoPlaces.clubFacilities);
      s.budget = 0;
      expect(find(build(gs), TodoKind.facilities), isNull);
    });

    test('工事中・上限の施設は数えない', () async {
      final gs = await quietGame();
      final s = gs.save!;
      s.budget = 1 << 40;
      final before = find(build(gs), TodoKind.facilities)!.count;
      s.infrastructure.construction[FacilityType.values.first] =
          gs.today.add(const Duration(days: 90));
      expect(find(build(gs), TodoKind.facilities)!.count, before - 1);
    });

    test('更新の費用が払えない選手は、更新の時期に数えない', () async {
      final gs = await quietGame();
      final s = gs.save!;
      final p = gs.userTeam.players.firstWhere((p) => !p.isLoan);
      p.contractYearsRemaining = 1;
      s.budget = 1 << 40;
      // 主力かどうかで出方が変わらないよう、件数で見る。
      expect(find(build(gs), TodoKind.contractRenewals)?.title, contains('1人'));
      s.budget = 0;
      final poor = find(build(gs), TodoKind.contractRenewals);
      // 払えなければ「更新の時期の選手が1人」とは出さない(主力なら、契約が
      // 切れかけている知らせだけが残る)。
      expect(poor?.title ?? '', isNot(contains('1人')));
    });

    test('資金が足りないと、有料の試合日のイベントしか無ければ挙げない(無料があれば挙げる)', () async {
      final gs = await quietGame();
      gs.save!.budget = 0;
      final free = matchdayPromos.any((p) => p.cost == 0);
      expect(find(build(gs), TodoKind.matchdayEvent) != null, free);
    });

    test('手放すことが決まったら、何も挙げない', () async {
      final gs = await quietGame();
      gs.save!.confidence = 0;
      gs.save!.supporterUltimatumUntil =
          gs.today.subtract(const Duration(days: 1));
      if (gs.saleReason != null) {
        expect(build(gs), isEmpty);
      }
    });
  });

  group('印の件数は一覧と合う', () {
    test('状況の印は必須の合計、ほかの項目は行き先がそこのものだけ', () async {
      final gs = await newGame();
      final s = gs.save!;
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
      final items = build(gs);
      final must = items.where((t) => t.isMust).toList();
      expect(items.mustCount, must.fold<int>(0, (n, t) => n + t.count));
      expect(items.mustAt(TodoMenu.status), items.mustCount);
      // 事件の札は状況に出る。オーナー室には印を付けない(以前の食い違い)。
      expect(items.mustAt(TodoMenu.ownerRoom), 0);
      // 届いたオファーは、状況の札と移籍>オファーの両方で答えられる。
      expect(items.mustAt(TodoMenu.transfer), 2);
      expect(items.mustAt(TodoMenu.transfer, TodoPlaces.transferOffers.tab), 2);
      // 交渉とオファーは同じタブ(2026-11-24 にまとめた)。候補のタブには付かない。
      expect(items.mustAt(TodoMenu.transfer, TodoPlaces.transferPicks.tab), 0);
      // スポンサーは経営の「資金・取引」。
      expect(items.mustAt(TodoMenu.finance), 1);
      expect(items.mustAt(TodoMenu.finance, TodoPlaces.financeFunding.tab), 1);
      expect(items.mustAt(TodoMenu.finance, TodoPlaces.financeOverview.tab), 0);
      // おすすめは、行き先の項目とタブに。状況には付けない。
      expect(items.recommendedAt(TodoMenu.status), 0);
      for (final menu in TodoMenu.values) {
        if (menu == TodoMenu.status) continue;
        final want = items
            .where((t) => !t.isMust && t.marked && t.place.menu == menu)
            .length;
        expect(items.recommendedAt(menu), want, reason: '$menu');
      }
      expect(items.recommendedCount, items.where((t) => !t.isMust).length);
    });

    test('青い点は「今だけ」のおすすめに絞る(いつでも出がちなものには付けない)', () async {
      final gs = await quietGame();
      final s = gs.save!;
      s.budget = 1 << 40;
      final p = gs.userTeam.players.firstWhere((p) => !p.isLoan);
      p.contractYearsRemaining = 1;
      final role = StaffRole.values
          .firstWhere((r) => gs.staffCandidatesFor(r).isNotEmpty);
      s.infrastructure.staff.remove(role);
      final items = build(gs);
      // 増築できる施設・更新の時期・開幕後のスタッフの空席・打てるオーナーの
      // 手は、一覧には出すが印は付けない。
      for (final k in [
        TodoKind.facilities,
        TodoKind.contractRenewals,
        TodoKind.staffVacant,
        TodoKind.ownerWorks,
        TodoKind.ownerGoal,
      ]) {
        expect(find(items, k), isNotNull, reason: '$k が一覧に無い');
        expect(find(items, k)!.marked, isFalse, reason: '$k に印が付く');
      }
      // 今月の広報・試合日のイベントは今だけなので付ける。
      expect(find(items, TodoKind.monthlyPr)!.marked, isTrue);
      expect(find(items, TodoKind.matchdayEvent)!.marked, isTrue);
      // クラブと選手には、おすすめの青い点が付かない。
      expect(items.recommendedAt(TodoMenu.club), 0);
      expect(items.recommendedAt(TodoMenu.squad), 0);
      expect(items.recommendedAt(TodoMenu.ownerRoom), 2);
      // 打てるオーナーの手は、おすすめのいちばん下。
      expect(items.last.kind, TodoKind.ownerWorks);
      // 必須は必ず印が付く。
      expect(items.where((t) => t.isMust).every((t) => t.marked), isTrue);
    });

    test('開幕前のスタッフの空席は「今だけ」なので印を付ける', () async {
      final gs = await newGame();
      expect(find(build(gs), TodoKind.staffVacant)!.marked, isTrue);
    });

    test('並びは必須が先、同じ重さの中は種類の順', () async {
      final gs = await newGame();
      final items = build(gs);
      final firstRec = items.indexWhere((t) => !t.isMust);
      if (firstRec >= 0) {
        expect(items.skip(firstRec).every((t) => !t.isMust), isTrue);
      }
      for (var i = 1; i < items.length; i++) {
        if (items[i].level != items[i - 1].level) continue;
        expect(items[i].kind.index, greaterThan(items[i - 1].kind.index));
      }
    });

    test('題と説明は、日本語と英語の両方で空でない', () async {
      final gs = await newGame();
      for (final lang in [AppLanguage.japanese, AppLanguage.english]) {
        Tr.language = lang;
        for (final t in build(gs)) {
          expect(t.title.trim(), isNotEmpty, reason: '${t.kind} $lang');
        }
      }
    });
  });
}
