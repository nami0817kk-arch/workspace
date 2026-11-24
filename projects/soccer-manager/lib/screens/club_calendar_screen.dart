import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/calendar_engine.dart';
import '../logic/club_calendar_engine.dart';
import '../state/game_state.dart';
import '../theme/semantic_colors.dart';

/// クラブ運営の1年の予定。移籍の窓の締切・契約の期限・お金の日・夏の大会・
/// 事件・年度末と、大きな試合(カップ戦の準決勝・決勝、スーパーカップ、
/// 大陸カップ)を日付で並べる。
///
/// 2026-11-25 に作り直した: 今日から先だけを1行ずつ小さく並べ、終わった
/// 予定はたたむ(押すと開く)。行を押すと、その予定の説明が開く。
/// カレンダー(CalendarHubScreen)の「1年の予定」として出す。
class ClubCalendarScreen extends StatefulWidget {
  const ClubCalendarScreen({super.key, this.modeSwitch});

  /// 「月」と「1年の予定」の切り替え(見出しの行に置く)。
  final Widget? modeSwitch;

  @override
  State<ClubCalendarScreen> createState() => _ClubCalendarScreenState();
}

class _ClubCalendarScreenState extends State<ClubCalendarScreen> {
  bool _showPast = false;
  final Set<int> _open = {};

  static IconData _icon(ClubEventKind k) => switch (k) {
        ClubEventKind.window => Icons.swap_horiz,
        ClubEventKind.budget => Icons.pie_chart_outline,
        ClubEventKind.incident => Icons.report_problem_outlined,
        ClubEventKind.season => Icons.event_available_outlined,
        ClubEventKind.contract => Icons.assignment_outlined,
        ClubEventKind.money => Icons.payments_outlined,
        ClubEventKind.tournament => Icons.flag_outlined,
        ClubEventKind.bigMatch => Icons.emoji_events_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final save = game.save;
    if (save == null) return const SizedBox.shrink();
    final league = save.league;
    final today = game.today;
    final all = [
      ...ClubCalendarEngine.build(
        season: league.season,
        theme: game.currentLeagueTheme,
        calendar: game.seasonCalendar,
      ),
      ...game.bigMatchEvents(),
    ];
    // 日付の順(同じ日は元の順のまま)。
    final indexed = all.indexed.toList()
      ..sort((a, b) {
        final c = a.$2.date.compareTo(b.$2.date);
        return c != 0 ? c : a.$1.compareTo(b.$1);
      });
    final events = [for (final e in indexed) e.$2];
    final past = [
      for (final (i, e) in events.indexed)
        if (e.date.isBefore(today)) i
    ];
    final ahead = [
      for (final (i, e) in events.indexed)
        if (!e.date.isBefore(today)) i
    ];
    final subtle = SemanticColors.subtleText(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            children: [
              if (widget.modeSwitch != null) widget.modeSwitch!,
              Text(
                Tr.pick(
                    '今日 ${CalendarEngine.formatDate(today)} ・ 第${league.season}季',
                    'Today ${CalendarEngine.formatDate(today)} • Season ${league.season}'),
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
        ),
        if (past.isNotEmpty)
          InkWell(
            key: const ValueKey('year-past-toggle'),
            onTap: () => setState(() => _showPast = !_showPast),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Row(
                children: [
                  Icon(_showPast ? Icons.expand_less : Icons.expand_more,
                      size: 20, color: subtle),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _showPast
                          ? Tr.pick('終わった予定(${past.length}件)をたたむ',
                              'Hide past dates (${past.length})')
                          : Tr.pick('終わった予定(${past.length}件)を見る',
                              'Show past dates (${past.length})'),
                      style: TextStyle(fontSize: 13, color: subtle),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_showPast)
          for (final i in past) _row(context, i, events[i], today, null),
        if (ahead.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              Tr.pick('今季の予定は全部終わりました。', 'Everything this season is done.'),
              style: TextStyle(fontSize: 13, color: subtle),
            ),
          ),
        for (final (k, i) in ahead.indexed)
          _row(context, i, events[i], today, k == 0),
      ],
    );
  }

  /// 1件を1行で。押すと説明が開く。[first] は今日から先で最初の予定か
  /// (過ぎた予定なら null)。
  Widget _row(BuildContext context, int index, ClubEvent e, DateTime today,
      bool? first) {
    final scheme = Theme.of(context).colorScheme;
    final subtle = SemanticColors.subtleText(context);
    final isPast = first == null;
    final days = e.date.difference(today).inDays;
    final open = _open.contains(index);
    final big = e.kind == ClubEventKind.bigMatch;
    final when = [
      if (e.matchday != null) Tr.pick('第${e.matchday}節', 'MD ${e.matchday}'),
      if (!isPast && days == 0) Tr.pick('今日', 'Today'),
      if (!isPast && days > 0 && first == true) Tr.pick('あと$days日', 'in $days d'),
    ].join(' ');
    return Material(
      color: first == true ? scheme.primaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        key: ValueKey('year-row-$index'),
        borderRadius: BorderRadius.circular(6),
        onTap: () => setState(() => open ? _open.remove(index) : _open.add(index)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    SizedBox(
                      // 英語の「Sat 15 Aug」は日本語の「8/15(土)」より長い。
                      width: Tr.isEnglish ? 84 : 70,
                      child: Text(
                        CalendarEngine.formatShortDate(e.date),
                        style: TextStyle(
                          fontSize: 12,
                          color: isPast ? subtle : null,
                          fontWeight: first == true ? FontWeight.bold : null,
                        ),
                      ),
                    ),
                    Icon(
                      _icon(e.kind),
                      size: 16,
                      color: isPast
                          ? subtle
                          : big
                              ? SemanticColors.ink(
                                  context, Colors.amber.shade800,
                                  min: 3)
                              : scheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        e.title,
                        maxLines: open ? 3 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: isPast ? subtle : null,
                          fontWeight: big ? FontWeight.bold : null,
                        ),
                      ),
                    ),
                    if (when.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(when,
                          style: TextStyle(fontSize: 11, color: subtle)),
                    ],
                    Icon(open ? Icons.expand_less : Icons.expand_more,
                        size: 16, color: subtle),
                  ],
                ),
                if (open)
                  Padding(
                    padding: EdgeInsets.only(
                        left: (Tr.isEnglish ? 84 : 70) + 22, top: 2),
                    child: Text(
                      e.detail,
                      style: TextStyle(fontSize: 12, color: subtle),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
