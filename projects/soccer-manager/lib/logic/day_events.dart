import '../l10n/tr.dart';
import '../models/league_theme.dart';
import 'contract_engine.dart';
import 'money_calendar.dart';
import 'season_calendar.dart';
import 'transfer_window.dart';

/// カレンダーに載せる出来事の種類。
enum DayEventKind {
  leagueMatch,
  cupMatch,
  superCup,
  friendly,
  wages,
  broadcast,
  windowOpens,
  windowDeadline,
  preContracts,
  optionDeadline,
}

extension DayEventKindInfo on DayEventKind {
  /// 試合の日か(進むボタンで試合をする日)。
  bool get isMatch =>
      this == DayEventKind.leagueMatch ||
      this == DayEventKind.cupMatch ||
      this == DayEventKind.superCup ||
      this == DayEventKind.friendly;

  /// 同じ日に重なったときの順(小さいほど先に見せる)。
  int get priority => switch (this) {
        DayEventKind.leagueMatch => 0,
        DayEventKind.cupMatch => 1,
        DayEventKind.superCup => 2,
        DayEventKind.friendly => 3,
        DayEventKind.windowDeadline => 4,
        DayEventKind.optionDeadline => 5,
        DayEventKind.windowOpens => 6,
        DayEventKind.preContracts => 7,
        DayEventKind.broadcast => 8,
        DayEventKind.wages => 9,
      };
}

/// カレンダーの1日の出来事。
class DayEvent {
  const DayEvent({
    required this.date,
    required this.kind,
    required this.label,
    this.shortLabel,
    this.matchday,
    this.match,
  });

  final DateTime date;
  final DayEventKind kind;

  /// 試合なら、相手・ホームかアウェイか・大会・結果(カレンダーのマスに出す)。
  final MatchFacts? match;

  /// カレンダーの日の欄・一覧に出す字(例「第8節 vs 北風シティ(H)」)。
  final String label;

  /// 進むボタンに出す短い字(例「第8節」)。無ければ [label]。
  final String? shortLabel;

  /// リーグ戦なら第何節か。
  final int? matchday;

  String get buttonLabel => shortLabel ?? label;
}

/// 試合の大会の分け方(カレンダーのマスの色)。
enum MatchCompetition { league, cup, continental, friendly }

/// カレンダーのマスに出す、1試合の中身。
class MatchFacts {
  const MatchFacts({
    required this.opponent,
    required this.competition,
    required this.competitionName,
    this.home,
    this.goalsFor,
    this.goalsAgainst,
  });

  /// 相手の名前(そのまま)。
  final String opponent;
  final MatchCompetition competition;

  /// 大会の名前(「リーグ戦」「○○カップ」など)。
  final String competitionName;

  /// 自分がホームか。中立地・未定なら null。
  final bool? home;

  /// 終わった試合の自分の得点・失点。まだなら null。
  final int? goalsFor;
  final int? goalsAgainst;

  bool get played => goalsFor != null && goalsAgainst != null;

  /// 勝ちなら 1、分けなら 0、負けなら -1。まだなら null。
  int? get outcome => !played ? null : (goalsFor! - goalsAgainst!).sign;

  /// マス目に入れる相手の短い名前。クラブ名は「町 愛称」の形なので、
  /// 見分けのつく愛称(最後の語)を使う(ロンドンやマンチェスターは
  /// 同じ町のクラブがいくつもある)。収まらない分は画面が「…」で切る。
  static String shortName(String name) {
    final words =
        name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length < 2) return name.trim();
    final last = words.last;
    // 「FC」「SC」のような短い印だけが残るときは、その前の語を使う。
    if (last.length <= 3 && last.toUpperCase() == last) {
      return words[words.length - 2];
    }
    return last;
  }

  String get opponentShort => shortName(opponent);
}

/// 試合以外の、日付で決まっている出来事(給料日・放映権の入金・移籍の窓・
/// 契約の期日)。どれもゲームの中で実際にその日に処理が走るもの
/// (GameState._setToday)なので、カレンダーと進むボタンの止まる日に使う。
class DayEvents {
  DayEvents._();

  /// [after] より後で [until] 以前の、試合以外の出来事を日付順に。
  static List<DayEvent> calendarEvents(
    DateTime after,
    DateTime until,
    LeagueTheme theme,
  ) {
    final a = SeasonCalendar.dateOnly(after);
    final u = SeasonCalendar.dateOnly(until);
    bool inRange(DateTime d) => d.isAfter(a) && !d.isAfter(u);
    final out = <DayEvent>[
      for (final d in MoneyCalendar.monthEndsBetween(a, u))
        DayEvent(
          date: d,
          kind: DayEventKind.wages,
          label: Tr.pick('給料日(選手・スタッフ)', 'Payday (players and staff)'),
          shortLabel: Tr.pick('給料日', 'Payday'),
        ),
      for (final d in MoneyCalendar.broadcastDatesBetween(a, u))
        DayEvent(
          date: d,
          kind: DayEventKind.broadcast,
          label: Tr.pick('放映権の入金', 'TV money arrives'),
          shortLabel: Tr.pick('放映権の入金', 'TV money'),
        ),
    ];
    for (var y = a.year; y <= u.year; y++) {
      for (final p in [
        TransferWindowCalendar.winterOf(y, theme),
        TransferWindowCalendar.summerOf(y, theme),
      ]) {
        if (inRange(p.opens)) {
          out.add(DayEvent(
            date: p.opens,
            kind: DayEventKind.windowOpens,
            label: Tr.pick('${p.kind.label}が開く', 'The ${p.kind.label} opens'),
            shortLabel: Tr.pick('移籍の窓が開く', 'Window opens'),
          ));
        }
        if (inRange(p.closes)) {
          out.add(DayEvent(
            date: p.closes,
            kind: DayEventKind.windowDeadline,
            label: Tr.pick('${p.kind.label}の締切', '${p.kind.label} deadline'),
            shortLabel: Tr.pick('移籍の締切', 'Deadline day'),
          ));
        }
      }
      final pre = DateTime(y, 1, 1);
      if (inRange(pre)) {
        out.add(DayEvent(
          date: pre,
          kind: DayEventKind.preContracts,
          label: Tr.pick('仮契約の解禁(今季末で切れる選手と話せる)',
              'Pre-contracts open (players out of contract this summer)'),
          shortLabel: Tr.pick('仮契約の解禁', 'Pre-contracts'),
        ));
      }
      final option = ContractEngine.optionDeadline(y);
      if (inRange(option)) {
        out.add(DayEvent(
          date: option,
          kind: DayEventKind.optionDeadline,
          label: Tr.pick('延長オプションの期限', 'Contract option deadline'),
          shortLabel: Tr.pick('オプションの期限', 'Option deadline'),
        ));
      }
    }
    sortEvents(out);
    return out;
  }

  /// 日付順、同じ日は試合を先に。
  static void sortEvents(List<DayEvent> events) => events.sort((x, y) {
        final c = x.date.compareTo(y.date);
        return c != 0 ? c : x.kind.priority.compareTo(y.kind.priority);
      });
}
