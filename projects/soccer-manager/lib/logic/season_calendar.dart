import '../models/league_theme.dart';

/// 1シーズンの暦。リーグ戦の各節に実在の暦日を与え、カップ戦・親善試合・
/// スーパーカップの日付もここから出す。
///
/// 日程は国・シーズン・節数だけから決まる(同じ入力なら必ず同じ日付)ので
/// 保存しない。保存するのは「今日」だけ(SaveGame.today)。
///
/// 作り方:
/// - シーズンは8月上旬(節が多い部は8月1日以降、それ以外は8日以降。
///   ドイツ・フランスは15日以降)の土曜に始まり、5月31日までに終える。
/// - リーグ戦は土曜。代表ウィーク(9・10・11・3月の第2土曜の週)は入れない。
/// - 年末年始: イングランドは12/26・12/29・1/1 に中2日で詰める。
///   ドイツは12/21〜1/14 がウィンターブレーク。他の国は12/24〜1/2 を休む。
/// - 土曜が足りない部(46節など)は、ふつうの週の火曜にも節を入れる。
///   土曜が余る部は、開幕を最大2週遅らせ、残りは間を均等に空ける。
/// - 国内カップ・大陸大会は、前後の節のあいだの平日(火・水)に置く。
class SeasonCalendar {
  SeasonCalendar._({
    required this.season,
    required this.theme,
    required this.matchdayDates,
    required Set<DateTime> blackout,
  }) : _blackout = blackout;

  /// 第1季が始まる年(第1季は 2026/27 シーズン)。
  static const int firstSeasonYear = 2026;

  final int season;
  final LeagueTheme theme;

  /// 節ごとの日付。[0] が第1節。
  final List<DateTime> matchdayDates;

  /// カップ戦を置かない日(代表ウィーク・ウィンターブレーク)。
  final Set<DateTime> _blackout;

  static final Map<String, SeasonCalendar> _cache = {};

  /// シーズンが始まる年(第s季は startYear 年の8月に開幕する)。
  static int startYear(int season) => firstSeasonYear + season - 1;

  /// オフの間の「今日」。新しいシーズンはこの日から始まる(7月1日)。
  static DateTime preseasonDate(int season) =>
      DateTime(startYear(season), 7, 1);

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// [season]・[theme]・[totalMatchdays]の暦を作る(同じ入力は使い回す)。
  factory SeasonCalendar.build({
    required int season,
    required LeagueTheme theme,
    required int totalMatchdays,
  }) {
    final key = '$season/${theme.name}/$totalMatchdays';
    return _cache.putIfAbsent(
      key,
      () => _generate(season, theme, totalMatchdays),
    );
  }

  static DateTime _addDays(DateTime d, int days) =>
      DateTime(d.year, d.month, d.day + days);

  static DateTime _firstSaturdayOnOrAfter(DateTime d) =>
      _addDays(d, (DateTime.saturday - d.weekday) % 7);

  /// 代表ウィークの土曜(9・10・11月と翌3月の第2土曜)。
  static List<DateTime> internationalSaturdays(int season) {
    final y = startYear(season);
    return [
      for (final (year, month) in [(y, 9), (y, 10), (y, 11), (y + 1, 3)])
        _firstSaturdayOnOrAfter(DateTime(year, month, 8)),
    ];
  }

  /// 代表ウィークとして空ける日(その土曜の5日前の月曜〜3日後の火曜)。
  static Set<DateTime> internationalWindowDays(int season) => {
        for (final sat in internationalSaturdays(season))
          for (var i = -5; i <= 3; i++) _addDays(sat, i),
      };

  /// 年末年始にリーグ戦を休む期間(両端含む)。イングランドは休まずに
  /// 詰めるので null。
  static (DateTime, DateTime)? winterBreak(int season, LeagueTheme theme) {
    final y = startYear(season);
    return switch (theme) {
      LeagueTheme.england => null,
      LeagueTheme.germany => (DateTime(y, 12, 21), DateTime(y + 1, 1, 14)),
      _ => (DateTime(y, 12, 24), DateTime(y + 1, 1, 2)),
    };
  }

  /// イングランドの年末年始の連戦(12/26・12/29・1/1)。
  static List<DateTime> festiveDates(int season) {
    final y = startYear(season);
    return [DateTime(y, 12, 26), DateTime(y, 12, 29), DateTime(y + 1, 1, 1)];
  }

  static bool _inRange(DateTime d, (DateTime, DateTime) r) =>
      !d.isBefore(r.$1) && !d.isAfter(r.$2);

  static SeasonCalendar _generate(
    int season,
    LeagueTheme theme,
    int total,
  ) {
    final y = startYear(season);
    final intl = internationalWindowDays(season);
    final wb = winterBreak(season, theme);
    final blackout = <DateTime>{...intl};
    if (wb != null) {
      for (var d = wb.$1; !d.isAfter(wb.$2); d = _addDays(d, 1)) {
        blackout.add(d);
      }
    }
    if (total <= 0) {
      return SeasonCalendar._(
        season: season,
        theme: theme,
        matchdayDates: const [],
        blackout: blackout,
      );
    }

    final startDay = total > 38
        ? 1
        : (theme == LeagueTheme.germany || theme == LeagueTheme.france)
            ? 15
            : 8;
    final start = _firstSaturdayOnOrAfter(DateTime(y, 8, startDay));
    final endLimit = DateTime(y + 1, 5, 31);
    final festiveWindow = (DateTime(y, 12, 24), DateTime(y + 1, 1, 3));

    // 1) 週末の枠(土曜)。
    final slots = <DateTime>[];
    for (var d = start; !d.isAfter(endLimit); d = _addDays(d, 7)) {
      if (blackout.contains(d)) continue;
      if (theme == LeagueTheme.england && _inRange(d, festiveWindow)) continue;
      slots.add(d);
    }
    if (theme == LeagueTheme.england) {
      slots.addAll(festiveDates(season));
      slots.sort();
    }

    List<DateTime> chosen;
    if (slots.length >= total) {
      // 2a) 余る: 開幕を最大2週遅らせ、残りは土曜を均等に間引く
      // (年末年始の連戦の日は残す)。
      final surplus = slots.length - total;
      var dropStart = surplus < 2 ? surplus : 2;
      // 開幕は8月のうちに収める。
      while (dropStart > 0 && slots[dropStart].month != 8) {
        dropStart--;
      }
      final pool = slots.sublist(dropStart);
      final k = pool.length - total;
      final festive = theme == LeagueTheme.england
          ? festiveDates(season).toSet()
          : const <DateTime>{};
      final removable = [
        for (var i = 0; i < pool.length; i++)
          if (!festive.contains(pool[i])) i,
      ];
      final drop = <int>{
        for (var j = 0; j < k; j++)
          removable[((j + 0.5) * removable.length / k).floor()],
      };
      chosen = [
        for (var i = 0; i < pool.length; i++)
          if (!drop.contains(i)) pool[i],
      ];
      // 節がごく少ない(連戦の日より少ない)ときの安全網。
      if (chosen.length > total) chosen = chosen.sublist(0, total);
    } else {
      // 2b) 足りない: ふつうの週(土曜→翌土曜)の火曜に節を足す。
      final deficit = total - slots.length;
      final holiday = (DateTime(y, 12, 20), DateTime(y + 1, 1, 6));
      List<DateTime> midweeks(int offset) => [
            for (var i = 0; i + 1 < slots.length; i++)
              if (slots[i].weekday == DateTime.saturday &&
                  slots[i + 1].difference(slots[i]).inDays == 7)
                _addDays(slots[i], offset),
          ]..removeWhere((d) => blackout.contains(d) || _inRange(d, holiday));
      final tuesdays = midweeks(3);
      final extra = <DateTime>[];
      if (tuesdays.length >= deficit) {
        for (var i = 0; i < deficit; i++) {
          extra.add(tuesdays[((i + 0.5) * tuesdays.length / deficit).floor()]);
        }
      } else {
        extra.addAll(tuesdays);
        // まだ足りなければ水曜にも入れ、それでも足りなければ5月の後へ延ばす。
        final wednesdays = midweeks(4);
        for (final d in wednesdays) {
          if (extra.length >= deficit) break;
          extra.add(d);
        }
        var tail = slots.isEmpty ? start : slots.last;
        while (extra.length < deficit) {
          tail = _addDays(tail, 7);
          extra.add(tail);
        }
      }
      chosen = [...slots, ...extra]..sort();
    }

    return SeasonCalendar._(
      season: season,
      theme: theme,
      matchdayDates: List.unmodifiable(chosen),
      blackout: blackout,
    );
  }

  int get totalMatchdays => matchdayDates.length;

  /// 第1節の日付(節が無いときは8月第2土曜)。
  DateTime get firstMatchDate => matchdayDates.isNotEmpty
      ? matchdayDates.first
      : _firstSaturdayOnOrAfter(DateTime(startYear(season), 8, 8));

  /// 最終節の日付。
  DateTime get lastMatchDate =>
      matchdayDates.isNotEmpty ? matchdayDates.last : firstMatchDate;

  /// 第[matchday]節の日付。範囲外は前後へ1週ずつ延ばした日。
  DateTime dateForMatchday(int matchday) {
    if (matchday < 1) return _addDays(firstMatchDate, -7 * (1 - matchday));
    if (matchday > matchdayDates.length) {
      return _addDays(lastMatchDate, 7 * (matchday - matchdayDates.length));
    }
    return matchdayDates[matchday - 1];
  }

  /// 開幕前の親善試合の日付。開幕の週から遡って1週ずつ並べる(土曜)。
  DateTime friendlyDate(int index, int count) =>
      _addDays(firstMatchDate, -7 * (count - index));

  /// スーパーカップの日付(開幕の6日前の日曜)。
  DateTime get superCupDate => _addDays(firstMatchDate, -6);

  /// 第[matchday]節の前(前の節とのあいだ)にあるカップ戦の日付。
  /// 平日で、代表ウィーク・ウィンターブレークを避ける。国内カップは火曜、
  /// 大陸大会は水曜を先に選ぶ。
  DateTime cupDateBefore(int matchday, {bool continental = false}) {
    final next = dateForMatchday(matchday);
    final prev = dateForMatchday(matchday - 1);
    final order = continental
        ? const [DateTime.wednesday, DateTime.tuesday, DateTime.thursday,
            DateTime.monday, DateTime.friday]
        : const [DateTime.tuesday, DateTime.wednesday, DateTime.thursday,
            DateTime.monday, DateTime.friday];
    final between = <DateTime>[
      for (var d = _addDays(prev, 1); d.isBefore(next); d = _addDays(d, 1)) d,
    ];
    for (final allowBlackout in [false, true]) {
      for (final wd in order) {
        for (final d in between) {
          if (d.weekday != wd) continue;
          if (!allowBlackout && _blackout.contains(d)) continue;
          return d;
        }
      }
    }
    return _addDays(prev, 1);
  }

  /// [after]より後の、最初のカップ戦向きの平日(国内は火曜、大陸は水曜)。
  /// リーグ戦が終わった後(オフ)のカップ戦に使う。
  static DateTime nextCupWeekdayAfter(DateTime after, {bool continental = false}) {
    final want = continental ? DateTime.wednesday : DateTime.tuesday;
    var d = _addDays(dateOnly(after), 1);
    while (d.weekday != want) {
      d = _addDays(d, 1);
    }
    return d;
  }

  /// [day]がリーグ戦を入れない代表ウィークの中か。
  bool isInternationalWindow(DateTime day) =>
      internationalWindowDays(season).contains(dateOnly(day));
}
