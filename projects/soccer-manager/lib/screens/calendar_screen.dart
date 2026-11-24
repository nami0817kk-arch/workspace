import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/calendar_engine.dart';
import '../logic/day_events.dart';
import '../logic/todo_advisor.dart';
import '../state/game_state.dart';
import '../theme/semantic_colors.dart';
import 'todo_navigation.dart';

/// 1か月のカレンダー(2026-11-22)。日ごとに、自クラブの試合・給料日・
/// 放映権の入金・移籍の窓・契約の期日に印を付ける。日を押すと、その日の
/// 予定を右に出す。
///
/// 試合の日は、マスに相手の短い名前・ホームかアウェイか・終わっていれば
/// 結果を書き、大会(リーグ・カップ・大陸カップ・親善試合)ごとに色を
/// 分ける(2026-11-24)。小さな印だけでは、どの日が試合で相手が誰かが
/// 分からなかった。今日と次の試合のマスは枠で目立たせる。試合以外の予定は
/// 小さな印のまま(試合を目立たせる)。
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime? _month;
  DateTime? _selected;

  static DateTime _monthOf(DateTime d) => DateTime(d.year, d.month);

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    if (game.save == null) return const SizedBox.shrink();
    final today = game.today;
    final month = _month ?? _monthOf(today);
    final first = month;
    final last = DateTime(month.year, month.month + 1, 0);
    final events = game.calendarEventsBetween(first, last);
    final byDay = <DateTime, List<DayEvent>>{};
    for (final e in events) {
      byDay.putIfAbsent(e.date, () => []).add(e);
    }
    final next = game.nextStop;
    final nextMatch = nextMatchDate(game);
    final selected = _selected;
    final body = LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 600;
        final grid = _MonthGrid(
          month: month,
          today: today,
          nextStop: next?.date,
          nextMatch: nextMatch,
          selected: selected,
          byDay: byDay,
          onPick: (d) => setState(() => _selected = d),
        );
        final list = _DayList(
          title: selected == null
              ? Tr.pick(
                  '${month.month}月の予定',
                  'In ${CalendarEngine.formatShortDate(first).split(' ').last}',
                )
              : CalendarEngine.formatDate(selected),
          events: selected == null
              ? events.where((e) => !e.date.isBefore(first)).toList()
              : byDay[selected] ?? const [],
          today: today,
          nextStop: next,
          nextMatch: nextMatch,
        );
        final header = Row(
          children: [
            IconButton(
              tooltip: Tr.pick('前の月', 'Previous month'),
              icon: const Icon(Icons.chevron_left),
              onPressed: () => setState(() {
                _month = DateTime(month.year, month.month - 1);
                _selected = null;
              }),
            ),
            Text(
              Tr.pick(
                '${month.year}年${month.month}月',
                '${CalendarEngine.formatShortDate(first).split(' ').last} ${month.year}',
              ),
              key: const ValueKey('calendar-month-title'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            IconButton(
              tooltip: Tr.pick('次の月', 'Next month'),
              icon: const Icon(Icons.chevron_right),
              onPressed: () => setState(() {
                _month = DateTime(month.year, month.month + 1);
                _selected = null;
              }),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => setState(() {
                _month = null;
                _selected = null;
              }),
              child: Text(Tr.pick('今日へ', 'Today')),
            ),
          ],
        );
        if (!wide) {
          return ListView(
            padding: const EdgeInsets.all(8),
            children: [header, grid, const SizedBox(height: 8), list],
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // マスに相手の名前を書くので、表を広めに取る(一覧は右の残り)。
              SizedBox(
                width: (c.maxWidth * 0.68).clamp(320.0, 760.0),
                child: SingleChildScrollView(
                  child: Column(children: [header, grid]),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 8),
                  child: list,
                ),
              ),
            ],
          ),
        );
      },
    );
    return body;
  }

  /// 次の試合(まだ終わっていない、今日以降でいちばん早い自クラブの試合)の日。
  static DateTime? nextMatchDate(GameState game) {
    final today = game.today;
    final ahead = game.calendarEventsBetween(
      today,
      today.add(const Duration(days: 400)),
    );
    for (final e in ahead) {
      if (e.kind.isMatch && e.match?.played != true) return e.date;
    }
    return null;
  }
}

/// 試合の大会の分け方。リーグ戦以外は kind から決める(古い形の出来事)。
MatchCompetition? _competitionOf(DayEvent e) =>
    e.match?.competition ??
    switch (e.kind) {
      DayEventKind.leagueMatch => MatchCompetition.league,
      DayEventKind.cupMatch || DayEventKind.superCup => MatchCompetition.cup,
      DayEventKind.friendly => MatchCompetition.friendly,
      _ => null,
    };

IconData _competitionIcon(MatchCompetition c) => switch (c) {
  MatchCompetition.league => Icons.sports_soccer,
  MatchCompetition.cup => Icons.emoji_events_outlined,
  MatchCompetition.continental => Icons.public,
  MatchCompetition.friendly => Icons.handshake_outlined,
};

IconData _iconFor(DayEvent e) {
  if (_competitionOf(e) case final c?) return _competitionIcon(c);
  return switch (e.kind) {
    DayEventKind.wages => Icons.payments_outlined,
    DayEventKind.broadcast => Icons.live_tv_outlined,
    DayEventKind.windowOpens => Icons.swap_horiz,
    DayEventKind.windowDeadline => Icons.alarm,
    DayEventKind.preContracts => Icons.assignment_outlined,
    DayEventKind.optionDeadline => Icons.assignment_late_outlined,
    _ => Icons.sports_soccer,
  };
}

/// 大会の色。リーグ=主役の色、カップ=金、大陸カップ=紫、親善試合=灰青。
/// [min] は地との差(字なら 4.5、飾りなら 3)。
Color _competitionColor(
  BuildContext context,
  MatchCompetition c, {
  double min = 4.5,
}) {
  final scheme = Theme.of(context).colorScheme;
  return switch (c) {
    MatchCompetition.league => scheme.primary,
    MatchCompetition.cup => SemanticColors.ink(
      context,
      Colors.amber.shade800,
      min: min,
    ),
    MatchCompetition.continental => SemanticColors.ink(
      context,
      Colors.deepPurple.shade400,
      min: min,
    ),
    MatchCompetition.friendly => SemanticColors.ink(
      context,
      Colors.blueGrey,
      min: min,
    ),
  };
}

Color _colorFor(BuildContext context, DayEvent e) {
  if (_competitionOf(e) case final c?) {
    return _competitionColor(context, c, min: 3);
  }
  return switch (e.kind) {
    DayEventKind.windowDeadline ||
    DayEventKind.optionDeadline => SemanticColors.negative(context),
    DayEventKind.windowOpens || DayEventKind.preContracts => SemanticColors.ink(
      context,
      Colors.teal,
      min: 3,
    ),
    _ => SemanticColors.subtleText(context),
  };
}

/// ホーム・アウェイ・中立地の字(H / A / N)。
String _sideLabel(bool? home) => home == null ? 'N' : (home ? 'H' : 'A');

/// 結果の字(「勝 2-1」/「W 2-1」)と色。色だけに頼らず字でも分かるように。
(String, Color) _resultOf(BuildContext context, MatchFacts m) {
  final score = '${m.goalsFor}-${m.goalsAgainst}';
  return switch (m.outcome) {
    1 => (Tr.pick('勝 $score', 'W $score'), SemanticColors.positive(context)),
    -1 => (Tr.pick('負 $score', 'L $score'), SemanticColors.negative(context)),
    _ => (Tr.pick('分 $score', 'D $score'), SemanticColors.subtleText(context)),
  };
}

String _dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// 次の試合の枠の色。
Color _nextColor(BuildContext context) =>
    SemanticColors.ink(context, Colors.amber.shade700, min: 3);

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.today,
    required this.nextStop,
    required this.nextMatch,
    required this.selected,
    required this.byDay,
    required this.onPick,
  });

  final DateTime month;
  final DateTime today;
  final DateTime? nextStop;
  final DateTime? nextMatch;
  final DateTime? selected;
  final Map<DateTime, List<DayEvent>> byDay;
  final void Function(DateTime) onPick;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final first = DateTime(month.year, month.month, 1);
    final days = DateTime(month.year, month.month + 1, 0).day;
    // 月曜始まり。
    final lead = first.weekday - 1;
    final cells = lead + days;
    final rows = (cells / 7).ceil();
    final subtle = SemanticColors.subtleText(context);
    // 押す所は48以上。文字を大きくしたら、その分だけ伸ばす。
    final cellHeight = MediaQuery.textScalerOf(context).scale(50);
    return Column(
      children: [
        Row(
          children: [
            for (var w = 1; w <= 7; w++)
              Expanded(
                child: Center(
                  child: Text(
                    CalendarEngine.weekdayLabel(w),
                    style: TextStyle(
                      fontSize: 11,
                      color: w >= 6 ? scheme.primary : subtle,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        for (var r = 0; r < rows; r++)
          Row(
            children: [
              for (var c = 0; c < 7; c++)
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final i = r * 7 + c - lead;
                      if (i < 0 || i >= days) {
                        return SizedBox(height: cellHeight + 2);
                      }
                      final d = DateTime(month.year, month.month, i + 1);
                      return Padding(
                        padding: const EdgeInsets.all(1),
                        child: _DayCell(
                          day: d,
                          events: byDay[d] ?? const [],
                          height: cellHeight,
                          isToday: d == today,
                          isNextMatch: d == nextMatch,
                          isNextStop: d == nextStop,
                          isSelected: d == selected,
                          past: d.isBefore(today),
                          onTap: () => onPick(d),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 10,
          runSpacing: 2,
          children: [
            _legendBox(context, scheme.primary, Tr.pick('今日', 'Today')),
            _legendBox(
              context,
              _nextColor(context),
              Tr.pick('次の試合', 'Next match'),
            ),
            for (final c in MatchCompetition.values)
              _legend(
                context,
                _competitionIcon(c),
                _competitionColor(context, c, min: 3),
                switch (c) {
                  MatchCompetition.league => Tr.pick('リーグ戦', 'League'),
                  MatchCompetition.cup => Tr.pick('カップ戦', 'Cup'),
                  MatchCompetition.continental => Tr.pick(
                    '大陸カップ',
                    'Continental',
                  ),
                  MatchCompetition.friendly => Tr.pick('親善試合', 'Friendly'),
                },
              ),
            _legendText(
              context,
              Tr.pick('H ホーム・A アウェイ・N 中立地', 'H home • A away • N neutral'),
            ),
            _legend(
              context,
              Icons.payments_outlined,
              subtle,
              Tr.pick('お金', 'Money'),
            ),
            _legend(
              context,
              Icons.swap_horiz,
              Colors.teal,
              Tr.pick('移籍・契約', 'Transfers'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _legend(
    BuildContext context,
    IconData icon,
    Color color,
    String label,
  ) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 12, color: SemanticColors.ink(context, color, min: 3)),
      const SizedBox(width: 2),
      _legendText(context, label),
    ],
  );

  Widget _legendBox(BuildContext context, Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 11,
        height: 11,
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 3),
      _legendText(context, label),
    ],
  );

  Widget _legendText(BuildContext context, String label) => Text(
    label,
    style: TextStyle(fontSize: 10, color: SemanticColors.subtleText(context)),
  );
}

/// 月の表の1マス。
///
/// 試合の日: 1行目に日付とホーム/アウェイ、2行目に相手の短い名前
/// (収まらなければ「…」)、3行目に結果(終わった試合)か大会の名前。
/// 左の縁を大会の色にし、地もその色を薄く敷く。
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.events,
    required this.height,
    required this.isToday,
    required this.isNextMatch,
    required this.isNextStop,
    required this.isSelected,
    required this.past,
    required this.onTap,
  });

  final DateTime day;
  final List<DayEvent> events;
  final double height;
  final bool isToday;
  final bool isNextMatch;
  final bool isNextStop;
  final bool isSelected;
  final bool past;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subtle = SemanticColors.subtleText(context);
    final match = events.where((e) => e.kind.isMatch).firstOrNull;
    final others = events.where((e) => !e.kind.isMatch).toList();
    final comp = match == null ? null : _competitionOf(match);
    final compColor = comp == null
        ? null
        : _competitionColor(context, comp, min: 3);
    final base = isSelected
        ? scheme.primaryContainer
        : scheme.surfaceContainerLow;
    final fill = compColor == null || isSelected
        ? base
        : Color.alphaBlend(compColor.withValues(alpha: 0.16), base);
    final BorderSide side;
    if (isToday) {
      side = BorderSide(color: scheme.primary, width: 2);
    } else if (isNextMatch) {
      side = BorderSide(color: _nextColor(context), width: 2.5);
    } else if (isNextStop) {
      side = BorderSide(color: _nextColor(context), width: 1);
    } else {
      side = BorderSide.none;
    }
    final facts = match?.match;
    final dayText = Text(
      '${day.day}',
      style: TextStyle(
        fontSize: 11,
        height: 1.15,
        fontWeight: isToday || isNextMatch ? FontWeight.bold : null,
        color: past ? subtle : null,
      ),
    );
    final icons = [
      for (final e in others.take(match == null ? 3 : 2))
        Icon(
          _iconFor(e),
          size: match == null ? 13 : 11,
          color: past ? subtle : _colorFor(context, e),
        ),
    ];
    Widget content;
    if (match == null) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          dayText,
          const Spacer(),
          Wrap(spacing: 1, children: icons),
        ],
      );
    } else {
      final (String, Color)? result = facts != null && facts.played
          ? _resultOf(context, facts)
          : null;
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              dayText,
              const Spacer(),
              if (facts != null)
                _SidePill(
                  home: facts.home,
                  color: compColor!,
                  key: ValueKey('cal-side-${_dayKey(day)}'),
                ),
            ],
          ),
          const SizedBox(height: 1),
          Text(
            facts?.opponentShort ?? match.buttonLabel,
            key: ValueKey('cal-opp-${_dayKey(day)}'),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              height: 1.15,
              fontWeight: FontWeight.bold,
              color: past && result == null ? subtle : scheme.onSurface,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: Text(
                  result?.$1 ??
                      (facts == null
                          ? ''
                          : comp == MatchCompetition.league
                          ? (match.matchday == null
                                ? facts.competitionName
                                : Tr.pick(
                                    '第${match.matchday}節',
                                    'MD ${match.matchday}',
                                  ))
                          : facts.competitionName),
                  key: ValueKey('cal-note-${_dayKey(day)}'),
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.1,
                    fontWeight: result != null ? FontWeight.bold : null,
                    color:
                        result?.$2 ??
                        _competitionColor(context, comp!, min: 4.5),
                  ),
                ),
              ),
              ...icons,
            ],
          ),
        ],
      );
    }
    return Material(
      key: ValueKey('cal-day-${_dayKey(day)}'),
      color: fill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: side,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 大会の色の縁。
              if (compColor != null) Container(width: 3, color: compColor),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    compColor != null ? 3 : 4,
                    2,
                    3,
                    2,
                  ),
                  child: content,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ホーム(塗り)・アウェイ(枠)・中立地(枠)の小さな札。
class _SidePill extends StatelessWidget {
  const _SidePill({super.key, required this.home, required this.color});

  final bool? home;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final filled = home == true;
    final onFill =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black;
    final text = Theme.of(context).colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: filled ? color : null,
        border: Border.all(color: color, width: 1),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        _sideLabel(home),
        semanticsLabel: switch (home) {
          true => Tr.pick('ホーム', 'Home'),
          false => Tr.pick('アウェイ', 'Away'),
          null => Tr.pick('中立地', 'Neutral'),
        },
        style: TextStyle(
          fontSize: 9,
          height: 1.15,
          fontWeight: FontWeight.bold,
          color: filled ? onFill : text,
        ),
      ),
    );
  }
}

class _DayList extends StatelessWidget {
  const _DayList({
    required this.title,
    required this.events,
    required this.today,
    required this.nextStop,
    required this.nextMatch,
  });

  final String title;
  final List<DayEvent> events;
  final DateTime today;
  final DayEvent? nextStop;
  final DateTime? nextMatch;

  @override
  Widget build(BuildContext context) {
    final subtle = SemanticColors.subtleText(context);
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        if (events.isEmpty)
          Text(
            Tr.pick('予定はありません', 'Nothing scheduled'),
            style: TextStyle(fontSize: 12, color: subtle),
          ),
        for (final e in events) _row(context, e, subtle, scheme),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    DayEvent e,
    Color subtle,
    ColorScheme scheme,
  ) {
    final isNextStop = e.date == nextStop?.date && e.kind == nextStop?.kind;
    final m = e.match;
    final past = e.date.isBefore(today);
    final isNextMatch =
        e.kind.isMatch && e.date == nextMatch && m?.played != true;
    final comp = _competitionOf(e);
    Widget? mark;
    if (isNextMatch) {
      mark = Text(
        Tr.pick('次の試合', 'Next match'),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: SemanticColors.ink(context, Colors.amber.shade700),
        ),
      );
    } else if (isNextStop) {
      mark = Text(
        Tr.pick('次', 'Next'),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: SemanticColors.ink(context, Colors.amber.shade700),
        ),
      );
    }
    final Widget text;
    if (m == null) {
      text = Text(
        e.label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13,
          fontWeight: e.kind.isMatch ? FontWeight.w600 : null,
          color: past ? subtle : null,
        ),
      );
    } else {
      final result = m.played ? _resultOf(context, m) : null;
      final sideWord = switch (m.home) {
        true => Tr.pick('ホーム', 'home'),
        false => Tr.pick('アウェイ', 'away'),
        null => Tr.pick('中立地', 'neutral'),
      };
      text = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            Tr.pick(
              'vs ${m.opponent}(${_sideLabel(m.home)})',
              'vs ${m.opponent} (${_sideLabel(m.home)})',
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          // 結果は1行に分けて、必ず読めるように(大会名の後ろに続けると、
          // 狭い列では「勝 …」と切れていた)。
          if (result != null)
            Text(
              result.$1,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: result.$2,
              ),
            ),
          Text(
            [
              m.competitionName,
              if (e.matchday != null)
                Tr.pick('第${e.matchday}節', 'MD ${e.matchday}'),
              sideWord,
            ].join(Tr.pick('・', ' • ')),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              color: _competitionColor(context, comp!, min: 4.5),
            ),
          ),
        ],
      );
    }
    // カップ戦の日は、その日の一覧から、カップ戦の画面(勝ち上がりの表・
    // 組み合わせ)へ移れるようにする(画面を重ねない)。
    final toCups =
        (comp == MatchCompetition.cup ||
            comp == MatchCompetition.continental) &&
        e.kind == DayEventKind.cupMatch;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isNextStop || isNextMatch
            ? scheme.primaryContainer
            : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(6),
        border: comp == null
            ? null
            : Border(
                left: BorderSide(
                  color: _competitionColor(context, comp, min: 3),
                  width: 3,
                ),
              ),
      ),
      // 一覧は表の右の狭い列に入るので、「次の試合」の印は日付の下、
      // カップ戦の画面への入口は字の下に置く(横に並べると相手の名前が
      // 「vs ノー…」まで削られていた)。
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              _iconFor(e),
              size: 16,
              color: past ? subtle : _colorFor(context, e),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            // 英語の「Sat 15 Aug」は日本語の「8/15(土)」より長い。
            width: Tr.isEnglish ? 76 : 62,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  CalendarEngine.formatShortDate(e.date),
                  style: TextStyle(fontSize: 12, color: subtle),
                ),
                if (mark != null) mark,
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                text,
                if (toCups)
                  TextButton.icon(
                    key: ValueKey('calendar-to-cups-${_dayKey(e.date)}'),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    onPressed: () =>
                        openTodoPlace(context, TodoPlaces.leagueCups),
                    icon: const Icon(Icons.chevron_right, size: 18),
                    label: Text(Tr.pick('カップ戦の画面へ', 'Open Cups')),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
