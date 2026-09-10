import 'package:flutter/material.dart';

import '../../models/legend.dart';
import '../../state/career_controller.dart';
import '../player_banner.dart';
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
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
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

/// 額の格。
///
/// 引退した選手が並ぶ画面が、白いカードに文字が並ぶだけだった。
/// 20年かけて大陸を獲った選手が、10試合で辞めた選手と同じ見た目で残る。
///
/// 色を決めるのは**カードにすでに書いてあるもの**（獲ったタイトル）だけ。
/// 見た目のためだけの数字は作らない。
enum HallPlaque {
  gold('金', Color(0xFF8A6B1F)),
  silver('銀', Color(0xFF4C555F)),
  bronze('銅', Color(0xFF5C3F2C));

  const HallPlaque(this.label, this.color);

  final String label;
  final Color color;

  static HallPlaque of(Legend legend) {
    if (legend.continentalTitles > 0) return HallPlaque.gold;
    if (legend.leagueTitles > 0 || legend.cupTitles > 0) {
      return HallPlaque.silver;
    }
    return HallPlaque.bronze;
  }
}

class _LegendCard extends StatelessWidget {
  const _LegendCard({required this.legend, required this.onRemove});

  final Legend legend;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final plaque = HallPlaque.of(legend);
    final on = readableOn(plaque.color);
    final onMuted = on.withValues(alpha: 0.85);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 額。名前とピーク総合力を、色を敷いた帯に置く。
          KitBackground(
            primary: plaque.color,
            secondary: const Color(0xFFF2F0E6),
            striped: plaque == HallPlaque.gold,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
              child: Row(
                children: [
                  PlayerPortrait(
                    look: legend.look,
                    squadNumber: legend.squadNumber,
                    size: 60,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                legend.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: on,
                                  fontWeight: FontWeight.w700,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (legend.tampered) ...[
                              const SizedBox(width: 6),
                              Text(
                                '改変済み',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: onMuted,
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          '${legend.positionLabel} ・ '
                          '${legend.retiredYear}年に${legend.retiredAge}歳で引退',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: onMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // ピークの総合力。衰えた後の数字ではなく、一番高かったところ。
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${legend.peakOverall}',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: on,
                          fontWeight: FontWeight.w700,
                          height: 1.0,
                        ),
                      ),
                      Text(
                        'ピーク',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: onMuted,
                        ),
                      ),
                    ],
                  ),
                  // 消すボタンは小さく。額の中で一番目立つものではない。
                  IconButton(
                    tooltip: '記録を消す',
                    onPressed: onRemove,
                    color: onMuted,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.delete_outline, size: 20),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 通算。額の中に入れると3行に折れるので、こちら側に置く。
                Text(legend.summary, style: muted),
                if (legend.caps > 0)
                  Text(
                    '代表 ${legend.caps}キャップ ${legend.internationalGoals}ゴール',
                    style: muted,
                  ),
                Text('引退後: ${legend.secondCareer.label}', style: muted),
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
                      title: Text('特性と称号', style: theme.textTheme.bodySmall),
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
        ],
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
      avatar: Icon(
        Icons.emoji_events,
        size: 16,
        color: theme.colorScheme.onPrimaryContainer,
      ),
      label: Text(label),
      backgroundColor: theme.colorScheme.primaryContainer,
      visualDensity: VisualDensity.compact,
    );
  }
}
