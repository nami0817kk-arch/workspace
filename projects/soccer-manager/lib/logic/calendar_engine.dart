import '../models/continental_cup.dart';
import '../models/cup.dart';
import '../models/league.dart';
import '../models/team.dart';
import '../models/league_theme.dart';
import 'continental_cup_engine.dart';
import 'season_calendar.dart';
import '../l10n/tr.dart';

/// カレンダー表示用の1日分の情報。
class CalendarDayInfo {
  final DateTime date;
  final bool isLeagueMatchDay;
  final bool isHomeMatch;
  final String? opponentName;
  final int? matchday;
  final bool isTrainingFocusDay;
  final bool isToday;

  /// この日から消化可能になるカップ戦(国内・大陸)の表示ラベル。
  /// 複数の大会が同じ日に消化可能となることもあるため複数保持する。
  final List<String> cupLabels;

  /// この日に予定されているプレシーズン親善試合(開幕前)。
  final bool isFriendlyMatchDay;

  const CalendarDayInfo({
    required this.date,
    this.isLeagueMatchDay = false,
    this.isHomeMatch = false,
    this.opponentName,
    this.matchday,
    this.isTrainingFocusDay = false,
    this.isToday = false,
    this.cupLabels = const [],
    this.isFriendlyMatchDay = false,
  });

  bool get isCupMatchDay => cupLabels.isNotEmpty;
}

/// カレンダー画面向けに、日ごとの予定(試合日/重点練習日)を計算する。
/// 節・カップ戦・親善試合の暦日は [SeasonCalendar] が決める。
class CalendarEngine {
  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static const _monthLabels = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];

  /// 「2026年8月16日(土)」/ "Sat 16 Aug 2026"。画面上部の今日の表示に使う。
  static String formatDate(DateTime d) => Tr.pick(
      '${d.year}年${d.month}月${d.day}日(${weekdayLabel(d.weekday)})',
      '${weekdayLabel(d.weekday)} ${d.day} ${_monthLabels[d.month - 1]} ${d.year}');

  /// 「8/16(土)」/ "Sat 16 Aug"。日程の一覧など、年の要らない所に使う。
  static String formatShortDate(DateTime d) => Tr.pick(
      '${d.month}/${d.day}(${weekdayLabel(d.weekday)})',
      '${weekdayLabel(d.weekday)} ${d.day} ${_monthLabels[d.month - 1]}');

  // const にできないのは、曜日名が表示時の言語で決まるため。static final に
  // すると最初のアクセスで言語が固定され、設定で切り替えても反映されない。
  static List<String> get _weekdayLabels => [
        Tr.pick('月', 'Mon'),
        Tr.pick('火', 'Tue'),
        Tr.pick('水', 'Wed'),
        Tr.pick('木', 'Thu'),
        Tr.pick('金', 'Fri'),
        Tr.pick('土', 'Sat'),
        Tr.pick('日', 'Sun')
      ];

  /// DateTime.weekday(1=月〜7=日)に対応する日本語の曜日1文字。
  static String weekdayLabel(int weekday) => _weekdayLabels[weekday - 1];

  /// カップ戦の対戦相手表示に使うチーム名を、リーグ勢+大陸カップ参加勢
  /// (両方渡された場合)から解決する。
  static String? _teamNameFor(
    String teamId,
    League league,
    List<Team> extraTeams,
  ) {
    for (final t in league.teams) {
      if (t.id == teamId) return t.name;
    }
    for (final t in extraTeams) {
      if (t.id == teamId) return t.name;
    }
    return null;
  }

  /// [cup]の次の未消化試合が消化可能になる日付("1節分の間隔"ルールにより
  /// 消化可能になる最初の日)と、カレンダー表示用ラベルを返す。
  static (DateTime, String)? _domesticCupEntry(
    Cup? cup,
    League league,
    SeasonCalendar calendar,
    String userTeamId,
    List<Team> extraTeams,
  ) {
    if (cup == null) return null;
    final match = cup.nextUnplayedMatch;
    if (match == null) return null;
    final date = calendar.cupDateBefore(_eligibleMatchday(
        cup.plannedRounds != null ? null : cup.lastPlayedAtMatchday,
        league,
        calendar,
        due: cup.dueMatchdayForMatch(match)));
    final involvesUser =
        match.homeTeamId == userTeamId || match.awayTeamId == userTeamId;
    if (!involvesUser) {
      return (date, Tr.pick('${cup.name}: 消化可能', '${cup.name}: tie available'));
    }
    final isHome = match.homeTeamId == userTeamId;
    final opponentId = isHome ? match.awayTeamId : match.homeTeamId;
    final opponentName =
        _teamNameFor(opponentId, league, extraTeams) ?? Tr.pick('未定', 'TBC');
    return (date, '${cup.name}: ${isHome ? '(H)' : '(A)'} vs $opponentName');
  }

  /// 大陸カップ版の[_domesticCupEntry]。グループステージ・決勝トーナメントの
  /// いずれの段階でも、次の未消化試合から対戦カードを解決する。
  static (DateTime, String)? _continentalCupEntry(
    ContinentalCup? cup,
    League league,
    SeasonCalendar calendar,
    String userTeamId,
    List<Team> extraTeams,
  ) {
    if (cup == null) return null;
    String? homeId;
    String? awayId;
    bool? isHome;
    if (!cup.isGroupStageComplete) {
      final match = ContinentalCupEngine.nextGroupMatch(cup);
      if (match == null) return null;
      homeId = match.homeTeamId;
      awayId = match.awayTeamId;
      isHome = homeId == userTeamId;
    } else {
      if (cup.knockoutRounds.isEmpty) return null;
      CupTie? tie;
      for (final t in cup.knockoutRounds.last) {
        if (!t.isComplete) {
          tie = t;
          break;
        }
      }
      if (tie == null) return null;
      homeId = tie.teamAId;
      awayId = tie.teamBId;
      isHome = null;
    }
    final date = calendar.cupDateBefore(
        _eligibleMatchday(cup.stepDue != null ? null : cup.lastPlayedAtMatchday,
            league, calendar,
            due: ContinentalCupEngine.currentStepDue(cup)),
        continental: true);
    final involvesUser = homeId == userTeamId || awayId == userTeamId;
    if (!involvesUser) {
      return (date, Tr.pick('${cup.name}: 消化可能', '${cup.name}: tie available'));
    }
    final opponentId = homeId == userTeamId ? awayId : homeId;
    final opponentName =
        _teamNameFor(opponentId, league, extraTeams) ?? Tr.pick('未定', 'TBC');
    final sideLabel = isHome == null ? '' : (isHome ? '(H)' : '(A)');
    return (date, '${cup.name}: $sideLabel vs $opponentName');
  }

  /// カップ戦の次の試合を消化できるようになる節。最後に消化した節の次と、
  /// いまのリーグの節(次に消化する節)と、回戦・段階の決まった節([due]。
  /// 1〜3部の全クラブのカップと、2つの大陸大会)のいちばん遅いもの。
  static int _eligibleMatchday(
    int? lastPlayedAtMatchday,
    League league,
    SeasonCalendar calendar, {
    int? due,
  }) {
    final afterLast = (lastPlayedAtMatchday ?? 0) + 1;
    final current = league.nextUnplayedFixture?.matchday ??
        (calendar.totalMatchdays + 1);
    var md = afterLast > current ? afterLast : current;
    if (due != null && due > md && league.nextUnplayedFixture != null) {
      md = due;
    }
    return md;
  }

  /// [league]の節数から作る暦。国が分からないときはイングランドの暦。
  static SeasonCalendar calendarFor(
    League league, {
    LeagueTheme theme = LeagueTheme.england,
  }) =>
      SeasonCalendar.build(
        season: league.season,
        theme: theme,
        totalMatchdays: league.fixtures
            .fold<int>(0, (m, f) => f.matchday > m ? f.matchday : m),
      );

  /// [from]〜[to](両端含む)の各日について、自クラブのリーグ戦がある日は
  /// 対戦相手情報を、それ以外は重点練習日かどうかを付与して返す。カップ戦
  /// (国内・大陸)は次の試合が消化可能になる日にラベルとして付与する。
  static List<CalendarDayInfo> buildRange({
    required DateTime from,
    required DateTime to,
    required League league,
    required String userTeamId,
    required int trainingDayOfWeek,
    required DateTime today,
    Cup? domesticCup,
    ContinentalCup? continentalCup,
    List<Team> continentalTeams = const [],
    List<Fixture> friendlies = const [],
    SeasonCalendar? calendar,
  }) {
    final cal = calendar ?? calendarFor(league);
    // プレシーズン親善試合は開幕前の週に並ぶ。未消化のものだけ予定として扱う。
    final friendlyByDate = <DateTime, Fixture>{};
    // 日付は全体の並び順で決める(消化した試合があっても残りの日付は動かない)。
    for (var i = 0; i < friendlies.length; i++) {
      if (friendlies[i].result != null) continue;
      friendlyByDate[dateOnly(cal.friendlyDate(i, friendlies.length))] =
          friendlies[i];
    }

    final matchesByDate = <DateTime, Fixture>{};
    for (final f in league.fixtures) {
      if (f.homeTeamId != userTeamId && f.awayTeamId != userTeamId) continue;
      matchesByDate[dateOnly(cal.dateForMatchday(f.matchday))] = f;
    }

    final cupLabelsByDate = <DateTime, List<String>>{};
    for (final entry in [
      _domesticCupEntry(
          domesticCup, league, cal, userTeamId, continentalTeams),
      _continentalCupEntry(
        continentalCup,
        league,
        cal,
        userTeamId,
        continentalTeams,
      ),
    ]) {
      if (entry == null) continue;
      cupLabelsByDate.putIfAbsent(entry.$1, () => []).add(entry.$2);
    }

    final days = <CalendarDayInfo>[];
    var cursor = dateOnly(from);
    final end = dateOnly(to);
    final todayOnly = dateOnly(today);
    while (!cursor.isAfter(end)) {
      final fixture = matchesByDate[cursor];
      final isToday = cursor == todayOnly;
      final cupLabels = cupLabelsByDate[cursor] ?? const [];
      if (fixture != null) {
        final isHome = fixture.homeTeamId == userTeamId;
        final opponentId = isHome ? fixture.awayTeamId : fixture.homeTeamId;
        String? opponentName;
        for (final t in league.teams) {
          if (t.id == opponentId) {
            opponentName = t.name;
            break;
          }
        }
        days.add(
          CalendarDayInfo(
            date: cursor,
            isLeagueMatchDay: true,
            isHomeMatch: isHome,
            opponentName: opponentName,
            matchday: fixture.matchday,
            isToday: isToday,
            cupLabels: cupLabels,
          ),
        );
      } else {
        final friendly = friendlyByDate[cursor];
        String? friendlyOpponent;
        if (friendly != null) {
          final isHome = friendly.homeTeamId == userTeamId;
          final opponentId = isHome ? friendly.awayTeamId : friendly.homeTeamId;
          for (final t in [...league.teams, ...continentalTeams]) {
            if (t.id == opponentId) {
              friendlyOpponent = t.name;
              break;
            }
          }
        }
        days.add(
          CalendarDayInfo(
            date: cursor,
            isTrainingFocusDay:
                friendly == null && cursor.weekday == trainingDayOfWeek,
            isToday: isToday,
            cupLabels: cupLabels,
            isFriendlyMatchDay: friendly != null,
            opponentName: friendlyOpponent,
          ),
        );
      }
      cursor = cursor.add(const Duration(days: 1));
    }
    return days;
  }
}
