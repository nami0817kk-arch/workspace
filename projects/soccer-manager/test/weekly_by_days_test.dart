import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/logic/season_calendar.dart';
import 'package:soccer_manager/models/league_theme.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 週の処理は7日ごと、怪我は日数で治る(2026-11-22)。
///
/// 以前は「週ごと」の処理(練習・不満・ユース・ローン・怪我の回復)を
/// 節を1つ消化するたびに走らせていたため、ドイツの冬休み(約3.5週)が
/// 1週扱いになり、イングランドの年末の3連戦(数日おき)が3週扱いになって
/// 怪我が3週分治っていた。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Tr.language = AppLanguage.japanese;
  });
  tearDown(() => Tr.language = AppLanguage.system);

  int weeksBetween(DateTime a, DateTime b) =>
      DateTime.utc(b.year, b.month, b.day)
          .difference(DateTime.utc(a.year, a.month, a.day))
          .inDays ~/
      7;

  /// 週の処理の回数を、成長推移の記録(週の処理ごとに1件)で数える。
  Player trackedPlayer(GameState gs) =>
      gs.userTeam.players.firstWhere((p) => !p.isLoanedOut);

  Future<GameState> startedSeason(LeagueTheme theme) async {
    final gs = GameState();
    await gs.startNewGame('週FC', theme: theme);
    expect(gs.save!.lastWeeklyTickDate, isNull, reason: '開幕前は時計が止まっている');
    expect(await gs.playNextMatchdayQuickSim(), isNotNull);
    // その季で最初の節の日に1回行い、その日を起点にする。
    expect(gs.save!.lastWeeklyTickDate, gs.dateOfMatchday(1));
    return gs;
  }

  test('ドイツの冬休み(約3.5週)のあいだに、週の処理が複数回走る', () async {
    final gs = await startedSeason(LeagueTheme.germany);
    final s = gs.save!;
    final wb =
        SeasonCalendar.winterBreak(s.league.season, LeagueTheme.germany)!;
    gs.debugAdvanceTodayTo(wb.$1);
    final p = trackedPlayer(gs);
    final historyBefore = p.overallHistory.length;
    final anchorBefore = s.lastWeeklyTickDate!;

    gs.debugAdvanceTodayTo(wb.$2);

    final ticks = p.overallHistory.length - historyBefore;
    expect(ticks, greaterThanOrEqualTo(3), reason: '冬休みは3週を超える。節ごとだと1回だった');
    expect(
        s.lastWeeklyTickDate,
        DateTime(anchorBefore.year, anchorBefore.month,
            anchorBefore.day + 7 * ticks));
    expect(s.today, wb.$2);
  });

  test('イングランドの年末の3連戦(3日おき)では、週の処理は1回', () async {
    final gs = await startedSeason(LeagueTheme.england);
    final s = gs.save!;
    final festive = SeasonCalendar.festiveDates(s.league.season);
    // 年末の3連戦は暦に入っている。
    final dates = gs.seasonCalendar.matchdayDates;
    for (final d in festive) {
      expect(dates, contains(d));
    }
    gs.debugAdvanceTodayTo(festive.first.subtract(const Duration(days: 1)));
    final anchorBefore = s.lastWeeklyTickDate!;
    for (final d in festive) {
      gs.debugAdvanceTodayTo(d);
    }
    expect(weeksBetween(anchorBefore, s.lastWeeklyTickDate!), 1,
        reason: '3試合でも7日に満たないので週は1つ。節ごとだと3回だった');
  });

  test('怪我は日数で治る: 3週の離脱は、年末の3連戦(7日)の後も2週残る', () async {
    final gs = await startedSeason(LeagueTheme.england);
    final s = gs.save!;
    final festive = SeasonCalendar.festiveDates(s.league.season);
    final start = festive.first.subtract(const Duration(days: 1));
    gs.debugAdvanceTodayTo(start);
    final p = gs.userTeam.players.firstWhere((x) => !x.isInjured);
    p
      ..injuryWeeks = 3
      ..injuryDays = 0
      ..injuryType = InjuryType.muscle;
    for (final d in festive) {
      gs.debugAdvanceTodayTo(d);
    }
    // 12/25 → 1/1 は7日。
    expect(p.injuryWeeks, 2, reason: '節ごとに数えると3節で治っていた');
    expect(p.injuryDays, 0);

    // 1週の離脱は、3日では治らず、7日で治る。
    p
      ..injuryWeeks = 1
      ..injuryDays = 0
      ..injuryType = InjuryType.muscle;
    gs.debugRecoverByDays(3);
    expect(p.injuryWeeks, 1);
    expect(p.injuryDays, 3);
    gs.debugRecoverByDays(4);
    expect(p.injuryWeeks, 0);
    expect(p.injuryDays, 0);
    expect(p.injuryType, isNull);
  });

  test('年末の連戦は過密日程と判定される', () async {
    final gs = await startedSeason(LeagueTheme.england);
    final s = gs.save!;
    final festive = SeasonCalendar.festiveDates(s.league.season);
    gs.debugAdvanceTodayTo(festive[0]);
    gs.debugNoteUserMatchDay();
    for (final d in festive.skip(1)) {
      gs.debugAdvanceTodayTo(d);
      final starter = gs.userTeam.players
          .firstWhere((p) => gs.userTeam.startingXI.contains(p.id))
        ..fatigue = 40;
      gs.debugNoteUserMatchDay();
      expect(s.lastWeekCongested, isTrue, reason: '$d は前の試合から3日');
      expect(starter.fatigue, 40 + GameStateCongestion.congestionFatigue);
    }
  });

  test('1季の週の処理の回数は暦どおり(約40週。節の数ではない)', () async {
    final gs = await startedSeason(LeagueTheme.england);
    final s = gs.save!;
    final first = s.lastWeeklyTickDate!;
    final cal = gs.seasonCalendar;
    gs.debugAdvanceTodayTo(cal.lastMatchDate);
    final ticks = weeksBetween(first, s.lastWeeklyTickDate!) + 1;
    expect(ticks, gs.weeklyTicksThisSeason);
    // 1季はおよそ8月〜5月の40週前後。節の数(38)とは一致しない。
    expect(ticks, inInclusiveRange(38, 46));
  });

  test('今季のものでない時計では、日付を進めても週の処理は走らない(オフ)', () async {
    final gs = await startedSeason(LeagueTheme.england);
    final s = gs.save!;
    // 時計が今季のものでなければ、日付を進めても週の処理は走らない。
    s.lastWeeklyTickDate = DateTime(2000, 1, 1);
    final p = trackedPlayer(gs);
    final before = p.overallHistory.length;
    gs.debugAdvanceTodayTo(gs.today.add(const Duration(days: 30)));
    expect(p.overallHistory.length, before);
  });
}
