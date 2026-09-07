import 'package:flutter/material.dart';

import '../../models/attributes.dart';
import '../../models/career.dart';
import '../../models/season.dart';
import '../../state/career_controller.dart';
import 'match_screen.dart';
import 'season_end_screen.dart';

/// キャリアの拠点。次の試合・練習・成績・順位表・これまでの記録をここから見る。
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

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('キャリアを削除しますか'),
        content: const Text('この選手の記録はすべて消えます。元に戻せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('やめる'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('削除する'),
          ),
        ],
      ),
    );
    if (ok == true) await controller.deleteCareer();
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
          actions: [
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'delete') _confirmDelete(context);
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'delete', child: Text('キャリアを削除')),
              ],
            ),
          ],
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
              onTraining: controller.setTraining,
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
    required this.onTraining,
  });

  final CareerState state;
  final SeasonStats stats;
  final VoidCallback onPlay;
  final VoidCallback onEndSeason;
  final Future<void> Function(AttributeKey?) onTraining;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final finished = state.seasonFinished;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _PlayerCard(state: state),
        const SizedBox(height: 16),
        if (!finished) ...[
          _TrainingCard(state: state, onTraining: onTraining),
          const SizedBox(height: 16),
        ],
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
    final muted = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
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
                        style: muted,
                      ),
                      Text(
                        '年俸 ${_yen(state.salary)}  ·  代理人 ${state.agent.name}',
                        style: muted,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                Chip(
                  label: Text('ポテンシャル ${player.potentialBand}'),
                  visualDensity: VisualDensity.compact,
                ),
                for (final t in player.traits)
                  Tooltip(
                    message: t.description,
                    child: Chip(
                      label: Text(t.label),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _ConditionBar(condition: player.condition),
            const SizedBox(height: 12),
            for (final key in AttributeKey.values)
              if (key != AttributeKey.goalkeeping ||
                  player.position == Position.gk)
                _AttributeBar(label: key.label, value: player.attributes[key]),
          ],
        ),
      ),
    );
  }

  static String _yen(int man) =>
      man >= 10000 ? '${(man / 10000).toStringAsFixed(1)}億円' : '$man万円';
}

class _ConditionBar extends StatelessWidget {
  const _ConditionBar({required this.condition});

  final int condition;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = condition >= 70
        ? theme.colorScheme.primary
        : condition >= 40
            ? theme.colorScheme.tertiary
            : theme.colorScheme.error;
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text('コンディション', style: theme.textTheme.bodySmall),
        ),
        SizedBox(
          width: 28,
          child: Text('$condition', style: theme.textTheme.bodySmall),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: condition / 100,
              minHeight: 8,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _TrainingCard extends StatelessWidget {
  const _TrainingCard({required this.state, required this.onTraining});

  final CareerState state;
  final Future<void> Function(AttributeKey?) onTraining;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keys = [
      for (final k in AttributeKey.values)
        if (k != AttributeKey.goalkeeping || state.player.position == Position.gk)
          k,
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('今週の練習', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              state.player.atPotential
                  ? 'ポテンシャルに達している。練習では伸びない。休養で試合に備える。'
                  : '練習は疲れる代わりに伸びる可能性がある。休養は戻すだけ。',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('休養'),
                  selected: state.training == null,
                  onSelected: (_) => onTraining(null),
                ),
                for (final k in keys)
                  ChoiceChip(
                    label: Text(k.label),
                    selected: state.training == k,
                    onSelected: (_) => onTraining(k),
                  ),
              ],
            ),
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
            width: 100,
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
                '${record.stats.goals}G ${record.stats.assists}A  ·  '
                '年俸 ${record.salary}万円',
              ),
              trailing: Text(
                record.stats.appearances == 0
                    ? '—'
                    : record.stats.averageRating.toStringAsFixed(2),
                style: theme.textTheme.titleMedium,
              ),
            ),
          ),
      ],
    );
  }
}
