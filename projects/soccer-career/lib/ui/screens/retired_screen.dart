import 'package:flutter/material.dart';

import '../../l10n/lang.dart';
import '../player_portrait.dart';
import '../readable_width.dart';
import '../share_card.dart';
import '../share_sheet.dart';
import 'hall_screen.dart';
import '../../game/formulas.dart';
import '../../models/legend.dart';
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
        title: Text(tr('新しいキャリアを始めますか', 'Start a new career?')),
        // 消えなくなった。ここは前の文言のままにしておくと嘘になる。
        content: Text(tr('この選手は「これまでの選手」に残ります。', 'This player stays under Players so far.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(tr('やめる', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(tr('始める', 'Start')),
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
    // 殿堂に写したものと同じ記録。送る1枚はここから作る。
    final legend = Legend.from(
      state,
      secondCareer: state.secondCareer ?? SecondCareer.quiet,
    );
    final best = seasons.isEmpty
        ? null
        : seasons.reduce(
            (a, b) => a.leaguePosition <= b.leaguePosition && a.tier <= b.tier
                ? a
                : b,
          );

    return Scaffold(
      appBar: AppBar(title: Text(tr('引退', 'Retired'))),
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
                tr('${state.player.positionLabel}  ${seasons.length}シーズン  '
                '${state.player.age}歳で引退', '${state.player.positionLabel}  ${seasons.length} seasons  retired at ${state.player.age}'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('通算', 'Career totals'), style: theme.textTheme.titleSmall),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _stat(theme, tr('出場', 'Games'), '${totals.appearances}'),
                          _stat(theme, tr('ゴール', 'Goals'), '${totals.goals}'),
                          _stat(theme, tr('アシスト', 'Assists'), '${totals.assists}'),
                          _stat(
                            theme,
                            tr('平均評価', 'Avg rating'),
                            totals.appearances == 0
                                ? '—'
                                : totals.averageRating.toStringAsFixed(2),
                          ),
                        ],
                      ),
                      if (state.caps > 0) ...[
                        const SizedBox(height: 12),
                        Text(
                          tr('代表 ${state.caps}キャップ  ${state.internationalGoals}ゴール', 'National team ${state.caps} caps  ${state.internationalGoals} goals'),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        tr('生涯の貯蓄 ${state.finances.savingsLabel}', 'Savings at the end ${state.finances.savingsLabel}'),
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tr('通算年俸 ${state.totalEarnings >= 10000 ? '${(state.totalEarnings / 10000).toStringAsFixed(1)}億円' : '${state.totalEarnings}万円'}', 'Career earnings ${state.totalEarnings >= 10000 ? 'JPY ${(state.totalEarnings / 100).round()}M' : 'JPY ${(state.totalEarnings / 100).toStringAsFixed(1)}M'}'),
                        style: theme.textTheme.bodyMedium,
                      ),
                      if (best != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          tr('最高成績: ${best.year}  ${best.clubName}  '
                          '${best.tier}部 ${best.leaguePosition}位', 'Best season: ${best.year}  ${best.clubName}  tier ${best.tier} #${best.leaguePosition}'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (state.reputation.awards.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(tr('称号', 'Honours'), style: theme.textTheme.titleSmall),
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
              // **次の選手に残るもの。** 引退が終わりではないと分かる場所。
              const SizedBox(height: 24),
              Text(tr('次の選手に残すもの', 'What you leave the next player'), style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                tr('${controller.lastLegacyPoints}pt を残した'
                '（通算 ${controller.hall.legacyPoints}pt）。'
                '${Formulas.legacyPerPotential}ptごとに、次の選手の伸びしろが'
                '+1される（今は+${controller.hall.potentialBonus}、'
                '上限+${Formulas.legacyPotentialCap}）。', '${controller.lastLegacyPoints}pt left behind (${controller.hall.legacyPoints}pt in all). Every ${Formulas.legacyPerPotential}pt adds +1 to the next player ceiling (now +${controller.hall.potentialBonus}, up to +${Formulas.legacyPotentialCap}).'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (controller.lastDeclared case final declared?) ...[
                const SizedBox(height: 4),
                Text(
                  declared.clearedBy(controller.hall.legends.first)
                      ? tr('宣言していた「${declared.label}」を達成した'
                            '（+${declared.declaredBonus}pt）。', 'You called ${declared.label}, and did it (+${declared.declaredBonus}pt).')
                      : tr('宣言していた「${declared.label}」には届かなかった。', 'You called ${declared.label}, and fell short.'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (controller.lastChallenges.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(tr('初めて達成した挑戦', 'Challenges cleared for the first time'), style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                for (final c in controller.lastChallenges)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text('${c.label}——${c.requirement}')),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 24),
              Text(tr('この後どう生きるか', 'What comes next'), style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                tr('やってきたことが、そのまま次の適性になる。'
                '見立ては「${controller.suggestedSecondCareer.label}」。', 'What you did as a player is what you are suited to now. The reading: ${controller.suggestedSecondCareer.label}.'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              // 選べない道は、なぜ選べないのかまで書く。
              for (final path in SecondCareer.values)
                if (controller.secondCareerBlocked(path) case final why?)
                  Text(
                    '${path.label}——$why',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final path in SecondCareer.values)
                    Tooltip(
                      message:
                          controller.secondCareerBlocked(path) ??
                          path.description,
                      child: ChoiceChip(
                        label: Text(path.label),
                        selected: state.secondCareer == path,
                        // **進める道だけ。** 20年のキャリアが結末に効かないなら、
                        // 「やってきたことが次の適性になる」は文字だけになる。
                        onSelected: controller.secondCareerBlocked(path) != null
                            ? null
                            : (_) async {
                                await controller.chooseSecondCareer(path);
                                if (mounted) setState(() {});
                              },
                      ),
                    ),
                ],
              ),
              if (state.charity) ...[
                const SizedBox(height: 10),
                Text(
                  tr('自分の名前の付いたグラウンドが、育った街に残っている。', 'A pitch in your home town carries your name.'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Text(tr('歩み', 'The road'), style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              for (final record in seasons)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('${record.year}  ${record.clubName}'),
                  subtitle: Text(
                    tr('${record.tier}部 ${record.leaguePosition}位 ・ '
                    '${record.stats.appearances}試合 '
                    '${record.stats.goals}G ${record.stats.assists}A', 'Tier ${record.tier} #${record.leaguePosition} - ${record.stats.appearances} games ${record.stats.goals}G ${record.stats.assists}A'),
                  ),
                  trailing: Text(
                    record.stats.appearances == 0
                        ? '—'
                        : record.stats.averageRating.toStringAsFixed(2),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              const SizedBox(height: 32),
              // **20年を語りたい瞬間はここ。** 殿堂に写したものと同じ
              // 記録から1枚を作って送れるようにする。
              //
              // **送るのは自分で歩いたキャリアだけ。** 管理画面で書き換えた
              // 記録（`tampered`）は外に出さない——作った数字が本物として
              // 広まるのは、記録として正しくない。印を殿堂に持ち込むのと同じ理屈。
              if (!legend.tampered) ...[
                OutlinedButton.icon(
                  onPressed: () {
                    final card = CareerShareCard(legend: legend);
                    showShareSheet(context, card: card, text: card.text);
                  },
                  icon: const Icon(Icons.ios_share, size: 18),
                  label: Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Text(tr('このキャリアを送る', 'Share this career')),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              // 引退した時点で殿堂に入っている。ここから見に行ける。
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => HallScreen(controller: controller),
                  ),
                ),
                icon: const Icon(Icons.workspace_premium_outlined, size: 18),
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(tr('これまでの選手（${controller.hall.legends.length}人）', 'Players so far (${controller.hall.legends.length})')),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => _newCareer(context),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(tr('新しいキャリアを始める', 'Start a new career')),
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
      Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      Text(value, style: theme.textTheme.titleLarge),
    ],
  );
}
