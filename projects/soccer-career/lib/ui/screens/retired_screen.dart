import 'package:flutter/material.dart';

import '../../state/career_controller.dart';

/// 引退後の画面。通算成績と歩みを見せる。ここから新しいキャリアを始められる。
class RetiredScreen extends StatelessWidget {
  const RetiredScreen({super.key, required this.controller});

  final CareerController controller;

  Future<void> _newCareer(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新しいキャリアを始めますか'),
        content: const Text('この選手の記録は消えます。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('やめる'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('始める'),
          ),
        ],
      ),
    );
    if (ok == true) await controller.deleteCareer();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = controller.state!;
    final totals = state.careerTotals;
    final seasons = state.history;
    final best = seasons.isEmpty
        ? null
        : seasons.reduce((a, b) => a.leaguePosition <= b.leaguePosition &&
                a.tier <= b.tier
            ? a
            : b);

    return Scaffold(
      appBar: AppBar(title: const Text('引退')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(state.player.name, style: theme.textTheme.headlineSmall),
            Text(
              '${state.player.position.label}  ${seasons.length}シーズン  '
              '${state.player.age}歳で引退',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('通算', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _stat(theme, '出場', '${totals.appearances}'),
                        _stat(theme, 'ゴール', '${totals.goals}'),
                        _stat(theme, 'アシスト', '${totals.assists}'),
                        _stat(
                            theme,
                            '平均評価',
                            totals.appearances == 0
                                ? '—'
                                : totals.averageRating.toStringAsFixed(2)),
                      ],
                    ),
                    if (best != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        '最高成績: ${best.year}  ${best.clubName}  '
                        '${best.tier}部 ${best.leaguePosition}位',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('歩み', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final record in seasons)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('${record.year}  ${record.clubName}'),
                subtitle: Text(
                  '${record.tier}部 ${record.leaguePosition}位  ·  '
                  '${record.stats.appearances}試合 '
                  '${record.stats.goals}G ${record.stats.assists}A',
                ),
                trailing: Text(
                  record.stats.appearances == 0
                      ? '—'
                      : record.stats.averageRating.toStringAsFixed(2),
                  style: theme.textTheme.titleSmall,
                ),
              ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: () => _newCareer(context),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('新しいキャリアを始める'),
              ),
            ),
          ],
        ),
      ),
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
