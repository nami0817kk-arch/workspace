import '../l10n/tr.dart';
import '../models/league_theme.dart';
import 'contract_engine.dart';
import 'money_calendar.dart';
import 'season_calendar.dart';
import 'summer_tournament.dart';
import 'transfer_window.dart';

/// 年間予定の種類。
enum ClubEventKind {
  window,
  budget,
  incident,
  season,
  contract,
  money,
  tournament,

  /// 大きな試合(カップ戦の準決勝・決勝、スーパーカップ、大陸カップ)。
  /// 日付はゲームの状態から決まるので、GameState.bigMatchEvents が作る。
  bigMatch,
}

/// クラブ運営の年間予定の1件。
class ClubEvent {
  const ClubEvent({
    required this.date,
    required this.kind,
    required this.title,
    required this.detail,
    this.matchday,
  });

  /// その日(締切ならその日まで)。
  final DateTime date;
  final ClubEventKind kind;
  final String title;
  final String detail;

  /// 節に結びつく予定なら、その節。
  final int? matchday;
}

/// 1シーズン(7月1日〜翌6月30日)の、クラブ運営の年間予定を日付で並べる。
///
/// 締切と期限(移籍の窓・仮契約の解禁・延長オプション・年度末)、お金の日
/// (放映権の入金)、夏の大会の合流、オーナーの判断が要る節を、ゲームの
/// 規則と同じ日付の式で出す(TransferWindowCalendar・ContractEngine・
/// MoneyCalendar・SummerTournament・GameState.isOwnerEventMatchday)。
class ClubCalendarEngine {
  const ClubCalendarEngine._();

  /// 事件が起きる節(12節ごと、6・18・30節)。
  static bool isIncidentMatchday(int matchday) =>
      matchday > 0 && matchday % 12 == 6;

  static List<ClubEvent> build({
    required int season,
    required LeagueTheme theme,
    required SeasonCalendar calendar,
  }) {
    final y = SeasonCalendar.startYear(season);
    final start = MoneyCalendar.fiscalYearStart(season);
    final end = MoneyCalendar.fiscalYearEnd(season);
    final summer = TransferWindowCalendar.summerOf(y, theme);
    final winter = TransferWindowCalendar.winterOf(y + 1, theme);
    final tournament = SummerTournament.of(y);
    final dates = calendar.matchdayDates;
    final fy = MoneyCalendar.fiscalYearLabel(season);
    String md(DateTime d) => TransferWindowCalendar.formatMonthDay(d);

    final events = <ClubEvent>[
      ClubEvent(
        date: start,
        kind: ClubEventKind.budget,
        title: Tr.pick('$fy年度が始まる・予算を決める', '$fy financial year starts: set the budget'),
        detail: Tr.pick('補強・育成・施設・営業・配当の配分を確定する。',
            'Fix the split between signings, youth, facilities, sales and dividends.'),
      ),
      if (tournament != null)
        ClubEvent(
          date: tournament.returnDate,
          kind: ClubEventKind.tournament,
          title: Tr.pick('${tournament.name}に出た選手が合流',
              'Players from the ${tournament.name} rejoin'),
          detail: Tr.pick('決勝(${md(tournament.ends)})のあと${SummerTournament.restDays}日休んでから戻る。それまでは試合に出せない。活躍した選手は市場価値が上がっている。',
              'They rest ${SummerTournament.restDays} days after the final (${md(tournament.ends)}) and cannot play until they return. Those who shone are worth more.'),
        ),
      if (dates.isNotEmpty)
        ClubEvent(
          date: dates.first,
          matchday: 1,
          kind: ClubEventKind.season,
          title: Tr.pick('開幕', 'Opening day'),
          detail: Tr.pick('リーグ戦が始まる。', 'The league season starts.'),
        ),
      ClubEvent(
        date: summer.closes,
        kind: ClubEventKind.window,
        title: Tr.pick('夏の移籍期間の締切', 'Summer transfer deadline'),
        detail: Tr.pick('補強と放出はこの日まで(${md(summer.opens)}から開いている)。締切の日に登録の名簿が決まる。締切のあとも自由契約の選手は取れる。',
            'Last day for signings and sales (open since ${md(summer.opens)}). The registered squad is fixed on deadline day. Free agents can still be signed after it.'),
      ),
      for (var i = 0; i < 4; i++)
        ClubEvent(
          date: MoneyCalendar.broadcastDates(season)[i],
          kind: ClubEventKind.money,
          title: Tr.pick('放映権の入金(${i + 1}/4)', 'Broadcast payment (${i + 1}/4)'),
          detail: Tr.pick('年額の4分の1が入る。', 'A quarter of the annual amount comes in.'),
        ),
      for (var m = 1; m <= dates.length; m++)
        if (isIncidentMatchday(m))
          ClubEvent(
            date: dates[m - 1],
            matchday: m,
            kind: ClubEventKind.incident,
            title: Tr.pick('事件の判断(第$m節)', 'Incident decision (MD $m)'),
            detail: Tr.pick('移籍要求・スポンサー撤退など、オーナーの判断が要る。',
                'Transfer demands, sponsor exits and similar calls for the owner.'),
          ),
      ClubEvent(
        date: DateTime(y + 1, 1, 1),
        kind: ClubEventKind.contract,
        title: Tr.pick('仮契約の解禁', 'Pre-contract season opens'),
        detail: Tr.pick('今季末で契約が切れる他のクラブの選手と、移籍金なしの仮契約を結べる。自クラブの満了の年の選手も狙われる。',
            'You can agree free pre-contracts with players at other clubs whose deals expire this summer. Your own expiring players can be approached too.'),
      ),
      ClubEvent(
        date: winter.opens,
        kind: ClubEventKind.window,
        title: Tr.pick('冬の移籍期間が開く', 'Winter window opens'),
        detail: Tr.pick('補強の追加と、不要な選手の放出ができる。半年のローンはここで戻る。',
            'Add signings and move on players you do not need. Half-season loans end here.'),
      ),
      ClubEvent(
        date: winter.closes,
        kind: ClubEventKind.window,
        title: Tr.pick('冬の移籍期間の締切', 'Winter transfer deadline'),
        detail: Tr.pick('締切の日に後半戦の登録の名簿が決まる。',
            'The registered squad for the rest of the season is fixed on deadline day.'),
      ),
      ClubEvent(
        date: ContractEngine.optionDeadline(y + 1),
        kind: ClubEventKind.contract,
        title: Tr.pick('延長オプションの期限', '1-year option deadline'),
        detail: Tr.pick('今季末で切れる選手の1年延長は、この日までに行使する。過ぎると6月30日で満了する。',
            'Take up 1-year options on expiring players by this day, or they run out on 30 Jun.'),
      ),
      if (dates.isNotEmpty)
        ClubEvent(
          date: dates.last,
          matchday: dates.length,
          kind: ClubEventKind.season,
          title: Tr.pick('最終節', 'Final matchday'),
          detail: Tr.pick('順位が決まる。昇降格は年度末に動く。',
              'The table is settled. Promotion and relegation happen at year end.'),
        ),
      ClubEvent(
        date: end,
        kind: ClubEventKind.season,
        title: Tr.pick('年度末: 決算とライセンスの審査', 'Year end: accounts and licence review'),
        detail: Tr.pick('財務の規則を満たすか審査される。違反は罰金・補強禁止・勝ち点剥奪。',
            'Financial rules are checked. Breaches bring fines, signing bans or point deductions.'),
      ),
      ClubEvent(
        date: end,
        kind: ClubEventKind.season,
        title: Tr.pick('年度末: 株主総会と配当', 'Year end: shareholder meeting and dividend'),
        detail: Tr.pick('配当・増資・返済を決める。期待が足りなければ叱責される。',
            'Decide dividends, capital raises and repayments.'),
      ),
      ClubEvent(
        date: end,
        kind: ClubEventKind.contract,
        title: Tr.pick('契約の満了', 'Contracts expire'),
        detail: Tr.pick('6月30日で契約が切れる選手は無償で去る。主力は更新を。',
            'Players whose deals end on 30 Jun leave for free. Renew your key men.'),
      ),
    ];
    // 同じ日は書いた順のまま(安定な並べ替え)。
    final indexed = events.asMap().entries.toList()
      ..sort((a, b) {
        final c = a.value.date.compareTo(b.value.date);
        return c != 0 ? c : a.key.compareTo(b.key);
      });
    return [for (final e in indexed) e.value];
  }
}
