import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/calendar_engine.dart';
import '../logic/day_events.dart';
import '../state/game_state.dart';
import '../theme/semantic_colors.dart';

/// 1か月のカレンダー(2026-11-22)。日ごとに、自クラブの試合・給料日・
/// 放映権の入金・移籍の窓・契約の期日に印を付ける。今日に枠、進むボタンが
/// 次に止まる日に「次」の印。日を押すと、その日の予定を右に出す。
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, this.standalone = false});

  /// 単独の画面として開いたか(上の帯の日付から)。戻るボタンを出す。
  final bool standalone;

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
    final selected = _selected;
    final body = LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 600;
      final grid = _MonthGrid(
        month: month,
        today: today,
        nextStop: next?.date,
        selected: selected,
        byDay: byDay,
        onPick: (d) => setState(() => _selected = d),
      );
      final list = _DayList(
        title: selected == null
            ? Tr.pick('${month.month}月の予定', 'This month')
            : CalendarEngine.formatDate(selected),
        events: selected == null
            ? events.where((e) => !e.date.isBefore(first)).toList()
            : byDay[selected] ?? const [],
        today: today,
        nextStop: next,
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
            Tr.pick('${month.year}年${month.month}月',
                '${month.month}/${month.year}'),
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
            SizedBox(
              width: (c.maxWidth * 0.5).clamp(320.0, 520.0),
              child: SingleChildScrollView(
                child: Column(children: [header, grid]),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: SingleChildScrollView(
                    padding: const EdgeInsets.only(top: 8), child: list)),
          ],
        ),
      );
    });
    if (!widget.standalone) return body;
    return Scaffold(
      appBar: AppBar(title: Text(Tr.pick('カレンダー', 'Calendar'))),
      body: body,
    );
  }
}

IconData _iconFor(DayEventKind k) => switch (k) {
      DayEventKind.leagueMatch => Icons.sports_soccer,
      DayEventKind.cupMatch => Icons.emoji_events_outlined,
      DayEventKind.superCup => Icons.emoji_events,
      DayEventKind.friendly => Icons.handshake_outlined,
      DayEventKind.wages => Icons.payments_outlined,
      DayEventKind.broadcast => Icons.live_tv_outlined,
      DayEventKind.windowOpens => Icons.swap_horiz,
      DayEventKind.windowDeadline => Icons.alarm,
      DayEventKind.preContracts => Icons.assignment_outlined,
      DayEventKind.optionDeadline => Icons.assignment_late_outlined,
    };

Color _colorFor(BuildContext context, DayEventKind k) {
  final scheme = Theme.of(context).colorScheme;
  return switch (k) {
    DayEventKind.leagueMatch || DayEventKind.friendly => scheme.primary,
    DayEventKind.cupMatch || DayEventKind.superCup => Colors.amber.shade700,
    DayEventKind.windowDeadline ||
    DayEventKind.optionDeadline =>
      SemanticColors.negative(context),
    DayEventKind.windowOpens || DayEventKind.preContracts => Colors.teal,
    DayEventKind.wages ||
    DayEventKind.broadcast =>
      SemanticColors.subtleText(context),
  };
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.today,
    required this.nextStop,
    required this.selected,
    required this.byDay,
    required this.onPick,
  });

  final DateTime month;
  final DateTime today;
  final DateTime? nextStop;
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
    return Column(
      children: [
        Row(
          children: [
            for (var w = 1; w <= 7; w++)
              Expanded(
                child: Center(
                  child: Text(CalendarEngine.weekdayLabel(w),
                      style: TextStyle(
                          fontSize: 11,
                          color: w >= 6 ? scheme.primary : subtle)),
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
                  child: Builder(builder: (context) {
                    final i = r * 7 + c - lead;
                    if (i < 0 || i >= days) return const SizedBox(height: 44);
                    final d = DateTime(month.year, month.month, i + 1);
                    final evs = byDay[d] ?? const [];
                    final isToday = d == today;
                    final isNext = d == nextStop;
                    final isSel = d == selected;
                    final past = d.isBefore(today);
                    return Padding(
                      padding: const EdgeInsets.all(1),
                      child: Material(
                        color: isSel
                            ? scheme.primaryContainer
                            : evs.any((e) => e.kind.isMatch)
                                ? scheme.surfaceContainerHigh
                                : scheme.surfaceContainerLow,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                          side: isToday
                              ? BorderSide(color: scheme.primary, width: 2)
                              : isNext
                                  ? BorderSide(
                                      color: Colors.amber.shade700, width: 2)
                                  : BorderSide.none,
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(4),
                          onTap: () => onPick(d),
                          child: SizedBox(
                            height: 44,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 2),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${d.day}',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight:
                                              isToday ? FontWeight.bold : null,
                                          color: past ? subtle : null)),
                                  const Spacer(),
                                  Wrap(
                                    spacing: 1,
                                    children: [
                                      for (final e in evs.take(3))
                                        Icon(_iconFor(e.kind),
                                            size: 13,
                                            color: past
                                                ? subtle
                                                : _colorFor(context, e.kind)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
            ],
          ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 10,
          runSpacing: 2,
          children: [
            _legend(context, Icons.crop_square, scheme.primary,
                Tr.pick('今日', 'Today')),
            _legend(context, Icons.crop_square, Colors.amber.shade700,
                Tr.pick('次に進む日', 'Next stop')),
            _legend(context, Icons.sports_soccer, scheme.primary,
                Tr.pick('リーグ戦', 'League')),
            _legend(context, Icons.emoji_events_outlined, Colors.amber.shade700,
                Tr.pick('カップ戦', 'Cup')),
            _legend(context, Icons.payments_outlined, subtle,
                Tr.pick('お金', 'Money')),
            _legend(context, Icons.swap_horiz, Colors.teal,
                Tr.pick('移籍・契約', 'Transfers')),
          ],
        ),
      ],
    );
  }

  Widget _legend(
          BuildContext context, IconData icon, Color color, String label) =>
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 10, color: SemanticColors.subtleText(context))),
        ],
      );
}

class _DayList extends StatelessWidget {
  const _DayList({
    required this.title,
    required this.events,
    required this.today,
    required this.nextStop,
  });

  final String title;
  final List<DayEvent> events;
  final DateTime today;
  final DayEvent? nextStop;

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
          Text(Tr.pick('予定はありません', 'Nothing scheduled'),
              style: TextStyle(fontSize: 12, color: subtle)),
        for (final e in events)
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: e.date == nextStop?.date && e.kind == nextStop?.kind
                  ? scheme.primaryContainer
                  : scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(_iconFor(e.kind),
                    size: 16,
                    color: e.date.isBefore(today)
                        ? subtle
                        : _colorFor(context, e.kind)),
                const SizedBox(width: 8),
                SizedBox(
                  width: 64,
                  child: Text(CalendarEngine.formatShortDate(e.date),
                      style: TextStyle(fontSize: 12, color: subtle)),
                ),
                Expanded(
                  child: Text(e.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: e.kind.isMatch ? FontWeight.w600 : null,
                          color: e.date.isBefore(today) ? subtle : null)),
                ),
                if (e.date == nextStop?.date && e.kind == nextStop?.kind)
                  Text(Tr.pick('次', 'Next'),
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade700)),
              ],
            ),
          ),
      ],
    );
  }
}
