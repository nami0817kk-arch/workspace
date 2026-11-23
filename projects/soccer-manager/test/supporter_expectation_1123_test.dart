// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/logic/board_engine.dart';
import 'package:soccer_manager/models/club_infrastructure.dart';
import 'package:soccer_manager/models/owner_legacy.dart';
import 'package:soccer_manager/models/owner_work.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';

/// サポーターの期待の作り直し(2026-11-23)。
///
/// 増減を1か所に集めて月の内訳を残す / 試合の結果は月末にまとめる /
/// オーナーの手(チケット・広報・地域・補強・売却・スタジアム)を主な
/// 動かし手にする / 10を割ったら最後通告と3か月の猶予。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Tr.language = AppLanguage.japanese;
  });
  tearDown(() => Tr.language = AppLanguage.system);

  Future<GameState> newGame() async {
    final gs = GameState();
    await gs.startNewGame('期待FC');
    return gs;
  }

  group('月末のまとめの計算', () {
    test('その月にリーグ戦が無ければ動かない', () {
      expect(
          BoardEngine.monthlyResultDelta(
              rank: 24, targetRank: 1, points: 0, games: 0),
          0);
    });

    test('目標ちょうどで勝点1/試合なら0、戦力どおり(目標の2つ上)なら+1', () {
      expect(
          BoardEngine.monthlyResultDelta(
              rank: 10, targetRank: 10, points: 4, games: 4),
          0);
      expect(
          BoardEngine.monthlyResultDelta(
              rank: 8, targetRank: 10, points: 4, games: 4),
          1);
    });

    test('上下とも6で止まる', () {
      expect(
          BoardEngine.monthlyResultDelta(
              rank: 1, targetRank: 12, points: 12, games: 4),
          BoardEngine.monthlyResultCap);
      expect(
          BoardEngine.monthlyResultDelta(
              rank: 24, targetRank: 8, points: 0, games: 4),
          -BoardEngine.monthlyResultCap);
    });

    test('順位の分と成績の分は、それぞれ -3〜+3', () {
      for (var gap = -20; gap <= 20; gap++) {
        final p = BoardEngine.monthlyRankPart(rank: 12 - gap, targetRank: 12);
        expect(p, inInclusiveRange(-3, 3));
      }
      expect(BoardEngine.monthlyFormPart(points: 0, games: 5), -3);
      expect(BoardEngine.monthlyFormPart(points: 15, games: 5), 3);
      // 勝点の取り方が良いほど、下がらない。
      var prev = -99;
      for (var pts = 0; pts <= 15; pts++) {
        final v = BoardEngine.monthlyFormPart(points: pts, games: 5);
        expect(v, greaterThanOrEqualTo(prev));
        prev = v;
      }
    });

    test('中間レビューと季末は目標との差に比例し、下がる幅は最大 -10', () {
      expect(
          BoardEngine.midSeasonReviewDelta(currentRank: 4, targetRank: 4), 2);
      expect(
          BoardEngine.midSeasonReviewDelta(currentRank: 2, targetRank: 4), 6);
      expect(BoardEngine.midSeasonReviewDelta(currentRank: 24, targetRank: 4),
          -10);
      expect(
          BoardEngine.confidenceDeltaForSeasonEnd(finalRank: 4, targetRank: 4),
          3);
      expect(
          BoardEngine.confidenceDeltaForSeasonEnd(finalRank: 1, targetRank: 10),
          15);
      expect(
          BoardEngine.confidenceDeltaForSeasonEnd(finalRank: 24, targetRank: 4),
          -10);
    });
  });

  group('増減の記録', () {
    test('理由ごとに今月の内訳へ積み、0〜100 に収めた量を記録する', () async {
      final gs = await newGame();
      final s = gs.save!;
      s.confidence = 50;
      s.supporterMonth.clear();
      gs.debugChangeSupporters(3, SupporterReason.pr);
      gs.debugChangeSupporters(-2, SupporterReason.results);
      gs.debugChangeSupporters(1, SupporterReason.pr);
      expect(s.confidence, 52);
      expect(s.supporterMonth, {'pr': 4, 'results': -2});
      s.confidence = 99;
      gs.debugChangeSupporters(5, SupporterReason.stadium);
      expect(s.confidence, 100);
      expect(s.supporterMonth['stadium'], 1, reason: '実際に動いた量だけ');
    });

    test('月を締めると前の月の内訳になり、受信箱に1行出る', () async {
      final gs = await newGame();
      final s = gs.save!;
      s.confidence = 50;
      s.communityLevel = 0;
      s.supporterMonth
        ..clear()
        ..addAll({'pr': 3, 'results': -2, 'tickets': -1});
      final news = s.newsLog.length;
      gs.debugCloseSupporterMonth(DateTime(2026, 2, 28));
      expect(s.supporterMonth, isEmpty);
      expect(s.supporterLastMonth, {'pr': 3, 'results': -2, 'tickets': -1});
      expect(gs.lastMonthSupporterTotal, 0);
      final line = gs.lastMonthSupporterLine!;
      expect(line, contains('2月'));
      expect(line, contains('広報 +3'));
      expect(line, contains('結果 -2'));
      expect(line, contains('チケット -1'));
      expect(s.newsLog.length, news + 1);
      expect(s.newsLog.first.text, line);
      expect(s.supporterMonthEnds.last, 50);
    });

    test('英語でも内訳が出る', () async {
      final gs = await newGame();
      final s = gs.save!;
      s.communityLevel = 0;
      s.supporterMonth
        ..clear()
        ..addAll({'pr': 4, 'results': -2});
      gs.debugCloseSupporterMonth(DateTime(2026, 3, 31));
      Tr.language = AppLanguage.english;
      final line = gs.lastMonthSupporterLine!;
      expect(line, contains('Supporter expectation in March: +2'));
      expect(line, contains('PR +4'));
      expect(line, contains('results -2'));
    });
  });

  group('月末: 結果・チケット・地域活動', () {
    test('その月の勝点と順位で結果を動かし、数えた勝点は0に戻す', () async {
      final gs = await newGame();
      final s = gs.save!;
      s.confidence = 50;
      s.communityLevel = 0;
      s.ticketPricing = TicketPricing.standard;
      s.supporterMonthGames = 4;
      s.supporterMonthPoints = 0;
      // 目標1位なら、順位の分は0以下。
      s.boardTargetRank = 1;
      final expected = gs.monthlyResultDeltaNow;
      expect(expected, lessThan(0), reason: '4戦全敗');
      gs.debugCloseSupporterMonth(DateTime(2026, 9, 30));
      expect(s.confidence, 50 + expected);
      expect(s.supporterLastMonth['results'], expected);
      expect(s.supporterMonthGames, 0);
      expect(s.supporterMonthPoints, 0);
    });

    test('チケット: 安い+2・普通0・高い-2(試合のある月だけ)', () async {
      for (final (pricing, d) in [
        (TicketPricing.budget, 2),
        (TicketPricing.standard, 0),
        (TicketPricing.premium, -2),
      ]) {
        expect(BoardEngine.ticketMonthlyDelta(pricing), d);
        final gs = await newGame();
        final s = gs.save!;
        s.confidence = 50;
        s.communityLevel = 0;
        s.ticketPricing = pricing;
        // 勝点1/試合・目標ちょうどの辺りでも、結果の分は別に積まれる。
        s.supporterMonthGames = 3;
        s.supporterMonthPoints = 3;
        gs.debugCloseSupporterMonth(DateTime(2026, 10, 31));
        expect(s.supporterLastMonth['tickets'] ?? 0, d, reason: pricing.name);
      }
      // 試合の無い月は、値段を変えても動かない。
      final gs = await newGame();
      gs.save!
        ..ticketPricing = TicketPricing.budget
        ..communityLevel = 0
        ..supporterMonthGames = 0;
      gs.debugCloseSupporterMonth(DateTime(2026, 7, 31));
      expect(gs.save!.supporterLastMonth, isEmpty);
    });

    test('地域活動を続けている間は毎月+1', () async {
      final gs = await newGame();
      final s = gs.save!;
      s.confidence = 50;
      s.communityLevel = 1;
      s.supporterMonthGames = 0;
      gs.debugCloseSupporterMonth(DateTime(2026, 7, 31));
      expect(s.confidence, 51);
      expect(s.supporterLastMonth, {'community': 1});
      s.communityLevel = 0;
      gs.debugCloseSupporterMonth(DateTime(2026, 8, 31));
      expect(s.confidence, 51);
    });

    test('日付を進めると、またいだ月末ごとに締める', () async {
      final gs = await newGame();
      final s = gs.save!;
      s.communityLevel = 1;
      final start = gs.today;
      final before = s.confidence;
      gs.debugAdvanceTodayTo(DateTime(start.year, start.month + 2, 15));
      expect(s.supporterMonthEnds.length, 2);
      expect(s.confidence, greaterThanOrEqualTo(before + 2 - 0));
      expect(
          s.supporterLastMonthKey,
          GameStateSupporters.monthKeyOf(
              DateTime(start.year, start.month + 1)));
    });
  });

  group('オーナーの手', () {
    test('広報・ファンの手は月に1回(どれか1つ)。翌月にはまた打てる', () async {
      final gs = await newGame();
      final s = gs.save!;
      s.budget = 500000;
      s.confidence = 50;
      s.supporterMonth.clear();
      final dinner = ownerWorks.firstWhere((w) => w.id == 'supporter_dinner');
      final clinic = ownerWorks.firstWhere((w) => w.id == 'kids_clinic');
      expect(dinner.monthly, isTrue);
      expect(await gs.doOwnerWork(dinner.id), isTrue);
      expect(s.confidence, 50 + dinner.supporters);
      expect(s.supporterMonth['pr'], dinner.supporters);
      expect(gs.fanWorkDoneThisMonth, isTrue);
      expect(gs.canDoOwnerWork(clinic), isFalse, reason: '同じ月に2つ目');
      final t = gs.today;
      gs.debugAdvanceTodayTo(DateTime(t.year, t.month + 1, 2));
      expect(gs.fanWorkDoneThisMonth, isFalse);
      expect(gs.canDoOwnerWork(dinner), isTrue, reason: '翌月はまた打てる');
    });

    test('広報・ファンの手の期待は +2〜6、ほかの分野は今までどおり1季に1回', () async {
      // 資金0の会見だけ +2(続けて打つと減る。2026-11-23)。ほかは +3〜6。
      for (final w in ownerWorks.where((w) => w.monthly)) {
        expect(w.supporters, inInclusiveRange(w.funds == 0 ? 2 : 3, 6),
            reason: w.id);
        expect(w.funds, lessThanOrEqualTo(0), reason: w.id);
      }
      final gs = await newGame();
      gs.save!.budget = 500000;
      final school = ownerWorks.firstWhere((w) => w.id == 'school_visit');
      expect(school.monthly, isFalse);
      expect(await gs.doOwnerWork(school.id), isTrue);
      expect(gs.save!.supporterMonth['community'], school.supporters);
      final t = gs.today;
      gs.debugAdvanceTodayTo(DateTime(t.year, t.month + 1, 2));
      expect(gs.canDoOwnerWork(school), isFalse, reason: '1季に1回のまま');
    });

    test('主力級(上位3人)を獲ると+3、控えなら動かない', () async {
      final gs = await newGame();
      final s = gs.save!;
      s.confidence = 50;
      final team = gs.userTeam;
      final sorted = [...team.players]
        ..sort((a, b) => b.overall.compareTo(a.overall));
      final star = sorted.first;
      final bench = sorted.last;
      team.players.remove(star);
      gs.debugSupportersOnSigning(star);
      expect(s.confidence, 50 + BoardEngine.bigSigningDelta);
      expect(s.supporterMonth['signings'], BoardEngine.bigSigningDelta);
      team.players.remove(bench);
      gs.debugSupportersOnSigning(bench);
      expect(s.confidence, 50 + BoardEngine.bigSigningDelta);
    });

    test('人気の選手を売ると -3〜-6(上位・長く在籍・生え抜きの数で)', () async {
      expect(
          BoardEngine.saleDelta(
              topPlayer: false, longServing: false, academy: false),
          0);
      expect(
          BoardEngine.saleDelta(
              topPlayer: true, longServing: false, academy: false),
          -3);
      expect(
          BoardEngine.saleDelta(
              topPlayer: true, longServing: true, academy: false),
          -5);
      expect(
          BoardEngine.saleDelta(
              topPlayer: true, longServing: true, academy: true),
          -6);
      final gs = await newGame();
      final s = gs.save!;
      s.confidence = 50;
      final team = gs.userTeam;
      final sorted = [...team.players]
        ..sort((a, b) => b.overall.compareTo(a.overall));
      final star = sorted.first;
      star.academyGraduate = true;
      s.clubApps[star.id] = BoardEngine.longServingApps;
      team.players.remove(star);
      gs.debugSupportersOnSale(star);
      expect(s.confidence, 44);
      expect(s.supporterMonth['sales'], -6);
      // 控えの若手(印なし)は動かない。
      final bench = sorted.last..academyGraduate = false;
      s.clubApps.remove(bench.id);
      team.players.remove(bench);
      gs.debugSupportersOnSale(bench);
      expect(s.confidence, 44);
    });

    test('スタジアムの増築が完成すると+5', () async {
      final gs = await newGame();
      final s = gs.save!;
      s.confidence = 50;
      s.communityLevel = 0;
      final t = gs.today;
      s.infrastructure.construction[FacilityType.stadium] =
          t.add(const Duration(days: 1));
      gs.debugAdvanceTodayTo(t.add(const Duration(days: 2)));
      expect(s.supporterMonth['stadium'], BoardEngine.stadiumCompletedDelta);
    });
  });

  group('最後通告と3か月の猶予', () {
    test('10を割ると最後通告。戻せば取り下げられ、手放さない', () async {
      final gs = await newGame();
      final s = gs.save!;
      s.confidence = 15;
      s.communityLevel = 0;
      gs.debugChangeSupporters(-8, SupporterReason.results);
      expect(s.confidence, 7);
      expect(gs.isUnderSupporterUltimatum, isTrue);
      expect(gs.supporterUltimatumDaysLeft, GameStateSupporters.ultimatumDays);
      expect(gs.saleReason, isNull, reason: '猶予のうちは手放さない');
      expect(s.newsLog.first.text, contains('最後通告'));
      final t = gs.today;
      gs.debugAdvanceTodayTo(t.add(const Duration(days: 40)));
      expect(gs.supporterUltimatumDaysLeft,
          lessThan(GameStateSupporters.ultimatumDays));
      gs.debugChangeSupporters(4, SupporterReason.pr);
      expect(s.confidence, greaterThanOrEqualTo(10));
      expect(s.supporterUltimatumUntil, isNull);
      expect(gs.isUnderSupporterUltimatum, isFalse);
      gs.debugAdvanceTodayTo(t.add(const Duration(days: 120)));
      expect(gs.saleReason, isNull);
    });

    test('3か月のうちに戻せなければ手放す', () async {
      final gs = await newGame();
      final s = gs.save!;
      s.confidence = 12;
      s.communityLevel = 0;
      gs.debugChangeSupporters(-6, SupporterReason.results);
      final t = gs.today;
      gs.debugAdvanceTodayTo(t.add(const Duration(days: 60)));
      expect(gs.saleReason, isNull);
      gs.debugAdvanceTodayTo(
          t.add(const Duration(days: GameStateSupporters.ultimatumDays)));
      expect(gs.saleReason, SaleReason.supporters);
      expect(gs.isDismissed, isTrue);
    });

    test('0になっても、猶予のうちは手放さない', () async {
      final gs = await newGame();
      final s = gs.save!;
      s.confidence = 5;
      gs.debugChangeSupporters(-20, SupporterReason.events);
      expect(s.confidence, 0);
      expect(gs.saleReason, isNull);
      expect(gs.isDismissed, isFalse);
    });

    test('今週の決断と受信箱の先頭に出る(ただし節を進める妨げにはしない)', () async {
      final gs = await newGame();
      final s = gs.save!;
      s.confidence = 12;
      gs.debugChangeSupporters(-5, SupporterReason.results);
      expect(gs.supporterUltimatumDaysLeft, isNotNull);
      expect(gs.inboxActions.any((a) => a.contains('最後通告')), isFalse);
    });

    test('最後通告は保存して読み戻せる', () async {
      final gs = await newGame();
      final s = gs.save!;
      s.confidence = 12;
      gs.debugChangeSupporters(-5, SupporterReason.results);
      final back = SaveGame.fromJson(
          jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>);
      expect(back.supporterUltimatumUntil, s.supporterUltimatumUntil);
    });
  });

  group('古いセーブ', () {
    test('新しい項目が無くても今の値のまま読め、月末から新しい仕組みに乗る', () async {
      final gs = await newGame();
      final s = gs.save!;
      s.confidence = 5;
      final json = jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>;
      for (final k in [
        'supporterMonth',
        'supporterLastMonth',
        'supporterLastMonthKey',
        'supporterMonthEnds',
        'supporterMonthPoints',
        'supporterMonthGames',
        'fanWorkMonthKey',
        'supporterUltimatumUntil',
      ]) {
        json.remove(k);
      }
      final old = SaveGame.fromJson(json);
      expect(old.confidence, 5);
      expect(old.supporterMonth, isEmpty);
      expect(old.supporterLastMonth, isEmpty);
      expect(old.supporterLastMonthKey, 0);
      expect(old.supporterMonthEnds, isEmpty);
      expect(old.supporterMonthGames, 0);
      expect(old.fanWorkMonthKey, 0);
      expect(old.supporterUltimatumUntil, isNull);

      // 0〜9 のまま読んだセーブも、すぐには手放さない。月末に最後通告が付く。
      expect(gs.saleReason, isNull);
      s.communityLevel = 0;
      s.supporterUltimatumUntil = null;
      gs.debugCloseSupporterMonth(DateTime(2026, 7, 31));
      expect(gs.isUnderSupporterUltimatum, isTrue);
      expect(gs.saleReason, isNull);
    });

    test('内訳と月の控えは保存して読み戻せる', () async {
      final gs = await newGame();
      final s = gs.save!;
      s.supporterMonth['pr'] = 4;
      s.supporterLastMonth['results'] = -3;
      s.supporterLastMonthKey =
          GameStateSupporters.monthKeyOf(DateTime(2026, 9));
      s.supporterMonthEnds.addAll([40, 35]);
      s.supporterMonthPoints = 7;
      s.supporterMonthGames = 4;
      s.fanWorkMonthKey = 123;
      final back = SaveGame.fromJson(
          jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>);
      expect(back.supporterMonth, {'pr': 4});
      expect(back.supporterLastMonth, {'results': -3});
      expect(back.supporterLastMonthKey, s.supporterLastMonthKey);
      expect(back.supporterMonthEnds, [40, 35]);
      expect(back.supporterMonthPoints, 7);
      expect(back.supporterMonthGames, 4);
      expect(back.fanWorkMonthKey, 123);
    });
  });

  group('試合', () {
    test('リーグ戦の後は勝点を数えるだけで、ふつうの試合ではその場で動かない', () async {
      final gs = await newGame();
      final s = gs.save!;
      s.rivalTeamId = null;
      final r = await gs.playNextMatchdayQuickSim();
      expect(r, isNotNull);
      expect(s.supporterMonthGames, 1);
      expect(s.supporterMonthPoints, anyOf(0, 1, 3));
      expect(s.supporterMonth['results'] ?? 0, 0,
          reason: '1試合ごとの ±3 はやめた(月末にまとめる)');
    });

    test('ダービーはその場で ±4', () {
      expect(BoardEngine.derbyDelta, 4);
    });
  });
}
