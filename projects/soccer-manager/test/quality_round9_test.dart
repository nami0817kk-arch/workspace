// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/models/attributes.dart';
import 'package:soccer_manager/models/club_infrastructure.dart';
import 'package:soccer_manager/models/community_activity.dart';
import 'package:soccer_manager/models/league.dart';
import 'package:soccer_manager/models/formation.dart';
import 'package:soccer_manager/models/ledger.dart';
import 'package:soccer_manager/models/manager_profile.dart';
import 'package:soccer_manager/models/owner_event.dart';
import 'package:soccer_manager/models/sponsor.dart';
import 'package:soccer_manager/models/staff_member.dart';
import 'package:soccer_manager/models/staff_offer.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 品質改善の9回目(2026-11-23): 施設の建設・サポーターの期待・監督の
/// 戦術・スタッフの引き抜き・観客収入の上限で、例外を出さずに壊れていた所。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Tr.language = AppLanguage.japanese;
  });
  tearDown(() => Tr.language = AppLanguage.system);

  Future<GameState> newGame([String name = '九回目FC']) async {
    final gs = GameState();
    await gs.startNewGame(name);
    return gs;
  }

  Fixture nextUserFixture(GameState gs) =>
      gs.save!.league.fixtures.firstWhere((f) =>
          f.result == null &&
          (f.homeTeamId == gs.save!.userTeamId ||
              f.awayTeamId == gs.save!.userTeamId));

  StaffMember coach(String id, {int wage = 10}) => StaffMember(
        id: id,
        name: 'コーチ$id',
        age: 45,
        role: StaffRole.headCoach,
        attributes: {for (final a in StaffAttribute.values) a: 12},
        wage: wage,
        contractYears: 2,
      );

  StaffOffer offerFor(GameState gs, StaffMember st,
          {int compensation = 1000}) =>
      StaffOffer(
        id: 'offer-${st.id}',
        role: st.role,
        staffId: st.id,
        staffName: st.name,
        clubId: 'club-x',
        clubName: '大きいFC',
        compensation: compensation,
        raisePercent: 30,
        expiresOn: gs.today.add(const Duration(days: 14)),
      );

  group('1 ダービー・祝日で増えるのは入場収入だけ', () {
    test('祝日の節の見込みは、スポンサーがいくら大きくても入場収入の割合しか増えない', () async {
      final gs = await newGame();
      final s = gs.save!;
      s.sponsorDeal =
          SponsorDeal(name: '大口', weeklyIncome: 1000000, yearsRemaining: 3);
      final md = gs.matchdaysPerSeason;
      final holiday = [
        for (var i = 1; i <= md; i++)
          if (gs.holidayOfMatchday(i) != null) i
      ].first;
      final plain = [
        for (var i = 1; i <= md; i++)
          if (gs.holidayOfMatchday(i) == null) i
      ].first;
      final gate = gs.weeklyIncomeParts(s.userTeamId).gate;
      final extra =
          gs.expectedMatchdayIncome(holiday) - gs.expectedMatchdayIncome(plain);
      expect(extra, greaterThanOrEqualTo(0));
      expect(extra, lessThanOrEqualTo((gate * 0.15).ceil() + 1),
          reason: 'スポンサー収入にまで客の増えた割合が掛かっている');
    });

    test('ダービーを戦っても、記帳される観客収入はスポンサーの額で膨らまない', () async {
      final gs = await newGame();
      final s = gs.save!;
      s.sponsorDeal =
          SponsorDeal(name: '大口', weeklyIncome: 1000000, yearsRemaining: 3);
      final next = nextUserFixture(gs);
      s.rivalTeamId =
          next.homeTeamId == s.userTeamId ? next.awayTeamId : next.homeTeamId;
      final parts = gs.weeklyIncomeParts(s.userTeamId);
      final before = s.ledgerFor(s.league.season).of(LedgerCategory.gate);
      await gs.playNextMatchday();
      if (gs.isHalfTime) await gs.playSecondHalf();
      final booked =
          s.ledgerFor(s.league.season).of(LedgerCategory.gate) - before;
      expect(booked, greaterThan(0));
      // 人数はダービーで最大1.5倍、祝日ならさらに1.15倍。順位で土台が
      // 少し動いても、スポンサーの100万の半分が混ざれば必ず超える。
      expect(booked, lessThanOrEqualTo(parts.gate * 2 + 1000),
          reason: 'スポンサー・グッズの分までダービーの増分に入っている');
    });
  });

  group('2 セットプレーの担当は、先発で出られる選手から', () {
    test('いちばん上手いキッカーが怪我で先発にいなければ、先発の中から選ぶ', () async {
      final gs = await newGame();
      final team = gs.userTeam;
      final next = nextUserFixture(gs);
      gs.debugManagerPreparesMatch(next);
      final bench =
          team.players.firstWhere((p) => !team.startingXI.contains(p.id));
      bench
        ..setAttributeValue(AttributeKeys.penalties, 99)
        ..setAttributeValue(AttributeKeys.freeKick, 99)
        ..setAttributeValue(AttributeKeys.corners, 99)
        ..injuryWeeks = 4;
      gs.debugManagerPreparesMatch(next);
      expect(team.startingXI, isNot(contains(bench.id)));
      for (final id in [
        team.penaltyTakerId,
        team.freeKickTakerId,
        team.cornerTakerId,
        team.setPieceDefenderId,
      ]) {
        expect(id, isNotNull);
        expect(team.startingXI, contains(id),
            reason: '担当が先発にいないと、試合では誰とも決まらない選手が蹴る');
      }
    });
  });

  group('3 引き抜きの話は、相手が役職を去れば消える', () {
    test('解任すると話が消え、後任の欄に前任の話は出ない', () async {
      final gs = await newGame();
      final s = gs.save!;
      final old = coach('old');
      s.infrastructure.staff[StaffRole.headCoach] = old;
      s.staffOffers.add(offerFor(gs, old));
      expect(gs.staffOfferFor(StaffRole.headCoach), isNotNull);
      expect(await gs.dismissStaff(StaffRole.headCoach), isTrue);
      expect(s.staffOffers, isEmpty);
      // 片付けを通らずに入れ替わっていても、後任の欄には出さない。
      s.staffOffers.add(offerFor(gs, old));
      s.infrastructure.staff[StaffRole.headCoach] = coach('new');
      expect(gs.staffOfferFor(StaffRole.headCoach), isNull);
      gs.debugDropStaleStaffOffers();
      expect(s.staffOffers, isEmpty);
    });

    test('候補を雇って入れ替えると、前任への話は消える', () async {
      final gs = await newGame();
      final s = gs.save!;
      s.budget = 99999999;
      s.wageBudget = 99999999;
      final cand = gs.staffCandidatesFor(StaffRole.headCoach).first;
      final old = coach('old');
      s.infrastructure.staff[StaffRole.headCoach] = old;
      s.staffOffers.add(offerFor(gs, old));
      expect(await gs.hireStaff(cand.id), isTrue);
      expect(s.staffOffers, isEmpty);
      expect(gs.staffOfferFor(StaffRole.headCoach), isNull);
    });
  });

  group('4 相手のいない事件は消える', () {
    test('監督がいないのに「監督の引き抜き」に答えても、お金も期待も動かない', () async {
      final gs = await newGame();
      final s = gs.save!;
      s.infrastructure.staff[StaffRole.manager] = null;
      s.pendingOwnerEvent = OwnerEventKind.managerPoach;
      final budget = s.budget;
      final supporters = s.confidence;
      expect(gs.pendingOwnerEvent, isNull);
      expect(await gs.resolveOwnerEvent(1), isFalse);
      expect(s.budget, budget);
      expect(s.confidence, supporters);
      expect(s.pendingOwnerEvent, isNull);
    });

    test('ユースがいなければ「ユースの引き抜き」も消える', () async {
      final gs = await newGame();
      final s = gs.save!;
      s.youthProspects = [];
      s.pendingOwnerEvent = OwnerEventKind.youthPoach;
      expect(gs.pendingOwnerEvent, isNull);
    });

    test('順位で起きた事件(スポンサーの撤退)は、順位が上がっても残る', () async {
      final gs = await newGame();
      gs.save!.pendingOwnerEvent = OwnerEventKind.sponsorExit;
      expect(gs.pendingOwnerEvent, OwnerEventKind.sponsorExit);
    });
  });

  group('5 同じ国で買い直しても、前のクラブのものは持ち越さない', () {
    test('事件・提案・引き抜きの話・地域活動・逃げ切りの采配', () async {
      final gs = await newGame();
      final s = gs.save!;
      final oldId = s.userTeamId;
      gs.userTeam.holdLeadLate = true;
      s.pendingOwnerEvent = OwnerEventKind.transferDemand;
      s.communityActivities = [
        CommunityActivity.visits,
        CommunityActivity.cleanup,
      ];
      final st = gs.staffFor(StaffRole.manager) ?? coach('m');
      s.staffOffers.add(offerFor(gs, st));
      s
        ..confidence = 0
        ..supporterUltimatumUntil = DateTime(2000);
      final target = gs.buyoutCandidates.first;
      expect(await gs.buyClub(target.id), isTrue);
      expect(s.userTeamId, target.id);
      expect(s.pendingOwnerEvent, isNull);
      expect(s.staffOffers, isEmpty);
      expect(s.communityLevel, 0);
      expect(s.proposals, isEmpty);
      expect(s.boardCupTargetRound, greaterThan(0));
      final former = s.league.teams.firstWhere((t) => t.id == oldId);
      expect(former.holdLeadLate, isFalse,
          reason: '逃げ切りは自クラブの監督だけのもの。CPU に戻ったクラブに残さない');

      // 保存して読み直しても、そのまま。
      final loaded = GameState();
      expect(await loaded.importSaveJson(gs.exportSaveJson()!), isTrue);
      expect(loaded.save!.communityLevel, 0);
      expect(loaded.save!.pendingOwnerEvent, isNull);
      expect(
          loaded.save!.league.teams
              .firstWhere((t) => t.id == oldId)
              .holdLeadLate,
          isFalse);
    });
  });

  group('6 スタッフの週俸を15%にしたとき、補償金も同じ割合にする', () {
    test('届いている引き抜きの話と、他クラブで指揮している候補の補償金', () async {
      final gs = await newGame();
      final s = gs.save!;
      final st = coach('old', wage: 100);
      s.infrastructure.staff[StaffRole.headCoach] = st;
      s.staffOffers.add(offerFor(gs, st, compensation: 2600));
      final cand = s.staffCandidates.firstWhere(
          (c) => c.role == StaffRole.manager,
          orElse: () => s.staffCandidates.first);
      cand.manager = ManagerProfile(
        style: ManagerStyle.pragmatic,
        formation: Formation.f442,
        employerClubId: 'club-x',
        employerClubName: '大きいFC',
        compensation: 10000,
      );
      final json = jsonDecode(gs.exportSaveJson()!) as Map<String, dynamic>;
      json.remove('staffWageVersion');
      final loaded = GameState();
      expect(await loaded.importSaveJson(jsonEncode(json)), isTrue);
      expect(loaded.save!.staffOffers.single.compensation, 390);
      final c = loaded.save!.staffCandidates.firstWhere((x) => x.id == cand.id);
      expect(c.manager!.compensation, 1500);
      expect(c.manager!.employerClubName, '大きいFC');
      // 読み直しても、もう一度は掛けない。
      final again = GameState();
      expect(await again.importSaveJson(loaded.exportSaveJson()!), isTrue);
      expect(again.save!.staffOffers.single.compensation, 390);
    });
  });

  group('7 施設の工事', () {
    test('月末の着工は、3か月後の月の末日に完成する(月が繰り越さない)', () async {
      final gs = await newGame();
      final s = gs.save!;
      s.today = DateTime(s.today!.year, 11, 30);
      expect(gs.facilityReadyDateFor(FacilityType.trainingGround),
          DateTime(s.today!.year + 1, 2, 28));
      s.today = DateTime(s.today!.year, 8, 31);
      expect(gs.facilityReadyDateFor(FacilityType.medicalCenter),
          DateTime(s.today!.year, 11, 30));
      s.today = DateTime(s.today!.year, 9, 15);
      expect(gs.facilityReadyDateFor(FacilityType.youthFacility),
          DateTime(s.today!.year, 12, 15));
    });

    test('「席数 × 1席の値段」は、補助を引いた建設費と合う', () async {
      final gs = await newGame();
      final s = gs.save!;
      s.stadiumSubsidyPct = 30;
      final cost = gs.facilityUpgradeCostFor(FacilityType.stadium);
      expect(gs.stadiumSeatCostNow * ClubInfrastructure.stadiumSeatsPerLevel,
          closeTo(cost, ClubInfrastructure.stadiumSeatsPerLevel / 2));
      expect(
          gs.stadiumSeatCostNow,
          lessThan(ClubInfrastructure.stadiumSeatCost(
              s.infrastructure.facilityLevel(FacilityType.stadium))));
    });
  });

  group('8 季末の見通しの文', () {
    test('最後通告が出ているなら「新しい季の初日に出る」ではなく、期限が続くと書く', () async {
      final gs = await newGame();
      final s = gs.save!;
      s.confidence = 0;
      s.boardTargetRank = 1;
      s.supporterUltimatumUntil = gs.today.add(const Duration(days: 60));
      expect(gs.seasonEndSupporterDelta,
          lessThan(GameStateSupporters.ultimatumLine));
      final line = gs.seasonEndPreviewLine;
      expect(line, contains('季をまたいでも続きます'));
      expect(line, isNot(contains('新しい季の初日に最後通告が出ます')));
      Tr.language = AppLanguage.english;
      final en = gs.seasonEndPreviewLine;
      expect(en, contains('carries over'));
      expect(RegExp(r'[ぁ-んァ-ヶ一-龠]').hasMatch(en), isFalse,
          reason: '英語の表示に日本語が漏れている');
    });
  });
}
