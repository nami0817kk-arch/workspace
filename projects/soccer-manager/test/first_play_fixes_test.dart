// ignore_for_file: invalid_use_of_visible_for_testing_member

// 季の切り替え(裏の部と他国の1季ぶん)を何度か回すので、既定の30秒では
// 足りない。
@Timeout(Duration(minutes: 5))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/logic/board_engine.dart';
import 'package:soccer_manager/logic/manager_report_engine.dart';
import 'package:soccer_manager/logic/next_action_advisor.dart';
import 'package:soccer_manager/models/club_vision.dart';
import 'package:soccer_manager/models/match_result.dart';
import 'package:soccer_manager/models/owner_legacy.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/models/sponsor.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 初めて遊ぶ人がつまずいた所の手当て(2026-11-23)。
///
/// 1 季の切り替えの崖 / 3 下がり続ける期待の早めの知らせ /
/// 4 最初に手を付けること / 6 季の結果のまとめ / 7 切り替えの給与 /
/// 8 決めごとの締切。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Tr.language = AppLanguage.japanese;
  });
  tearDown(() => Tr.language = AppLanguage.system);

  Future<GameState> newGame([String name = '初手FC']) async {
    final gs = GameState();
    await gs.startNewGame(name);
    return gs;
  }

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

  group('1 季の切り替えの崖', () {
    test('期待20で最下位でも、新しい季は40から始まり手放さない', () async {
      final gs = await newGame();
      loseEverything(gs);
      final s = gs.save!;
      s.clubVision = ClubVision.none;
      s.confidence = 20;
      // 季末は目標との差に比例し、下がる幅は最大 -10(2026-11-23)。
      // 目標の順位はくじで変わるので、最下位との差しだいで -9 などにもなる。
      expect(gs.seasonEndSupporterDelta,
          inInclusiveRange(-BoardEngine.boardReviewMaxDrop, -1));
      await gs.startNextSeason();
      expect(s.confidence, BoardEngine.newSeasonConfidenceFloor);
      expect(gs.saleReason, isNull, reason: '第2季の1試合目より前に手放していた');
    });

    test('最後通告の期限を過ぎていたら、季を越えても手放す', () async {
      final gs = await newGame();
      loseEverything(gs);
      gs.save!.clubVision = ClubVision.none;
      gs.save!.confidence = 0;
      gs.save!.supporterUltimatumUntil = DateTime(2000);
      await gs.startNextSeason();
      expect(gs.save!.confidence, 0);
      expect(gs.saleReason, SaleReason.supporters);
    });

    test('最後通告の猶予中なら、季の切り替えで40へ戻り通告は取り下げ', () async {
      final gs = await newGame();
      loseEverything(gs);
      final s = gs.save!;
      s.clubVision = ClubVision.none;
      s.confidence = 5;
      s.supporterUltimatumUntil = gs.today.add(const Duration(days: 300));
      await gs.startNextSeason();
      expect(s.confidence, BoardEngine.newSeasonConfidenceFloor);
      expect(s.supporterUltimatumUntil, isNull);
      expect(gs.saleReason, isNull);
    });

    test('「シーズン終了！」の札に、来る増減を先に出す', () async {
      final gs = await newGame();
      loseEverything(gs);
      gs.save!.confidence = 20;
      final line = gs.seasonEndPreviewLine;
      expect(line, contains('-${BoardEngine.boardReviewMaxDrop}'));
      expect(line, contains('最低${BoardEngine.newSeasonConfidenceFloor}'));
    });
  });

  group('3 下がり続ける期待', () {
    test('22位で目標17位なら「大きな問題はありません」と言わない', () {
      final r = ManagerReportEngine.build(
        rank: 22,
        teamCount: 24,
        tier: 3,
        supporter: 50,
        shareholder: 50,
        budget: 1000,
        weeklyNet: 10,
        targetRank: 17,
      );
      expect(r.headline, isNot(contains('大きな問題はありません')));
      // 季末の増減は目標との差に比例(下がる幅は最大 -10)。
      expect(r.headline, contains('-10'));
    });

    test('直近5節で -10 以上下がれば、危ない線の前でも報告が変わる', () {
      final r = ManagerReportEngine.build(
        rank: 12,
        teamCount: 24,
        tier: 3,
        supporter: 50,
        shareholder: 50,
        budget: 1000,
        weeklyNet: 10,
        targetRank: 17,
        supporterTrend: -12,
      );
      expect(r.headline, contains('サポーターの期待'));
      expect(r.headline, contains('オーナー室'));
    });

    test('推移は節ごとに控え、直近5節の増減を出す', () async {
      final gs = await newGame();
      final s = gs.save!;
      s.supporterTrail
        ..clear()
        ..addAll([60, 58, 55, 52, 49, 46, 45]);
      expect(gs.supporterTrend, 45 - 58);
      expect(gs.supporterFalling, isTrue);
    });

    test('今週の決断は、期待の低下を契約の知らせより先に出す', () async {
      final gs = await newGame();
      final s = gs.save!;
      s.budget = 1000000;
      // 主力の契約を切れかけにする(普段ならこれが出る)。
      final best =
          gs.userTeam.players.reduce((a, b) => a.overall >= b.overall ? a : b);
      best.contractYearsRemaining = 1;
      final action = NextActionAdvisor.top(s, gs.userTeam, supporterTrend: -12);
      expect(action?.target, NextActionTarget.ownerWork);
      expect(action?.message, contains('オーナー室'));
    });
  });

  group('4 最初に手を付けること', () {
    test('開幕前は、スタッフ・スポンサー・オーナーの目標を先に挙げる', () async {
      final gs = await newGame();
      final all =
          NextActionAdvisor.all(gs.save!, gs.userTeam, includeSetup: true);
      expect(all.first.target, NextActionTarget.staff);
      expect(all.first.message, contains('7役中0人'));
      expect(all.map((a) => a.target),
          containsAll([NextActionTarget.finance, NextActionTarget.ownerGoal]));
    });

    test('カップ戦の札は、試合の日が近いときだけ出す', () async {
      final gs = await newGame();
      final d = gs.userDomesticCupDate;
      if (gs.isUserDomesticCupMatchSoon) {
        expect(d, isNotNull);
        expect(d!.difference(gs.today).inDays, lessThanOrEqualTo(7));
      } else if (d != null) {
        expect(d.difference(gs.today).inDays, greaterThan(7),
            reason: '開幕前の7月に、何週も先のカップ戦の札が出ていた');
      }
    });

    test('開幕前は順位で語らない', () async {
      final gs = await newGame();
      expect(gs.isPreseason, isTrue);
      final r = ManagerReportEngine.build(
        rank: 1,
        teamCount: 24,
        tier: 3,
        supporter: 60,
        shareholder: 60,
        budget: 1000,
        weeklyNet: 10,
        targetRank: 17,
        preseason: true,
      );
      expect(r.headline, contains('開幕前'));
    });
  });

  group('6・7 季の結果のまとめと切り替えの給与', () {
    test('開始レポートの先頭に、順位・2つの期待・お金・来季が並ぶ', () async {
      final gs = await newGame();
      loseEverything(gs);
      final s = gs.save!;
      s.clubVision = ClubVision.none;
      s.confidence = 46;
      s.budget = 100000000;
      final teams = s.league.teams.length;
      await gs.startNextSeason();
      final lines = gs.lastSeasonResultLines!;
      expect(lines.first, contains('$teams位'));
      // 季末の -10 のほかに、季の締めで出来事などの小さな増減が乗ることが
      // ある(CI で 46→26 以外が出た)。前の値と矢印が出ていることを見る。
      expect(lines.any((l) => l.contains('サポーターの期待 46→')), isTrue,
          reason: lines.join(' / '));
      expect(lines.any((l) => l.contains('株主の期待')), isTrue);
      expect(lines.any((l) => l.contains('1年の資金の増減')), isTrue);
      expect(lines.any((l) => l.contains('来季: 3部')), isTrue);
      expect(lines.any((l) => l.contains('降格はありません')), isTrue,
          reason: '3部の最下位は降格しないことを一言');
      expect(lines.any((l) => l.contains('給与')), isTrue,
          reason: '切り替えで引かれた給与を1行で出す');
    });

    test('切り替えの給与で赤字になりそうなら、急ぎで知らせる', () async {
      final gs = await newGame();
      loseEverything(gs);
      final s = gs.save!;
      s.budget = 1;
      final short = gs.rolloverShortfall;
      expect(short, isNotNull);
      final action =
          NextActionAdvisor.top(s, gs.userTeam, rolloverShortfall: short);
      expect(action?.urgent, isTrue);
      expect(action?.target, NextActionTarget.finance);
    });
  });

  group('8 決めごとの締切', () {
    test('噂は締切を過ぎると「コメントしない」で片付く', () async {
      final gs = await newGame();
      gs.debugRaiseRumor();
      expect(gs.save!.pendingRumor, isNotNull);
      for (var i = 0; i < GameStateDecisions.decisionDeadlineMatchdays; i++) {
        await gs.debugTickDecisionDeadlines();
      }
      expect(gs.save!.pendingRumor, isNull);
      expect(gs.lastAutoDecisions.join(), contains('コメントしない'));
    });

    test('スポンサーは締切を過ぎると、週の収入がいちばん多い話を結ぶ', () async {
      final gs = await newGame();
      final s = gs.save!;
      s.sponsorDeal = null;
      s.pendingSponsorOffers = [
        SponsorDeal(name: 'A社', weeklyIncome: 10, yearsRemaining: 2),
        SponsorDeal(name: 'B社', weeklyIncome: 30, yearsRemaining: 1),
        SponsorDeal(name: 'C社', weeklyIncome: 20, yearsRemaining: 3),
      ];
      for (var i = 0; i < GameStateDecisions.decisionDeadlineMatchdays; i++) {
        expect(s.sponsorDeal, isNull);
        await gs.debugTickDecisionDeadlines();
      }
      expect(s.sponsorDeal?.name, 'B社');
      expect(gs.lastAutoDecisions.single, contains('B社'));
    });

    test('手術の判断は答えを待つものに数え、締切で医療スタッフのおすすめに従う', () async {
      final gs = await newGame();
      final s = gs.save!;
      s.budget = 100000000;
      final p = gs.userTeam.players.first;
      p.injuryType = InjuryType.acl;
      p.injuryWeeks = 20;
      gs.debugReviewInjuries();
      expect(gs.playersAwaitingSurgeryDecision, contains(p));
      expect(gs.inboxActions.any((a) => a.contains(p.name)), isTrue);
      expect(gs.recommendsSurgery(p), isTrue, reason: '長期の怪我は手術');
      for (var i = 0; i < GameStateDecisions.decisionDeadlineMatchdays; i++) {
        await gs.debugTickDecisionDeadlines();
      }
      expect(s.injuryPlans[p.id], 'surgery');
      expect(gs.lastAutoDecisions.join(), contains(p.name));
    });

    test('締切の前に答えれば、数えた経過は消える', () async {
      final gs = await newGame();
      gs.debugRaiseRumor();
      await gs.debugTickDecisionDeadlines();
      expect(gs.save!.decisionAges['rumor'], 1);
      expect(gs.decisionMatchdaysLeft('rumor'),
          GameStateDecisions.decisionDeadlineMatchdays - 1);
      await gs.answerRumor(RumorAnswer.deny);
      await gs.debugTickDecisionDeadlines();
      expect(gs.save!.decisionAges.containsKey('rumor'), isFalse);
    });

    test('セーブに残る', () async {
      final gs = await newGame();
      final s = gs.save!;
      s.decisionAges['rumor'] = 2;
      s.supporterTrail.addAll([60, 50]);
      s.supporterMoves.add(['-12', '中間レビュー']);
      final back = s.toJson();
      expect(back['decisionAges'], {'rumor': 2});
      expect(back['supporterMoves'], [
        ['-12', '中間レビュー']
      ]);
    });
  });
}
