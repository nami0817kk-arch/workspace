import 'dart:math';

import '../l10n/tr.dart';
import '../models/league_theme.dart';
import 'season_calendar.dart';

/// お金が動く日の決まり。
///
/// - 会計年度は7月1日〜翌6月30日。第s季の年度は、第s季が始まる年の
///   7月1日から。収支の記録(SeasonLedger)はこの年度で区切る。
/// - 給与(選手・スタッフ)は毎月の末日に、年俸の12分の1を払う。
/// - 放映権は年4回(8/1・11/1・2/1・5/1)に、年額の4分の1ずつ入る。
/// - 観客・スポンサー・グッズは、これまで通り試合の日に入る。
///   祝日の試合は客が増える([holidayAttendanceMultiplier])。
class MoneyCalendar {
  MoneyCalendar._();

  /// [day] が入る会計年度(=第何季の年度か)。7月1日で切り替わる。
  static int fiscalSeasonOf(DateTime day) {
    final startYear = day.month >= 7 ? day.year : day.year - 1;
    return startYear - SeasonCalendar.firstSeasonYear + 1;
  }

  /// 第[season]季の会計年度の最初の日(7月1日)。
  static DateTime fiscalYearStart(int season) =>
      DateTime(SeasonCalendar.startYear(season), 7, 1);

  /// 第[season]季の会計年度の最後の日(翌年の6月30日)。
  static DateTime fiscalYearEnd(int season) =>
      DateTime(SeasonCalendar.startYear(season) + 1, 6, 30);

  /// 年度の表示(「2026/27年度」)。
  static String fiscalYearLabel(int season) {
    final y = SeasonCalendar.startYear(season);
    final next = (y + 1) % 100;
    return '$y/${next.toString().padLeft(2, '0')}';
  }

  /// 月の末日。
  static DateTime monthEnd(int year, int month) => DateTime(year, month + 1, 0);

  /// [after] より後で [until] 以前(両端は日付で比べる)の月末の日。
  static List<DateTime> monthEndsBetween(DateTime after, DateTime until) {
    final a = SeasonCalendar.dateOnly(after);
    final u = SeasonCalendar.dateOnly(until);
    final out = <DateTime>[];
    var y = a.year;
    var m = a.month;
    while (true) {
      final end = monthEnd(y, m);
      if (end.isAfter(u)) break;
      if (end.isAfter(a)) out.add(end);
      m += 1;
      if (m > 12) {
        m = 1;
        y += 1;
      }
    }
    return out;
  }

  /// 週俸の合計から、毎月末に払う額。12回で年俸(週俸×52)になる。
  static int monthlyFromWeekly(int weekly) => (weekly * 52 / 12).round();

  /// 放映権の入る日(年度の中の4回)。
  static List<DateTime> broadcastDates(int season) {
    final y = SeasonCalendar.startYear(season);
    return [
      DateTime(y, 8, 1),
      DateTime(y, 11, 1),
      DateTime(y + 1, 2, 1),
      DateTime(y + 1, 5, 1),
    ];
  }

  /// [after] より後で [until] 以前の放映権の入金日。
  static List<DateTime> broadcastDatesBetween(DateTime after, DateTime until) {
    final a = SeasonCalendar.dateOnly(after);
    final u = SeasonCalendar.dateOnly(until);
    final out = <DateTime>[];
    for (var s = fiscalSeasonOf(a); s <= fiscalSeasonOf(u); s++) {
      for (final d in broadcastDates(s)) {
        if (d.isAfter(a) && !d.isAfter(u)) out.add(d);
      }
    }
    return out;
  }

  /// 年額 [annual] の放映権を4回に分けたときの [index] 回目(0〜3)の額。
  /// 4回の合計は年額と必ず一致する(端数は回ごとに寄せる)。
  static int broadcastInstallment(int annual, int index) {
    final i = index.clamp(0, 3);
    return (annual * (i + 1) / 4).round() - (annual * i / 4).round();
  }

  /// [day] がその年度の何回目の放映権の入金日か(入金日でなければ null)。
  static int? broadcastIndexOf(DateTime day) {
    final d = SeasonCalendar.dateOnly(day);
    final dates = broadcastDates(fiscalSeasonOf(d));
    final i = dates.indexOf(d);
    return i < 0 ? null : i;
  }

  // ---- 祝日 ----

  /// 祝日の試合の客の倍率。
  static const double holidayAttendanceMultiplier = 1.15;

  /// 復活祭の日曜(グレゴリオ暦。匿名のアルゴリズム)。
  static DateTime easterSunday(int year) {
    final a = year % 19;
    final b = year ~/ 100;
    final c = year % 100;
    final d = b ~/ 4;
    final e = b % 4;
    final f = (b + 8) ~/ 25;
    final g = (b - f + 1) ~/ 3;
    final h = (19 * a + b - d - g + 15) % 30;
    final i = c ~/ 4;
    final k = c % 4;
    final l = (32 + 2 * e + 2 * i - h - k) % 7;
    final m = (a + 11 * h + 22 * l) ~/ 451;
    final month = (h + l - 7 * m + 114) ~/ 31;
    final day = ((h + l - 7 * m + 114) % 31) + 1;
    return DateTime(year, month, day);
  }

  static DateTime _nthWeekday(int year, int month, int weekday, int n) {
    final first = DateTime(year, month, 1);
    final offset = (weekday - first.weekday) % 7;
    return DateTime(year, month, 1 + offset + (n - 1) * 7);
  }

  static DateTime _lastWeekday(int year, int month, int weekday) {
    final last = monthEnd(year, month);
    final offset = (last.weekday - weekday) % 7;
    return DateTime(year, month, last.day - offset);
  }

  /// [theme] の国の [year] 年の祝日(日付 → 名前。表示の言語で返す)。
  static Map<DateTime, String> holidays(LeagueTheme theme, int year) {
        final easter = easterSunday(year);
        DateTime fromEaster(int days) =>
            DateTime(easter.year, easter.month, easter.day + days);
        final common = <DateTime, String>{
          DateTime(year, 1, 1): Tr.pick('元日', 'New Year\'s Day'),
          DateTime(year, 12, 25): Tr.pick('クリスマス', 'Christmas Day'),
        };
        final Map<DateTime, String> own = switch (theme) {
          LeagueTheme.england => {
              fromEaster(-2): Tr.pick('聖金曜日', 'Good Friday'),
              fromEaster(1): Tr.pick('イースターマンデー', 'Easter Monday'),
              _nthWeekday(year, 5, DateTime.monday, 1):
                  Tr.pick('5月の祝日', 'Early May bank holiday'),
              _lastWeekday(year, 5, DateTime.monday): Tr.pick('春の祝日', 'Spring bank holiday'),
              _lastWeekday(year, 8, DateTime.monday): Tr.pick('夏の祝日', 'Summer bank holiday'),
              DateTime(year, 12, 26): Tr.pick('ボクシング・デー', 'Boxing Day'),
            },
          LeagueTheme.spain => {
              DateTime(year, 1, 6): Tr.pick('公現祭', 'Epiphany'),
              fromEaster(-2): Tr.pick('聖金曜日', 'Good Friday'),
              DateTime(year, 5, 1): Tr.pick('メーデー', 'Labour Day'),
              DateTime(year, 8, 15): Tr.pick('聖母被昇天祭', 'Assumption Day'),
              DateTime(year, 10, 12): Tr.pick('建国記念日', 'National Day'),
              DateTime(year, 11, 1): Tr.pick('諸聖人の日', 'All Saints\' Day'),
              DateTime(year, 12, 6): Tr.pick('憲法記念日', 'Constitution Day'),
              DateTime(year, 12, 8): Tr.pick('無原罪の御宿り', 'Immaculate Conception'),
            },
          LeagueTheme.germany => {
              fromEaster(-2): Tr.pick('聖金曜日', 'Good Friday'),
              fromEaster(1): Tr.pick('復活祭の月曜', 'Easter Monday'),
              DateTime(year, 5, 1): Tr.pick('メーデー', 'Labour Day'),
              fromEaster(39): Tr.pick('昇天祭', 'Ascension Day'),
              fromEaster(50): Tr.pick('聖霊降臨祭の月曜', 'Whit Monday'),
              DateTime(year, 10, 3): Tr.pick('統一記念日', 'Day of German Unity'),
              DateTime(year, 12, 26): Tr.pick('聖シュテファンの日', 'St Stephen\'s Day'),
            },
          LeagueTheme.italy => {
              DateTime(year, 1, 6): Tr.pick('公現祭', 'Epiphany'),
              fromEaster(1): Tr.pick('復活祭の月曜', 'Easter Monday'),
              DateTime(year, 4, 25): Tr.pick('解放記念日', 'Liberation Day'),
              DateTime(year, 5, 1): Tr.pick('メーデー', 'Labour Day'),
              DateTime(year, 6, 2): Tr.pick('共和国記念日', 'Republic Day'),
              DateTime(year, 8, 15): Tr.pick('聖母被昇天祭', 'Assumption Day'),
              DateTime(year, 11, 1): Tr.pick('諸聖人の日', 'All Saints\' Day'),
              DateTime(year, 12, 8): Tr.pick('無原罪の御宿り', 'Immaculate Conception'),
              DateTime(year, 12, 26): Tr.pick('聖ステファノの日', 'St Stephen\'s Day'),
            },
          LeagueTheme.france => {
              fromEaster(1): Tr.pick('復活祭の月曜', 'Easter Monday'),
              DateTime(year, 5, 1): Tr.pick('メーデー', 'Labour Day'),
              DateTime(year, 5, 8): Tr.pick('戦勝記念日', 'Victory in Europe Day'),
              fromEaster(39): Tr.pick('昇天祭', 'Ascension Day'),
              fromEaster(50): Tr.pick('聖霊降臨祭の月曜', 'Whit Monday'),
              DateTime(year, 7, 14): Tr.pick('革命記念日', 'Bastille Day'),
              DateTime(year, 8, 15): Tr.pick('聖母被昇天祭', 'Assumption Day'),
              DateTime(year, 11, 1): Tr.pick('諸聖人の日', 'All Saints\' Day'),
              DateTime(year, 11, 11): Tr.pick('休戦記念日', 'Armistice Day'),
            },
        };
        return {...common, ...own};
  }

  /// [day] が [theme] の国の祝日なら、その名前。祝日でなければ null。
  static String? holidayName(DateTime day, LeagueTheme theme) =>
      holidays(theme, day.year)[SeasonCalendar.dateOnly(day)];

  static bool isHoliday(DateTime day, LeagueTheme theme) =>
      holidayName(day, theme) != null;

  /// 祝日の客の倍率を掛けた観客数(収容人数で頭打ち)。
  static int holidayAttendance(int attendance, int capacity) =>
      min(capacity, (attendance * holidayAttendanceMultiplier).round());
}
