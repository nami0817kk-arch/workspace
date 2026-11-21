import 'package:flutter/material.dart';

import '../../l10n/lang.dart';
import '../../models/challenge.dart';
import '../../models/club.dart';
import '../../models/legend.dart';
import '../../state/career_controller.dart';
import '../hall_plaque.dart';
import '../player_banner.dart';
import '../player_portrait.dart';
import '../readable_width.dart';
import '../share_card.dart';
import '../share_sheet.dart';
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
        title: Text(tr('${legend.name}の記録を消しますか', 'Delete the record of ${legend.name}?')),
        content: Text(tr('戻せません。', 'This cannot be undone.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(tr('やめる', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(tr('消す', 'Delete')),
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
      appBar: AppBar(title: Text(tr('これまでの選手', 'Players so far'))),
      body: SafeArea(
        child: ReadableWidth(
          child: legends.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      tr('引退した選手はまだ居ない。\n'
                      'キャリアを終えると、ここに1人ずつ残る。', 'No one has retired yet.\nEvery career you finish leaves a player here.'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: legends.length + 2,
                  itemBuilder: (context, i) {
                    // 一番上に歴代の記録。次の選手が追う的が無いと、
                    // 殿堂は過去を眺めるだけの場所になる。
                    if (i == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _RecordsCard(hall: widget.controller.hall),
                      );
                    }
                    // 記録は「多いほど良い」ものしかない。**違う形のキャリアを
                    // 試す理由**は、その下の挑戦のほうに置く。
                    if (i == 1) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ChallengesCard(hall: widget.controller.hall),
                      );
                    }
                    final legend = legends[i - 2];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _LegendCard(
                        legend: legend,
                        // 1人しか居ないうちは「歴代1位」に意味が無い。
                        records: legends.length >= 2
                            ? widget.controller.hall.recordsHeldBy(legend)
                            : const [],
                        onRemove: () => _remove(i - 2, legend),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

/// 挑戦の一覧。**達成したものと、まだのもの。**
///
/// 通算ゴールや通算出場は同じ遊び方を続けるほど伸びるので、
/// 2人目を作る理由にならない。ここに並ぶのは
/// **形の違うキャリアでしか届かないもの**だけ。
class _ChallengesCard extends StatelessWidget {
  const _ChallengesCard({required this.hall});

  final Hall hall;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final done = Challenge.values.where(hall.isCleared).length;
    // **畳んでおく。** 9件を開いたままにすると、殿堂に並ぶ選手が
    // 画面の外へ押し出される（実際にテストが選手を見つけられなくなった）。
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: const PageStorageKey('hall-challenges'),
          title: Text(tr('挑戦', 'Challenges'), style: theme.textTheme.titleSmall),
          subtitle: Text(
            tr('$done / ${Challenge.values.length} 達成 ・'
            ' どれも違う形のキャリアでしか届かない', '$done / ${Challenge.values.length} done · each one needs a differently shaped career'),
            style: muted,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final c in Challenge.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      hall.isCleared(c)
                          ? Icons.check_circle
                          : Icons.circle_outlined,
                      size: 18,
                      color: hall.isCleared(c)
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outlineVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.label,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: hall.isCleared(c)
                                  ? theme.colorScheme.onSurface
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(c.requirement, style: muted),
                          if (c.note.isNotEmpty) Text(c.note, style: muted),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 歴代の記録。次のキャリアが追う的。
class _RecordsCard extends StatelessWidget {
  const _RecordsCard({required this.hall});

  final Hall hall;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final records = hall.records;
    if (records.isEmpty) return const SizedBox.shrink();
    // **窪んだ受け皿にする。** 一段暗いだけの板だと、白いカードの列に
    // 「あとから貼った灰色の紙」として浮く（切り札の受け皿で先に踏んだのと
    // 同じ形）。記録は盤にはめ込んであるほうが、追う的らしい。
    final tray = theme.colorScheme.surfaceContainerHighest;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.alphaBlend(const Color(0x3D000000), tray),
            tray,
            Color.alphaBlend(
              theme.colorScheme.surface.withValues(alpha: 0.45),
              tray,
            ),
          ],
          stops: const [0.0, 0.35, 1.0],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('歴代の記録', 'All-time records'), style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final r in records)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 96,
                      child: Text(
                        r.label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Text(
                      '${r.value}${r.unit}',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        r.holder,
                        style: theme.textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LegendCard extends StatelessWidget {
  const _LegendCard({
    required this.legend,
    required this.records,
    required this.onRemove,
  });

  final Legend legend;

  /// この選手が持っている歴代の記録。
  final List<HallRecord> records;

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
                  // **額の中の似顔は、テーマではなくクラブの色を着る。**
                  // クラブを渡していなかったので、引退した選手は
                  // `theme.colorScheme.primary` を着ていた——明るいテーマと
                  // 暗いテーマで、同じ選手が別の色になっていた。
                  // IDを控えていない古い記録は、今までどおり。
                  PlayerPortrait(
                    look: legend.look,
                    club: legend.clubId.isEmpty
                        ? null
                        : Club(
                            id: legend.clubId,
                            name: legend.spells.isEmpty
                                ? ''
                                : legend.spells.last.clubName,
                            strength: 0,
                            tier: 1,
                          ),
                    squadNumber: legend.squadNumber,
                    size: 60,
                    // 背は帯の上に乗るので、テーマではなく帯から決める。
                    backdrop: const Color(0xFFF2F0E6),
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
                                tr('改変済み', 'Edited'),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: onMuted,
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          tr('${legend.positionLabel} ・ '
                          '${legend.retiredYear}年に${legend.retiredAge}歳で引退', '${legend.positionLabel} · retired in ${legend.retiredYear}, aged ${legend.retiredAge}'),
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
                        tr('ピーク', 'Peak'),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: onMuted,
                        ),
                      ),
                    ],
                  ),
                  // **後から振り返っても送れるようにする。**
                  // 引退の画面は一度閉じたら戻れないので、そこだけに
                  // 置くと「あのとき送りそこねた」が残る。
                  // 書き換えた記録（`tampered`）は外に出さない。
                  if (!legend.tampered)
                    IconButton(
                      tooltip: tr('この記録を送る', 'Share this record'),
                      onPressed: () {
                        final card = CareerShareCard(legend: legend);
                        showShareSheet(context, card: card, text: card.text);
                      },
                      color: onMuted,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.ios_share, size: 18),
                    ),
                  // 消すボタンは小さく。額の中で一番目立つものではない。
                  IconButton(
                    tooltip: tr('記録を消す', 'Delete record'),
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
                    tr('代表 ${legend.caps}キャップ ${legend.internationalGoals}ゴール', 'National team ${legend.caps} caps, ${legend.internationalGoals} goals'),
                    style: muted,
                  ),
                Text(tr('引退後: ${legend.secondCareer.label}', 'After football: ${legend.secondCareer.label}'), style: muted),
                if (records.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final r in records)
                        Chip(
                          label: Text(tr('歴代1位 ${r.label}', 'All-time best · ${r.label}')),
                          backgroundColor: theme.colorScheme.tertiaryContainer,
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ],
                if (legend.titles > 0 || legend.worldCupBest.participated) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (legend.leagueTitles > 0)
                        _Trophy(label: tr('リーグ優勝 ${legend.leagueTitles}', 'League titles ${legend.leagueTitles}')),
                      if (legend.cupTitles > 0)
                        _Trophy(label: tr('国内カップ ${legend.cupTitles}', 'Domestic cups ${legend.cupTitles}')),
                      if (legend.continentalTitles > 0)
                        _Trophy(label: tr('大陸カップ ${legend.continentalTitles}', 'Continental cups ${legend.continentalTitles}')),
                      if (legend.worldCupBest.participated)
                        _Trophy(label: tr('世界大会 ${legend.worldCupBest.label}', 'World tournament ${legend.worldCupBest.label}')),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                // 歩いた順。同じクラブに戻ってきたら別の区切りになる。
                Text(tr('歩み', 'The road'), style: theme.textTheme.labelMedium),
                const SizedBox(height: 4),
                for (final spell in legend.spells)
                  Text(
                    tr('${spell.clubName}（${spell.tier}部）  ${spell.seasons}季', '${spell.clubName} (tier ${spell.tier})  ${spell.seasons} seasons'),
                    style: muted,
                  ),
                if (legend.traits.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Theme(
                    data: theme.copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: const EdgeInsets.only(bottom: 8),
                      title: Text(tr('特性と称号', 'Traits and honours'), style: theme.textTheme.bodySmall),
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
