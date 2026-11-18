import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/logic/economy_scale.dart';
import 'package:soccer_manager/logic/money_calendar.dart';
import 'package:soccer_manager/models/league_theme.dart';
import 'package:soccer_manager/models/ledger.dart';
import 'package:soccer_manager/state/game_state.dart';

/// お金が動く日(会計年度・月末の給与・年4回の放映権・祝日の客)の検査。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('暦の決まり', () {
    test('会計年度は7月1日で切り替わる', () {
      expect(MoneyCalendar.fiscalSeasonOf(DateTime(2026, 7, 1)), 1);
      expect(MoneyCalendar.fiscalSeasonOf(DateTime(2027, 6, 30)), 1);
      expect(MoneyCalendar.fiscalSeasonOf(DateTime(2027, 7, 1)), 2);
      expect(MoneyCalendar.fiscalYearLabel(1), '2026/27');
      expect(MoneyCalendar.fiscalYearEnd(1), DateTime(2027, 6, 30));
    });

    test('1年度の月末は12回、放映権の入金は4回', () {
      final start = DateTime(2026, 6, 30);
      final end = DateTime(2027, 6, 30);
      final ends = MoneyCalendar.monthEndsBetween(start, end);
      expect(ends, hasLength(12));
      expect(ends.first, DateTime(2026, 7, 31));
      expect(ends.last, DateTime(2027, 6, 30));
      expect(ends, contains(DateTime(2027, 2, 28)));
      expect(MoneyCalendar.broadcastDatesBetween(start, end), hasLength(4));
    });

    test('12か月の給与の合計は年俸(週俸×52)とほぼ一致する', () {
      for (final weekly in [7, 100, 12345, 99999]) {
        final year = MoneyCalendar.monthlyFromWeekly(weekly) * 12;
        expect((year - weekly * 52).abs(), lessThanOrEqualTo(12));
      }
    });

    test('放映権の4回の合計は年額と必ず一致する', () {
      for (final annual in [2000, 10001, 40003, 2500000]) {
        final sum = [
          for (var i = 0; i < 4; i++)
            MoneyCalendar.broadcastInstallment(annual, i)
        ].reduce((a, b) => a + b);
        expect(sum, annual);
      }
    });

    test('祝日は国ごとに違う', () {
      expect(MoneyCalendar.easterSunday(2027), DateTime(2027, 3, 28));
      expect(MoneyCalendar.easterSunday(2026), DateTime(2026, 4, 5));
      final boxing = DateTime(2026, 12, 26);
      expect(MoneyCalendar.isHoliday(boxing, LeagueTheme.england), isTrue);
      expect(MoneyCalendar.isHoliday(boxing, LeagueTheme.spain), isFalse);
      expect(MoneyCalendar.isHoliday(DateTime(2026, 10, 3), LeagueTheme.germany),
          isTrue);
      expect(MoneyCalendar.isHoliday(DateTime(2027, 7, 14), LeagueTheme.france),
          isTrue);
      expect(MoneyCalendar.isHoliday(DateTime(2027, 3, 29), LeagueTheme.italy),
          isTrue,
          reason: '復活祭の月曜');
      expect(MoneyCalendar.isHoliday(DateTime(2026, 9, 12), LeagueTheme.italy),
          isFalse);
    });

    test('祝日の客は増えるが、収容人数は超えない', () {
      expect(MoneyCalendar.holidayAttendance(10000, 20000), 11500);
      expect(MoneyCalendar.holidayAttendance(19000, 20000), 20000);
    });
  });

  group('ゲームの中のお金の日', () {
    test('月末に給与を払い、8月1日に放映権の1回目が入る', () async {
      final gs = GameState();
      await gs.startNewGame('暦FC');
      expect(gs.today, DateTime(2026, 7, 1));
      final wages = gs.monthlyPlayerWageCost + gs.monthlyStaffWageCost;
      expect(wages, greaterThan(0));

      final budget = gs.save!.budget;
      gs.debugAdvanceTodayTo(DateTime(2026, 7, 30));
      expect(gs.save!.budget, budget, reason: '月末の前は払わない');

      gs.debugAdvanceTodayTo(DateTime(2026, 7, 31));
      expect(gs.save!.budget, budget - wages);
      expect(-gs.currentLedger.of(LedgerCategory.playerWages),
          gs.monthlyPlayerWageCost);

      gs.debugAdvanceTodayTo(DateTime(2026, 8, 1));
      final first = MoneyCalendar.broadcastInstallment(
          annualBroadcast(gs.currentDivisionTier), 0);
      expect(first, greaterThan(0));
      expect(gs.save!.budget, budget - wages + first);
      expect(gs.currentLedger.of(LedgerCategory.broadcast), first);
    });

    test('試合の日には給与も放映権も動かない(観客・スポンサー・グッズだけ)',
        () async {
      final gs = GameState();
      await gs.startNewGame('暦FC');
      // 第1節の前日まで進めて、月末と入金日を済ませておく。
      final firstDay = gs.dateOfMatchday(1);
      gs.debugAdvanceTodayTo(firstDay.subtract(const Duration(days: 1)));
      final wagesBefore = gs.currentLedger.of(LedgerCategory.playerWages);
      final broadcastBefore = gs.currentLedger.of(LedgerCategory.broadcast);
      await gs.playNextMatchdayQuickSim();
      expect(gs.today, firstDay);
      expect(gs.currentLedger.of(LedgerCategory.playerWages), wagesBefore);
      expect(gs.currentLedger.of(LedgerCategory.broadcast), broadcastBefore);
      expect(gs.currentLedger.of(LedgerCategory.gate), greaterThan(0));
    });

    test('5・6月の給与は、次のシーズンへ進む前に今季の年度で払う', () async {
      final gs = GameState();
      await gs.startNewGame('暦FC');
      while (gs.save!.league.nextUnplayedFixture != null) {
        await gs.playNextMatchdayQuickSim();
      }
      final season = gs.save!.league.season;
      final lastDay = gs.today;
      final remaining = MoneyCalendar.monthEndsBetween(
              lastDay, MoneyCalendar.fiscalYearEnd(season))
          .length;
      expect(remaining, greaterThanOrEqualTo(1), reason: '最終節は5月');
      final player = gs.monthlyPlayerWageCost;
      final before = gs.save!.ledgerFor(season).of(LedgerCategory.playerWages);

      await gs.startNextSeason();

      expect(gs.save!.league.season, season + 1);
      expect(gs.today, MoneyCalendar.fiscalYearStart(season + 1));
      expect(gs.save!.ledgerFor(season).of(LedgerCategory.playerWages),
          before - player * remaining);
      expect(gs.save!.ledgerFor(season + 1).of(LedgerCategory.playerWages), 0,
          reason: '7月1日の時点で新しい年度にはまだ給与が無い');
    });

    test('祝日の節は、入金の予定に客が増える印が付き、収入の見込みが減らない',
        () async {
      final gs = GameState();
      await gs.startNewGame('暦FC', theme: LeagueTheme.england);
      final cal = gs.seasonCalendar;
      final holidayMd = [
        for (var i = 0; i < cal.matchdayDates.length; i++)
          if (MoneyCalendar.isHoliday(cal.matchdayDates[i], LeagueTheme.england))
            i + 1
      ];
      expect(holidayMd, isNotEmpty, reason: 'ボクシング・デーと元日に節がある');
      final md = holidayMd.first;
      expect(gs.holidayOfMatchday(md), isNotNull);
      final plain = [
        for (var i = 1; i <= cal.matchdayDates.length; i++)
          if (gs.holidayOfMatchday(i) == null) i
      ].first;
      expect(gs.expectedMatchdayIncome(md),
          greaterThanOrEqualTo(gs.expectedMatchdayIncome(plain)));
    });

    test('入出金の予定は日付の順で、給与日と放映権を含む', () async {
      final gs = GameState();
      await gs.startNewGame('暦FC');
      final items = gs.upcomingMoneyDates(count: 10);
      expect(items, isNotEmpty);
      for (var i = 1; i < items.length; i++) {
        expect(items[i].date.isBefore(items[i - 1].date), isFalse);
      }
      expect(items.any((e) => e.date == DateTime(2026, 7, 31) && e.amount < 0),
          isTrue);
      expect(items.any((e) => e.date == DateTime(2026, 8, 1) && e.amount > 0),
          isTrue);
    });
  });
}
