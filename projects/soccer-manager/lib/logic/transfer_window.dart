import '../l10n/tr.dart';
import '../models/league_theme.dart';

/// 移籍の窓の種類。
enum TransferWindowKind { summer, winter }

extension TransferWindowKindInfo on TransferWindowKind {
  String get label => switch (this) {
        TransferWindowKind.summer => Tr.pick('夏の窓', 'summer window'),
        TransferWindowKind.winter => Tr.pick('冬の窓', 'winter window'),
      };
}

/// 1回分の移籍の窓。[opens]〜[closes](両端を含む。[closes]が締切日)。
class TransferWindowPeriod {
  const TransferWindowPeriod({
    required this.kind,
    required this.opens,
    required this.closes,
  });

  final TransferWindowKind kind;
  final DateTime opens;
  final DateTime closes;

  bool contains(DateTime day) {
    final d = TransferWindowCalendar.dateOnly(day);
    return !d.isBefore(opens) && !d.isAfter(closes);
  }

  @override
  bool operator ==(Object other) =>
      other is TransferWindowPeriod &&
      other.kind == kind &&
      other.opens == opens &&
      other.closes == closes;

  @override
  int get hashCode => Object.hash(kind, opens, closes);
}

/// ローンの長さ。半年は冬の窓が開く日まで、1年はシーズン末(6月30日)まで。
enum LoanLength { half, full }

/// 移籍の窓の暦。国ごとに実在の日付へ寄せる(年によって数日ずれる実在の
/// 日付を、毎年同じ月日に丸めてある)。
///
/// | 国 | 夏 | 冬 |
/// |---|---|---|
/// | イングランド | 6/14〜9/1 | 1/1〜2/2 |
/// | スペイン | 7/1〜9/1 | 1/2〜2/3 |
/// | ドイツ | 7/1〜9/1 | 1/1〜2/2 |
/// | イタリア | 7/1〜9/1 | 1/2〜2/3 |
/// | フランス | 6/16〜9/1 | 1/1〜2/3 |
///
/// 新しいシーズンは7月1日から始まる(SeasonCalendar.preseasonDate)ので、
/// どの国も始まった日には夏の窓が開いている。リーグ戦を終えてから
/// 夏の窓が開くまで(5月末〜6月中旬)は閉じている。
class TransferWindowCalendar {
  TransferWindowCalendar._();

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// 夏の窓の(開く月, 日, 締切の月, 日)。
  static (int, int, int, int) summerDates(LeagueTheme theme) =>
      switch (theme) {
        LeagueTheme.england => (6, 14, 9, 1),
        LeagueTheme.spain => (7, 1, 9, 1),
        LeagueTheme.germany => (7, 1, 9, 1),
        LeagueTheme.italy => (7, 1, 9, 1),
        LeagueTheme.france => (6, 16, 9, 1),
      };

  /// 冬の窓の(開く月, 日, 締切の月, 日)。
  static (int, int, int, int) winterDates(LeagueTheme theme) =>
      switch (theme) {
        LeagueTheme.england => (1, 1, 2, 2),
        LeagueTheme.spain => (1, 2, 2, 3),
        LeagueTheme.germany => (1, 1, 2, 2),
        LeagueTheme.italy => (1, 2, 2, 3),
        LeagueTheme.france => (1, 1, 2, 3),
      };

  /// [year]年の夏の窓。
  static TransferWindowPeriod summerOf(int year, LeagueTheme theme) {
    final (om, od, cm, cd) = summerDates(theme);
    return TransferWindowPeriod(
      kind: TransferWindowKind.summer,
      opens: DateTime(year, om, od),
      closes: DateTime(year, cm, cd),
    );
  }

  /// [year]年の冬の窓(1月に開く)。
  static TransferWindowPeriod winterOf(int year, LeagueTheme theme) {
    final (om, od, cm, cd) = winterDates(theme);
    return TransferWindowPeriod(
      kind: TransferWindowKind.winter,
      opens: DateTime(year, om, od),
      closes: DateTime(year, cm, cd),
    );
  }

  /// [year]の前後の窓を日付順に並べたもの。
  static List<TransferWindowPeriod> _around(int year, LeagueTheme theme) => [
        for (var y = year - 1; y <= year + 1; y++) ...[
          winterOf(y, theme),
          summerOf(y, theme),
        ],
      ];

  /// [day]に開いている窓。閉じていれば null。
  static TransferWindowPeriod? openOn(DateTime day, LeagueTheme theme) {
    for (final p in _around(day.year, theme)) {
      if (p.contains(day)) return p;
    }
    return null;
  }

  static bool isOpen(DateTime day, LeagueTheme theme) =>
      openOn(day, theme) != null;

  /// [day]より後に開く、最初の窓。
  static TransferWindowPeriod nextAfter(DateTime day, LeagueTheme theme) {
    final d = dateOnly(day);
    for (final p in _around(day.year, theme)) {
      if (p.opens.isAfter(d)) return p;
    }
    return winterOf(day.year + 2, theme);
  }

  /// [a]から[b]までの日数(暦の日で数える。夏時間の切り替えでずれない)。
  static int daysBetween(DateTime a, DateTime b) =>
      DateTime.utc(b.year, b.month, b.day)
          .difference(DateTime.utc(a.year, a.month, a.day))
          .inDays;

  /// 締切まで残り何日か(締切日当日は0)。閉じていれば null。
  static int? daysUntilDeadline(DateTime day, LeagueTheme theme) {
    final p = openOn(day, theme);
    if (p == null) return null;
    return daysBetween(day, p.closes);
  }

  /// [from]の翌日から[to]までのあいだに締切日を過ぎた窓(締切日の翌日が
  /// その範囲に入る窓)があるか。
  static bool deadlinePassedBetween(
      DateTime from, DateTime to, LeagueTheme theme) {
    final a = dateOnly(from);
    final b = dateOnly(to);
    if (!b.isAfter(a)) return false;
    for (final p in [..._around(a.year, theme), ..._around(b.year, theme)]) {
      final dayAfter = DateTime(p.closes.year, p.closes.month, p.closes.day + 1);
      if (dayAfter.isAfter(a) && !dayAfter.isAfter(b)) return true;
    }
    return false;
  }

  /// [from]の翌日から[to]までのあいだに開いた窓があるか。
  static bool openedBetween(DateTime from, DateTime to, LeagueTheme theme) {
    final a = dateOnly(from);
    final b = dateOnly(to);
    if (!b.isAfter(a)) return false;
    for (final p in [..._around(a.year, theme), ..._around(b.year, theme)]) {
      if (p.opens.isAfter(a) && !p.opens.isAfter(b)) return true;
    }
    return false;
  }

  /// シーズンの終わり(6月30日)。7月以降の日はその翌年の6月30日。
  static DateTime seasonEnd(DateTime day) =>
      DateTime(day.month >= 7 ? day.year + 1 : day.year, 6, 30);

  /// 冬の窓が開く日のうち、[day]より後で最初のもの。
  static DateTime nextWinterOpening(DateTime day, LeagueTheme theme) {
    final d = dateOnly(day);
    var w = winterOf(d.year, theme).opens;
    if (!w.isAfter(d)) w = winterOf(d.year + 1, theme).opens;
    return w;
  }

  /// 半年のローンが組めるか。冬の窓が開く日がシーズン末より前に来るときだけ
  /// (冬の窓の最中や、それより後に組むと、半年は「シーズン末まで」と同じになる)。
  static bool halfLoanAvailable(DateTime day, LeagueTheme theme) =>
      nextWinterOpening(day, theme).isBefore(seasonEnd(day));

  /// [day]に組んだローンが終わる日。半年は冬の窓が開く日、1年はシーズン末。
  /// 半年が組めない時期の半年は、シーズン末にする。
  static DateTime loanEndDate(
    DateTime day,
    LeagueTheme theme,
    LoanLength length,
  ) {
    if (length == LoanLength.half && halfLoanAvailable(day, theme)) {
      return nextWinterOpening(day, theme);
    }
    return seasonEnd(day);
  }

  /// 「9月1日」/ "1 Sep"(年の要らない日付)。
  static String formatMonthDay(DateTime d) => Tr.pick(
      '${d.month}月${d.day}日', '${d.day} ${_months[d.month - 1]}');

  /// 「2027年7月」/ "Jul 2027"(日の要らない日付)。
  static String formatYearMonth(DateTime d) =>
      Tr.pick('${d.year}年${d.month}月', '${_months[d.month - 1]} ${d.year}');

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
}
