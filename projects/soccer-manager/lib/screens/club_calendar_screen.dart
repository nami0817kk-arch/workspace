import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/calendar_engine.dart';
import '../logic/club_calendar_engine.dart';
import '../state/game_state.dart';
import '../widgets/responsive_body.dart';

/// クラブ運営の年間予定。移籍の窓の締切・契約の期限・お金の日・夏の大会・
/// 事件・年度末を日付で並べ、今日に印を付ける。
class ClubCalendarScreen extends StatelessWidget {
  const ClubCalendarScreen({super.key});

  IconData _icon(ClubEventKind k) => switch (k) {
        ClubEventKind.window => Icons.swap_horiz,
        ClubEventKind.budget => Icons.pie_chart_outline,
        ClubEventKind.incident => Icons.report_problem_outlined,
        ClubEventKind.season => Icons.event_available_outlined,
        ClubEventKind.contract => Icons.assignment_outlined,
        ClubEventKind.money => Icons.payments_outlined,
        ClubEventKind.tournament => Icons.flag_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final save = game.save;
    return Scaffold(
      appBar: AppBar(title: Text(Tr.pick('クラブの年間予定', 'Club calendar'))),
      body: save == null
          ? const SizedBox.shrink()
          : ResponsiveBody(child: _body(context, game)),
    );
  }

  Widget _body(BuildContext context, GameState game) {
    final league = game.save!.league;
    final today = game.today;
    final events = ClubCalendarEngine.build(
      season: league.season,
      theme: game.currentLeagueTheme,
      calendar: game.seasonCalendar,
    );
    final scheme = Theme.of(context).colorScheme;
    // 今日以降で最初の予定に「次」の印を付ける。
    final upcomingIndex = events.indexWhere((e) => !e.date.isBefore(today));
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(
          Tr.pick('今日 ${CalendarEngine.formatDate(today)} ・ 第${league.season}季',
              'Today ${CalendarEngine.formatDate(today)} • Season ${league.season}'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < events.length; i++)
          Builder(builder: (context) {
            final e = events[i];
            final past = e.date.isBefore(today);
            final days = e.date.difference(today).inDays;
            return Card(
              color: i == upcomingIndex
                  ? scheme.primaryContainer
                  : past
                      ? scheme.surfaceContainerLow
                      : null,
              child: ListTile(
                leading: Icon(_icon(e.kind),
                    color: past ? scheme.onSurfaceVariant : scheme.primary),
                title: Text(e.title),
                subtitle: Text(e.detail),
                trailing: Text(
                  [
                    CalendarEngine.formatShortDate(e.date),
                    if (e.matchday != null)
                      Tr.pick('第${e.matchday}節', 'MD ${e.matchday}'),
                    if (!past && days == 0) Tr.pick('今日', 'Today'),
                    if (!past && days > 0 && i == upcomingIndex)
                      Tr.pick('あと$days日', 'in $days d'),
                  ].join('\n'),
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            );
          }),
      ],
    );
  }
}
