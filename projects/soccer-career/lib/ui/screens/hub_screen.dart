import 'package:flutter/material.dart';

import '../../models/attributes.dart';
import '../../models/career.dart';
import '../../models/season.dart';
import '../../state/career_controller.dart';
import 'match_screen.dart';
import 'season_end_screen.dart';

/// キャリアの拠点。次の試合・成績・順位表・これまでの記録をここから見る。
class HubScreen extends StatelessWidget {
  const HubScreen({super.key, required this.controller});

  final CareerController controller;

  Future<void> _playNext(BuildContext context) async {
    controller.startNextMatch();
    if (controller.currentMatch == null) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MatchScreen(controller: controller),
    ));
  }

  Future<void> _endSeason(BuildContext context) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SeasonEndScreen(controller: controller),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final state = controller.state!;
    final stats = state.seasonStats;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${state.player.name}  ${state.year}シーズン'),
          bottom: const TabBar(tabs: [
            Tab(text: 'ホーム'),
            Tab(text: '順位表'),
            Tab(text: 'キャリア'),
          ]),
        ),
        body: TabBarView(
          children: [
            _HomeTab(
              state: state,
              stats: stats,
              onPlay: () => _playNext(context),
              onEndSeason: () => _endSeason(context),
            ),
            _TableTab(state: state),
            _CareerTab(state: state),
          ],
        ),
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({
    required this.state,
    required this.stats,
    required this.onPlay,
    required this.onEndSeason,
  });

  final CareerState state;
  final SeasonStats stats;
  final VoidCallback onPlay;
  final VoidCallback onEndSeason;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final finished = state.seasonFinished;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _PlayerCard(state: state),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('今シーズンの成績', style: theme.textTheme.titleSmall),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _stat(theme, '出場', '${stats.appearances}'),
                    _stat(theme, 'ゴール', '${stats.goals}'),
                    _stat(theme, 'アシスト', '${stats.assists}'),
                    _stat(
                        theme,
                        '平均評価',
                        stats.appearances == 0
                            ? '—'
                            : stats.averageRating.toStringAsFixed(2)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (finished)
          FilledButton(
            onPressed: onEndSeason,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('シーズンを終える'),
            ),
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('第${state.matchday}節 / ${state.fixtures.length}',
                      style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  Text(
                    '${state.isHome(state.matchday) ? "H" : "A"}  '
                    'vs ${state.opponentFor(state.matchday).name}',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: onPlay,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('試合へ'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 24),
        Text('直近の試合', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        if (state.results.isEmpty)
          Text('まだ試合をしていない。',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant))
        else
          for (final r in state.results.reversed.take(8))
            _ResultRow(result: r),
      ],
    );
  }

  Widget _stat(ThemeData theme, String label, String value) => Column(
        children: [
          Text(label,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          Text(value, style: theme.textTheme.titleLarge),
        ],
      );
}

class _PlayerCard extends StatelessWidget {
  const _PlayerCard({required this.state});

  final CareerState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final player = state.player;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  child: Text('${player.overall}',
                      style: theme.textTheme.titleMedium),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(player.name, style: theme.textTheme.titleMedium),
                      Text(
                        '${player.position.label}  ${player.age}歳  ·  '
                        '${state.club.name}（${state.club.tier}部）',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            for (final key in AttributeKey.values)
              _AttributeBar(
                  label: key.label, value: player.attributes[key]),
          ],
        ),
      ),
    );
  }
}

class _AttributeBar extends StatelessWidget {
  const _AttributeBar({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(label, style: theme.textTheme.bodySmall),
          ),
          SizedBox(
            width: 28,
            child: Text('$value', style: theme.textTheme.bodySmall),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: value / 99,
                minHeight: 6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.result});

  final MatchResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = result.won
        ? theme.colorScheme.primary
        : result.drawn
            ? theme.colorScheme.onSurfaceVariant
            : theme.colorScheme.error;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: SizedBox(
        width: 44,
        child: Text(result.scoreLine,
            style: theme.textTheme.titleSmall?.copyWith(color: color)),
      ),
      title: Text('${result.home ? "H" : "A"}  ${result.opponentName}'),
      subtitle: Text(result.appearance.label),
      trailing: Text(
        result.rating?.toStringAsFixed(1) ?? '—',
        style: theme.textTheme.titleSmall,
      ),
    );
  }
}

class _TableTab extends StatelessWidget {
  const _TableTab({required this.state});

  final CareerState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = state.sortedTable;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        final mine = row.clubId == state.club.id;
        return Container(
          color: mine ? theme.colorScheme.primaryContainer : null,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              SizedBox(width: 28, child: Text('${index + 1}')),
              Expanded(
                child: Text(row.clubName,
                    overflow: TextOverflow.ellipsis,
                    style: mine
                        ? theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.bold)
                        : theme.textTheme.bodyMedium),
              ),
              SizedBox(
                  width: 32,
                  child: Text('${row.played}', textAlign: TextAlign.end)),
              SizedBox(
                  width: 40,
                  child: Text(
                      row.goalDifference >= 0
                          ? '+${row.goalDifference}'
                          : '${row.goalDifference}',
                      textAlign: TextAlign.end)),
              SizedBox(
                width: 40,
                child: Text('${row.points}',
                    textAlign: TextAlign.end,
                    style: theme.textTheme.titleSmall),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CareerTab extends StatelessWidget {
  const _CareerTab({required this.state});

  final CareerState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (state.history.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'シーズンを終えると、ここに記録が積み上がる。',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final record in state.history.reversed)
          Card(
            child: ListTile(
              title: Text('${record.year}  ${record.clubName}'),
              subtitle: Text(
                '${record.tier}部 ${record.leaguePosition}位  ·  '
                '${record.stats.appearances}試合 '
                '${record.stats.goals}G ${record.stats.assists}A',
              ),
              trailing: Text(
                record.stats.averageRating.toStringAsFixed(2),
                style: theme.textTheme.titleMedium,
              ),
            ),
          ),
      ],
    );
  }
}
