import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/logic/calendar_engine.dart';
import 'package:soccer_manager/logic/season_calendar.dart';
import 'package:soccer_manager/models/league_theme.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 各国・各部の節数(ホーム&アウェイの総当たり)。
Iterable<(LeagueTheme, int)> _allLeagueShapes() sync* {
  for (final theme in LeagueTheme.values) {
    for (final teams in theme.teamsByTier.toSet()) {
      yield (theme, (teams - 1) * 2);
    }
  }
}

const _seasons = [1, 2, 3, 4, 5, 6, 7, 8];

bool _isWeekday(DateTime d) =>
    d.weekday >= DateTime.monday && d.weekday <= DateTime.friday;

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Tr.language = AppLanguage.japanese;
  });
  tearDown(() => Tr.language = AppLanguage.system);

  group('SeasonCalendar の日程', () {
    test('全節の日付が昇順で、節の数だけある', () {
      for (final (theme, total) in _allLeagueShapes()) {
        for (final season in _seasons) {
          final cal = SeasonCalendar.build(
              season: season, theme: theme, totalMatchdays: total);
          expect(cal.matchdayDates.length, total,
              reason: '${theme.name} $total節 第$season季');
          for (var i = 1; i < total; i++) {
            expect(cal.matchdayDates[i].isAfter(cal.matchdayDates[i - 1]),
                isTrue,
                reason: '${theme.name} $total節 第$season季 第${i + 1}節');
          }
        }
      }
    });

    test('8月に開幕し、46節ある部も含めて5月31日までに終わる', () {
      for (final (theme, total) in _allLeagueShapes()) {
        for (final season in _seasons) {
          final y = SeasonCalendar.startYear(season);
          final cal = SeasonCalendar.build(
              season: season, theme: theme, totalMatchdays: total);
          expect(cal.firstMatchDate.year, y);
          expect(cal.firstMatchDate.month, 8,
              reason: '${theme.name} $total節 第$season季');
          expect(cal.lastMatchDate.isAfter(DateTime(y + 1, 5, 31)), isFalse,
              reason: '${theme.name} $total節 第$season季 '
                  '最終節 ${cal.lastMatchDate}');
          // 5月の終わりまで使う(シーズンが途中で終わらない)。
          expect(cal.lastMatchDate.isBefore(DateTime(y + 1, 5, 1)), isFalse,
              reason: '${theme.name} $total節 第$season季 '
                  '最終節 ${cal.lastMatchDate}');
        }
      }
    });

    test('代表ウィーク(9・10・11・3月)にリーグ戦が無い', () {
      for (final (theme, total) in _allLeagueShapes()) {
        for (final season in _seasons) {
          final cal = SeasonCalendar.build(
              season: season, theme: theme, totalMatchdays: total);
          final window = SeasonCalendar.internationalWindowDays(season);
          final months = {
            for (final s in SeasonCalendar.internationalSaturdays(season))
              s.month,
          };
          expect(months, {9, 10, 11, 3});
          for (final d in cal.matchdayDates) {
            expect(window.contains(d), isFalse,
                reason: '${theme.name} $total節 第$season季 $d');
          }
        }
      }
    });

    test('リーグ戦は週末(土曜)が中心。平日は年末年始と、節の多い部の火曜だけ', () {
      for (final (theme, total) in _allLeagueShapes()) {
        for (final season in _seasons) {
          final cal = SeasonCalendar.build(
              season: season, theme: theme, totalMatchdays: total);
          final festive = theme == LeagueTheme.england
              ? SeasonCalendar.festiveDates(season).toSet()
              : <DateTime>{};
          final saturdays =
              cal.matchdayDates.where((d) => d.weekday == DateTime.saturday);
          expect(saturdays.length / total, greaterThanOrEqualTo(0.8),
              reason: '${theme.name} $total節 第$season季');
          for (final d in cal.matchdayDates) {
            if (d.weekday == DateTime.saturday || festive.contains(d)) continue;
            expect(d.weekday, anyOf(DateTime.tuesday, DateTime.wednesday),
                reason: '${theme.name} $total節 第$season季 $d');
          }
        }
      }
    });

    test('イングランドは12/26・12/29・1/1に詰め、ドイツはウィンターブレークで休む', () {
      for (final season in _seasons) {
        final y = SeasonCalendar.startYear(season);
        for (final total in [38, 46]) {
          final eng = SeasonCalendar.build(
              season: season, theme: LeagueTheme.england, totalMatchdays: total);
          for (final d in SeasonCalendar.festiveDates(season)) {
            expect(eng.matchdayDates, contains(d),
                reason: 'イングランド $total節 第$season季 $d');
          }
        }
        final ger = SeasonCalendar.build(
            season: season, theme: LeagueTheme.germany, totalMatchdays: 34);
        for (final d in ger.matchdayDates) {
          final inBreak = !d.isBefore(DateTime(y, 12, 21)) &&
              !d.isAfter(DateTime(y + 1, 1, 14));
          expect(inBreak, isFalse, reason: 'ドイツ 第$season季 $d');
        }
      }
    });

    test('国内カップ・大陸大会は前後の節のあいだの平日で、代表ウィークを避ける', () {
      for (final (theme, total) in _allLeagueShapes()) {
        for (final season in [1, 2, 5]) {
          final cal = SeasonCalendar.build(
              season: season, theme: theme, totalMatchdays: total);
          final window = SeasonCalendar.internationalWindowDays(season);
          for (var md = 1; md <= total + 1; md++) {
            for (final continental in [false, true]) {
              final d = cal.cupDateBefore(md, continental: continental);
              final why = '${theme.name} $total節 第$season季 第$md節の前 $d';
              // 前後の節のあいだに平日があれば必ず平日(年末年始の連戦で
              // 土日しか空かない年だけは週末になる)。
              final prev = cal.dateForMatchday(md - 1);
              final gapHasWeekday = [
                for (var x = prev.add(const Duration(days: 1));
                    x.isBefore(cal.dateForMatchday(md));
                    x = x.add(const Duration(days: 1)))
                  x,
              ].any(_isWeekday);
              if (gapHasWeekday) expect(_isWeekday(d), isTrue, reason: why);
              expect(d.isAfter(cal.dateForMatchday(md - 1)), isTrue,
                  reason: why);
              expect(d.isBefore(cal.dateForMatchday(md)), isTrue, reason: why);
              expect(window.contains(d), isFalse, reason: why);
              expect(cal.matchdayDates.contains(d), isFalse, reason: why);
            }
          }
        }
      }
    });

    test('同じ国・シーズン・節数なら同じ日付になる', () {
      final a = SeasonCalendar.build(
          season: 3, theme: LeagueTheme.italy, totalMatchdays: 38);
      final b = SeasonCalendar.build(
          season: 3, theme: LeagueTheme.italy, totalMatchdays: 38);
      expect(a.matchdayDates, b.matchdayDates);
      // 国が違えば日程も違う(年末年始の扱いが違う)。
      final e = SeasonCalendar.build(
          season: 3, theme: LeagueTheme.england, totalMatchdays: 38);
      expect(e.matchdayDates, isNot(a.matchdayDates));
    });

    test('日付の書き方', () {
      final d = DateTime(2026, 8, 15);
      Tr.language = AppLanguage.japanese;
      expect(CalendarEngine.formatDate(d), '2026年8月15日(土)');
      expect(CalendarEngine.formatShortDate(d), '8/15(土)');
      Tr.language = AppLanguage.english;
      expect(CalendarEngine.formatDate(d), 'Sat 15 Aug 2026');
      expect(CalendarEngine.formatShortDate(d), 'Sat 15 Aug');
    });
  });

  group('GameState の今日', () {
    test('新しいゲームは第1季のオフ(2026年7月1日)から始まる', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      expect(gs.today, DateTime(2026, 7, 1));
      expect(gs.save!.today, DateTime(2026, 7, 1));
      expect(gs.nextMatchDate, gs.dateOfMatchday(1));
    });

    test('カップ戦は平日、リーグ戦はその節の日に今日が進む', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      expect(await gs.playNextCupMatch(), isNotNull);
      final cupDay = gs.today;
      expect(_isWeekday(cupDay), isTrue, reason: '$cupDay');
      expect(cupDay.isBefore(gs.dateOfMatchday(1)), isTrue);

      await gs.playNextMatchdayQuickSim();
      expect(gs.today, gs.dateOfMatchday(1));
      await gs.playNextMatchdayQuickSim();
      expect(gs.today, gs.dateOfMatchday(2));

      // 2節目の後のカップ戦は、2節と3節のあいだの平日。
      expect(await gs.playNextCupMatch(), isNotNull);
      expect(gs.today.isAfter(gs.dateOfMatchday(2)), isTrue);
      expect(gs.today.isBefore(gs.dateOfMatchday(3)), isTrue);
      expect(_isWeekday(gs.today), isTrue);
    });

    test('次のシーズンは翌年の7月1日から始まる', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      await gs.playNextMatchdayQuickSim();
      await gs.startNextSeason();
      expect(gs.save!.league.season, 2);
      expect(gs.today, DateTime(2027, 7, 1));
    });

    test('保存して読み込むと今日が保たれる', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      await gs.playNextMatchdayQuickSim();
      await gs.playNextMatchdayQuickSim();
      final before = gs.today;
      final json = gs.exportSaveJson()!;
      expect((jsonDecode(json) as Map)['today'],
          SaveGame.formatSaveDate(before));

      final loaded = GameState();
      expect(await loaded.importSaveJson(json), isTrue);
      expect(loaded.today, before);
      expect(loaded.save!.today, before);
    });

    test('今日を持たない旧セーブは、最後に消化した節の日から作り直す', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      await gs.playNextMatchdayQuickSim();
      await gs.playNextMatchdayQuickSim();
      await gs.playNextMatchdayQuickSim();
      final map = jsonDecode(gs.exportSaveJson()!) as Map<String, dynamic>;
      map.remove('today');

      final loaded = GameState();
      expect(await loaded.importSaveJson(jsonEncode(map)), isTrue);
      expect(loaded.save!.today, loaded.dateOfMatchday(3));
      // 次の節は今日より後。
      expect(loaded.nextMatchDate!.isAfter(loaded.today), isTrue);
    });

    test('1節も消化していない旧セーブは、そのシーズンのオフから始まる', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      final map = jsonDecode(gs.exportSaveJson()!) as Map<String, dynamic>;
      map.remove('today');
      final loaded = GameState();
      expect(await loaded.importSaveJson(jsonEncode(map)), isTrue);
      expect(loaded.today, DateTime(2026, 7, 1));
    });
  });
}
