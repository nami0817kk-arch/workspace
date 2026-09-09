import 'package:flutter/material.dart';

import '../player_portrait.dart';
import '../readable_width.dart';
import '../../models/life.dart';
import '../../state/career_controller.dart';

/// 引退後の画面。通算成績と歩みを見せる。ここから新しいキャリアを始められる。
class RetiredScreen extends StatefulWidget {
  const RetiredScreen({super.key, required this.controller});

  final CareerController controller;

  @override
  State<RetiredScreen> createState() => _RetiredScreenState();
}

class _RetiredScreenState extends State<RetiredScreen> {

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
    if (ok == true) await widget.controller.deleteCareer();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = widget.controller;
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
        child: ReadableWidth(
          child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              state.nickname == null
                  ? state.player.name
                  : '${state.player.name}「${state.nickname}」',
              style: theme.textTheme.headlineSmall,
            ),
            Center(
              child: PlayerPortrait(
                look: state.player.look,
                club: state.club,
                squadNumber: state.squadNumber,
                size: 96,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${state.player.positionLabel}  ${seasons.length}シーズン  '
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
                    if (state.caps > 0) ...[
                      const SizedBox(height: 12),
                      Text(
                        '代表 ${state.caps}キャップ  ${state.internationalGoals}ゴール',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      '生涯の貯蓄 ${state.finances.savingsLabel}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '通算年俸 ${state.totalEarnings >= 10000 ? '${(state.totalEarnings / 10000).toStringAsFixed(1)}億円' : '${state.totalEarnings}万円'}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (best != null) ...[
                      const SizedBox(height: 8),
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
            if (state.reputation.awards.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('称号', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final a in state.reputation.awards)
                    Chip(label: Text(a.label)),
                ],
              ),
            ],
            const SizedBox(height: 24),
            Text('この後どう生きるか', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              'やってきたことが、そのまま次の適性になる。'
              '見立ては「${controller.suggestedSecondCareer.label}」。',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final path in SecondCareer.values)
                  Tooltip(
                    message: path.description,
                    child: ChoiceChip(
                      label: Text(path.label),
                      selected: state.secondCareer == path,
                      onSelected: (_) async {
                        await controller.chooseSecondCareer(path);
                        if (mounted) setState(() {});
                      },
                    ),
                  ),
              ],
            ),
            if (state.charity) ...[
              const SizedBox(height: 10),
              Text('自分の名前の付いたグラウンドが、育った街に残っている。',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.primary)),
            ],
            const SizedBox(height: 24),
            Text('歩み', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final record in seasons)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('${record.year}  ${record.clubName}'),
                subtitle: Text(
                  '${record.tier}部 ${record.leaguePosition}位 ・ '
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
