// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/logic/economy_scale.dart';
import 'package:soccer_manager/logic/proposal_engine.dart';
import 'package:soccer_manager/logic/reserve_match_engine.dart';
import 'package:soccer_manager/logic/shareholder_engine.dart';
import 'package:soccer_manager/logic/training_engine.dart';
import 'package:soccer_manager/models/club_infrastructure.dart';
import 'package:soccer_manager/models/club_vision.dart';
import 'package:soccer_manager/models/match_result.dart';
import 'package:soccer_manager/models/owner_work.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/models/staff_member.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 長く遊んだときの釣り合い(2026-11-23)。
///
/// GameState の公開メソッドで3つの方針を10季回して測ったところ、
/// 自クラブだけが練習で疲れていつも最下位・1部の収入が青天井・スタッフの
/// 週俸が収入より速く膨らむ・監督の引き抜きが多すぎる・広報だけで期待が
/// 満点に張り付く・何もしないオーナーが10季生き残る、が見つかった。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Tr.language = AppLanguage.japanese;
  });
  tearDown(() => Tr.language = AppLanguage.system);

  Future<GameState> newGame([String name = '釣り合いFC']) async {
    final gs = GameState();
    await gs.startNewGame(name);
    return gs;
  }

  group('1 練習の疲れ', () {
    test('通常の全体練習は +4、週の抜けは -6 で、1週で2下がる', () async {
      final gs = await newGame();
      final team = gs.userTeam;
      team.defaultTrainingFocus = TrainingFocus.balanced;
      team.trainingIntensity = TrainingIntensity.normal;
      for (final p in team.players) {
        p.fatigue = 50;
      }
      TrainingEngine.applyWeeklyTraining(team);
      for (final p in team.players) {
        expect(p.fatigue,
            50 + TrainingEngine.fatigueBalanced - TrainingEngine.weeklyRecovery,
            reason: p.name);
      }
      expect(TrainingEngine.fatigueBalanced, lessThanOrEqualTo(4));
      expect(TrainingEngine.weeklyRecovery, 6);
    });

    test('リザーブの試合の疲れは4', () {
      expect(ReserveMatchEngine.fatigueCost, 4);
    });

    test('水準4以上の監督は、先発が疲れた週に練習を軽く・休養にする', () {
      expect(TrainingEngine.managerEasing(managerLevel: 3, starterFatigue: 90),
          (null, null),
          reason: '水準3以下の監督は何もしない');
      expect(TrainingEngine.managerEasing(managerLevel: 4, starterFatigue: 40),
          (null, null));
      expect(TrainingEngine.managerEasing(managerLevel: 4, starterFatigue: 50),
          (null, TrainingIntensity.light));
      expect(TrainingEngine.managerEasing(managerLevel: 6, starterFatigue: 70),
          (TrainingFocus.rest, null));
    });

    test('監督が休養にした週は、先発の疲れが大きく抜ける', () async {
      final gs = await newGame();
      final team = gs.userTeam;
      team.defaultTrainingFocus = TrainingFocus.attack;
      gs.save!.infrastructure.staff[StaffRole.manager] = StaffMember(
        id: 'mgr-test',
        name: 'テスト監督',
        age: 50,
        role: StaffRole.manager,
        attributes: {for (final a in StaffAttribute.values) a: 15},
        wage: 10,
      );
      expect(gs.save!.infrastructure.staffLevel(StaffRole.manager),
          greaterThanOrEqualTo(4));
      for (final p in team.players) {
        p.fatigue = 90;
      }
      gs.save!.trainingDoneThisWeek = false;
      expect(await gs.runWeeklyTraining(), isTrue);
      final xi =
          team.players.where((p) => team.startingXI.contains(p.id)).toList();
      expect(xi, isNotEmpty);
      for (final p in xi) {
        expect(p.fatigue,
            lessThanOrEqualTo(90 - 30 - TrainingEngine.weeklyRecovery),
            reason: p.name);
      }
    });
  });

  group('2 1部の収入の青天井', () {
    test('商業施設は1段 +4%(Lv8 で 1.28 倍)', () {
      expect(ClubInfrastructure.commercialRevenueMultiplier(1), 1.0);
      expect(ClubInfrastructure.commercialRevenueMultiplier(8),
          closeTo(1.28, 1e-9));
    });

    test('観客収入は、1年で「入る人数×ホームの試合×1人の単価」を超えない', () async {
      final gs = await newGame();
      final s = gs.save!;
      final md = gs.matchdaysPerSeason;
      final home =
          s.league.fixtures.where((f) => f.homeTeamId == s.userTeamId).length;
      final perYear = gs.expectedAttendance *
          home *
          gateRevenuePerFan(s.currentDivisionTier) *
          s.ticketPricing.revenueMultiplier;
      expect(gs.gateCapPerMatchday * md, closeTo(perYear, md.toDouble()));

      // 来る人が少なければ、施設を建てても観客収入は人数で頭打ち。
      s.fanDemand = 3000;
      s.infrastructure.facilityLevels[FacilityType.commercialFacility] = 8;
      final cap = gs.gateCapPerMatchday;
      final gate = gs.weeklyIncomeParts(s.userTeamId).gate;
      expect(cap, lessThan(3000 * 0.2 * 1.3));
      // 頭打ちの後に掛かる倍率(予算の配分・景気など)の分だけの幅を見る。
      expect(gate, lessThanOrEqualTo((cap * 1.3).round()));
    });

    test('上限に届いていても、試合日のイベントを打てば観客収入は増える', () async {
      final gs = await newGame();
      final s = gs.save!;
      s.budget = 500000;
      s.fanDemand = 3000;
      final id = s.userTeamId;
      final capped = gs.weeklyIncomeParts(id).gate;
      expect(await gs.setMatchdayPromo('light_up'), isTrue);
      expect(gs.weeklyIncomeParts(id).gate, greaterThan(capped));
    });

    test('順位の上乗せは1つにつき6', () {
      expect(GameStateFinance.gateRankStep, 6);
    });
  });

  group('3 スタッフの週俸', () {
    test('週俸の相場は以前の15%', () {
      expect(StaffMember.staffWageFactor, 0.15);
      expect(StaffMember.askingWage(10), ((4 + 100 * 0.25) * 0.15).round());
      expect(StaffMember.askingWage(1), greaterThanOrEqualTo(1));
    });

    test('古いセーブのスタッフの週俸は、読み込んだときに一度だけ15%にする', () async {
      final gs = await newGame();
      gs.save!.infrastructure.staff[StaffRole.headCoach] = StaffMember(
        id: 'coach-old',
        name: '古いコーチ',
        age: 45,
        role: StaffRole.headCoach,
        attributes: {for (final a in StaffAttribute.values) a: 12},
        wage: 100,
      );
      final json = jsonDecode(gs.exportSaveJson()!) as Map<String, dynamic>;
      json.remove('staffWageVersion');
      expect(SaveGame.fromJson(json).staffWageVersion, 1);
      final loaded = GameState();
      expect(await loaded.importSaveJson(jsonEncode(json)), isTrue);
      expect(loaded.staffFor(StaffRole.headCoach)!.wage, 15);
      expect(loaded.save!.staffWageVersion, SaveGame.currentStaffWageVersion);
      // 読み直しても、もう一度は掛けない。
      final again = GameState();
      expect(await again.importSaveJson(loaded.exportSaveJson()!), isTrue);
      expect(again.staffFor(StaffRole.headCoach)!.wage, 15);
    });
  });

  group('4 監督の引き抜き', () {
    test('月 2%+1%/段(水準3以下は来ない)', () {
      expect(GameStateStaffMoves.poachChance(3), 0);
      expect(GameStateStaffMoves.poachChance(4), closeTo(0.02, 1e-9));
      expect(GameStateStaffMoves.poachChance(8), closeTo(0.06, 1e-9));
    });

    test('着任から1年は来ず、1季に1回まで', () async {
      final gs = await newGame();
      final st = StaffMember(
        id: 'mgr-p',
        name: '狙われる監督',
        age: 50,
        role: StaffRole.manager,
        attributes: {for (final a in StaffAttribute.values) a: 18},
        wage: 10,
      );
      expect(gs.staffPoachable(st), isTrue, reason: '着任日の無い旧セーブ');
      st.hiredOn = gs.today.subtract(const Duration(days: 100));
      expect(gs.staffPoachable(st), isFalse);
      st.hiredOn = gs.today.subtract(const Duration(days: 366));
      expect(gs.staffPoachable(st), isTrue);
      gs.save!.staffPoachSeason = gs.save!.league.season;
      expect(gs.staffPoachable(st), isFalse, reason: '今季はもう来た');
    });

    test('雇った日を覚え、保存して読み戻せる', () async {
      final gs = await newGame();
      gs.save!.wageBudget = 99999999;
      gs.save!.budget = 99999999;
      final c = gs.staffCandidatesFor(StaffRole.headCoach).first;
      expect(await gs.hireStaff(c.id), isTrue);
      final hired = gs.staffFor(StaffRole.headCoach)!;
      expect(hired.hiredOn, isNotNull);
      final back = StaffMember.fromJson(hired.toJson());
      expect(back.hiredOn, hired.hiredOn);
    });
  });

  group('5 広報', () {
    test('資金0の会見は +2 から、同じ季に打つたびに1ずつ減る', () async {
      final gs = await newGame();
      final s = gs.save!;
      s.confidence = 50;
      final press =
          ownerWorks.firstWhere((w) => w.id == OwnerWork.visionPressId);
      final got = <int>[];
      for (var i = 0; i < 3; i++) {
        expect(gs.ownerWorkSupporters(press), 2 - i);
        final before = s.confidence;
        expect(await gs.doOwnerWork(press.id), isTrue);
        got.add(s.confidence - before);
        final t = gs.today;
        gs.debugAdvanceTodayTo(DateTime(t.year, t.month + 1, 2));
        s.confidence = 50;
      }
      expect(got, [2, 1, 0]);
      // 季が変われば戻る。
      s.visionPressSeason = s.league.season - 1;
      expect(gs.ownerWorkSupporters(press), 2);
    });

    test('結果がマイナスの月は、広報の効き目が半分になる', () async {
      final gs = await newGame();
      final s = gs.save!;
      s.confidence = 50;
      gs.debugChangeSupporters(4, SupporterReason.pr);
      s.supporterMonthGames = 4;
      s.supporterMonthPoints = 0;
      // 最下位にする(開幕前は全クラブ勝点0で、並びしだいで上位になる)。
      s.league.pointsAdjustments[s.userTeamId] = -30;
      expect(gs.monthlyResultDeltaNow, lessThan(0));
      final t = gs.today;
      gs.debugCloseSupporterMonth(DateTime(t.year, t.month + 1, 0));
      expect(s.supporterLastMonth['pr'], 2);
    });

    test('結果がマイナスでない月は、広報はそのまま', () async {
      final gs = await newGame();
      final s = gs.save!;
      s.confidence = 50;
      gs.debugChangeSupporters(4, SupporterReason.pr);
      s.supporterMonthGames = 0;
      final t = gs.today;
      gs.debugCloseSupporterMonth(DateTime(t.year, t.month + 1, 0));
      expect(s.supporterLastMonth['pr'], 4);
    });
  });

  group('6 手放した選手の更新の提案', () {
    test('承認しても落ちず false を返し、提案は消える', () async {
      final gs = await newGame();
      final s = gs.save!;
      const p = ManagerProposal(
          kind: ProposalKind.renew,
          playerId: 'gone-player',
          playerName: '去った人');
      s.proposals.add(p);
      expect(await gs.approveProposal(p.id), isFalse);
      expect(s.proposals.where((x) => x.id == p.id), isEmpty);
      expect(await gs.renewContract('gone-player'), isFalse);
    });

    test('選手が抜けると、その選手の更新の提案は消える', () async {
      final gs = await newGame();
      final s = gs.save!;
      final player = gs.userTeam.players.last;
      s.proposals.add(ManagerProposal(
          kind: ProposalKind.renew,
          playerId: player.id,
          playerName: player.name));
      await gs.setTransferListed(player.id, true);
      final o = gs.debugOfferFor(player.id);
      expect(o, isNotNull);
      expect(await gs.acceptIncomingOffer(o!.id), isTrue);
      expect(s.proposals.where((x) => x.playerId == player.id), isEmpty);
    });
  });

  group('7 季を越える最後通告と株主', () {
    /// 自クラブが全敗、ほかは全部引き分けで季を終わらせる(最下位)。
    void loseEverything(GameState gs) {
      final userId = gs.userTeam.id;
      for (final f in gs.save!.league.fixtures) {
        final home = f.homeTeamId == userId;
        final away = f.awayTeamId == userId;
        f.result = MatchResult(
          matchday: f.matchday,
          homeTeamId: f.homeTeamId,
          awayTeamId: f.awayTeamId,
          homeGoals: home ? 0 : (away ? 3 : 1),
          awayGoals: away ? 0 : (home ? 3 : 1),
          events: [],
        );
      }
    }

    test('季末に10を割っていたら、底上げせず新しい季の初日に最後通告', () async {
      final gs = await newGame();
      loseEverything(gs);
      final s = gs.save!;
      s.clubVision = ClubVision.none;
      s.confidence = 15;
      expect(gs.seasonEndPreviewLine, contains('最後通告'));
      await gs.startNextSeason();
      expect(s.confidence, lessThan(GameStateSupporters.ultimatumLine));
      expect(gs.isUnderSupporterUltimatum, isTrue);
      expect(gs.supporterUltimatumDaysLeft, GameStateSupporters.ultimatumDays);
      expect(gs.saleReason, isNull);
    });

    test('株主の期待の季末の増減に、順位と目標の差を3割混ぜる', () {
      expect(
          ShareholderEngine.mixedWithResults(financial: 12, results: -10), 5);
      expect(
          ShareholderEngine.mixedWithResults(financial: 12, results: 15), 13);
      expect(ShareholderEngine.mixedWithResults(financial: -17, results: -10),
          -15);
    });
  });
}
