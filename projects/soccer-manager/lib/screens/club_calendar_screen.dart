import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/club_calendar_engine.dart';
import '../state/game_state.dart';
import '../widgets/responsive_body.dart';

/// クラブ運営の年間予定。移籍期間・予算・事件・決算・総会を節に並べ、
/// いまの節に印を付ける。
class ClubCalendarScreen extends StatelessWidget {
  const ClubCalendarScreen({super.key});

  IconData _icon(ClubEventKind k) => switch (k) {
        ClubEventKind.window => Icons.swap_horiz,
        ClubEventKind.budget => Icons.pie_chart_outline,
        ClubEventKind.incident => Icons.report_problem_outlined,
        ClubEventKind.season => Icons.event_available_outlined,
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
    final total = league.fixtures.isEmpty
        ? 0
        : league.fixtures.map((f) => f.matchday).reduce((a, b) => a > b ? a : b);
    final next = league.nextUnplayedFixture?.matchday ?? total + 1;
    final events = ClubCalendarEngine.build(totalMatchdays: total);
    final scheme = Theme.of(context).colorScheme;
    // いまの節以降で最初の予定に「次」の印を付ける。
    final upcomingIndex = events.indexWhere((e) => e.matchday >= next);
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(
          Tr.pick('第${league.season}季 ・ 次は第$next節', 'Season ${league.season} • next: MD $next'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < events.length; i++)
          Card(
            color: i == upcomingIndex
                ? scheme.primaryContainer
                : events[i].matchday < next
                    ? scheme.surfaceContainerLow
                    : null,
            child: ListTile(
              leading: Icon(_icon(events[i].kind),
                  color: events[i].matchday < next
                      ? scheme.onSurfaceVariant
                      : scheme.primary),
              title: Text(events[i].title),
              subtitle: Text(events[i].detail),
              trailing: Text(
                events[i].matchday == 0
                    ? Tr.pick('開幕前', 'Pre')
                    : events[i].matchday > total
                        ? Tr.pick('終了時', 'End')
                        : Tr.pick('第${events[i].matchday}節', 'MD ${events[i].matchday}'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
      ],
    );
  }
}
