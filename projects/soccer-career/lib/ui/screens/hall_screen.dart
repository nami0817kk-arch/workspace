import 'package:flutter/material.dart';

import '../../models/legend.dart';
import '../../state/career_controller.dart';
import '../player_portrait.dart';
import '../readable_width.dart';
import '../trait_row.dart';

/// 引退した選手たち。
///
/// これまで**引退した選手は消えていた**。新しいキャリアを始めた瞬間に、
/// 20年ぶんの選択の結果が捨てられていた。ここに残る。
class HallScreen extends StatefulWidget {
  const HallScreen({super.key, required this.controller});

  final CareerController controller;

  @override
  State<HallScreen> createState() => _HallScreenState();
}

class _HallScreenState extends State<HallScreen> {
  Future<void> _remove(int index, Legend legend) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${legend.name}の記録を消しますか'),
        content: const Text('戻せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('やめる'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('消す'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await widget.controller.removeLegend(index);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final legends = widget.controller.hall.legends;
    return Scaffold(
      appBar: AppBar(title: const Text('これまでの選手')),
      body: SafeArea(
        child: ReadableWidth(
          child: legends.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      '引退した選手はまだ居ない。\n'
                      'キャリアを終えると、ここに1人ずつ残る。',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: legends.length,
                  itemBuilder: (context, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _LegendCard(
                      legend: legends[i],
                      onRemove: () => _remove(i, legends[i]),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _LegendCard extends StatelessWidget {
  const _LegendCard({required this.legend, required this.onRemove});

  final Legend legend;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 所属クラブはもう無いので、落ち着いた色で描く。
                PlayerPortrait(
                  look: legend.look,
                  squadNumber: legend.squadNumber,
                  size: 64,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(legend.name,
                                style: theme.textTheme.titleMedium,
                                overflow: TextOverflow.ellipsis),
                          ),
                          if (legend.tampered) ...[
                            const SizedBox(width: 6),
                            Text('改変済み',
                                style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.error)),
                          ],
                        ],
                      ),
                      Text(
                        '${legend.positionLabel} ・ '
                        '${legend.retiredYear}年に${legend.retiredAge}歳で引退',
                        style: muted,
                      ),
                      Text(legend.summary, style: muted),
                      Text(
                        'ピーク総合力 ${legend.peakOverall}'
                        '${legend.caps > 0 ? ' ・ 代表 ${legend.caps}キャップ ${legend.internationalGoals}ゴール' : ''}',
                        style: muted,
                      ),
                      Text('引退後: ${legend.secondCareer.label}', style: muted),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '記録を消す',
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline, size: 20),
                ),
              ],
            ),
            if (legend.titles > 0 || legend.worldCupBest.participated) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (legend.leagueTitles > 0)
                    _Trophy(label: 'リーグ優勝 ${legend.leagueTitles}'),
                  if (legend.cupTitles > 0)
                    _Trophy(label: '国内カップ ${legend.cupTitles}'),
                  if (legend.continentalTitles > 0)
                    _Trophy(label: '大陸カップ ${legend.continentalTitles}'),
                  if (legend.worldCupBest.participated)
                    _Trophy(label: '世界大会 ${legend.worldCupBest.label}'),
                ],
              ),
            ],
            const SizedBox(height: 10),
            // 歩いた順。同じクラブに戻ってきたら別の区切りになる。
            Text('歩み', style: theme.textTheme.labelMedium),
            const SizedBox(height: 4),
            for (final spell in legend.spells)
              Text(
                '${spell.clubName}（${spell.tier}部）  ${spell.seasons}季',
                style: muted,
              ),
            if (legend.traits.isNotEmpty) ...[
              const SizedBox(height: 10),
              Theme(
                data: theme.copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  title:
                      Text('特性と称号', style: theme.textTheme.bodySmall),
                  children: [
                    for (final trait in legend.traits) ...[
                      TraitRow(trait: trait),
                      const SizedBox(height: 8),
                    ],
                    if (legend.awards.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final award in legend.awards)
                            Chip(
                              label: Text(award.label),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Trophy extends StatelessWidget {
  const _Trophy({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Chip(
      avatar: Icon(Icons.emoji_events,
          size: 16, color: theme.colorScheme.onPrimaryContainer),
      label: Text(label),
      backgroundColor: theme.colorScheme.primaryContainer,
      visualDensity: VisualDensity.compact,
    );
  }
}
