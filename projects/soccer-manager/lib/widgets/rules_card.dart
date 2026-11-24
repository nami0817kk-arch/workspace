import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/advisor_engine.dart';
import '../logic/economy_scale.dart';
import '../logic/league_rules.dart';
import '../state/game_state.dart';
import '../theme/semantic_colors.dart';
import 'help_button.dart';

/// このクラブのいる国の財務規則と、いまの状況。クラブ経営の画面に置く。
///
/// 2026-11-25 の第7段で、利用者の「収支規則を分かりやすく」に合わせて
/// 作り直した。項目ごとに 今・上限・あといくら・状態 を表で並べ、その下に
/// いつ判定されるか・違反するとどうなるか(国ごとの罰)を書く。
class RulesCard extends StatelessWidget {
  const RulesCard({super.key});

  static Color levelColor(BuildContext context, int level) => switch (level) {
        2 => SemanticColors.negative(context),
        1 => SemanticColors.ink(context, Colors.orange.shade700),
        _ => SemanticColors.positive(context),
      };

  static String levelText(int level) => switch (level) {
        2 => Tr.pick('違反', 'Breach'),
        1 => Tr.pick('注意', 'Caution'),
        _ => Tr.pick('問題なし', 'OK'),
      };

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final save = gameState.save;
    if (save == null) return const SizedBox.shrink();
    final report = gameState.ruleReport;
    final ruleSet = gameState.ruleSet;
    final theme = Theme.of(context);
    final subtle = SemanticColors.subtleText(context);
    final worst = report.statuses.fold<int>(0, (m, s) => s.level > m ? s.level : m);
    final inGrace = save.league.season <= RulesEngine.graceSeasons;
    final legal = save.advisors[Advisor.legal.name] ?? 0;

    Widget fact(IconData icon, String head, String body, {Key? key}) =>
        Padding(
          key: key,
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(icon, size: 16, color: subtle),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text: '$head  ',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    TextSpan(text: body),
                  ]),
                  style: const TextStyle(fontSize: 12.5),
                ),
              ),
            ],
          ),
        );

    return Card(
      key: const ValueKey('rules-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TitleWithHelp(
                    title: Tr.pick('財務規則', 'Financial rules'),
                    help: ruleSet.summary,
                  ),
                ),
                _LevelBadge(level: worst),
              ],
            ),
            Text(ruleSet.label,
                style: theme.textTheme.bodySmall?.copyWith(color: subtle)),
            const SizedBox(height: 8),
            for (final s in report.statuses) _StatusRow(status: s),
            // スペイン式: 上限までの空きと、上限を超えている間に売った分から
            // 使える額(売った人件費の一部)。
            if (ruleSet == RuleSet.spain) ...[
              const SizedBox(height: 6),
              Text(
                Tr.pick(
                    '新加入に使える人件費: いま年${formatMoney(gameState.squadCostSpendable)}${gameState.squadCostSaleAllowance > 0 ? '(うち売った分から年${formatMoney(gameState.squadCostSaleAllowance)})' : ''}',
                    'Room for new signings: ${formatMoney(gameState.squadCostSpendable)} a year now${gameState.squadCostSaleAllowance > 0 ? ' (${formatMoney(gameState.squadCostSaleAllowance)} of it from sales)' : ''}'),
                key: const Key('rules-spendable'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                Tr.pick(
                    '上限を超えている間は、売って空いた人件費の${(RulesEngine.saleSpendShare * 100).round()}%だけ新加入に使えます。',
                    'While over the limit, only ${(RulesEngine.saleSpendShare * 100).round()}% of the costs you shed can go on new signings.'),
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 4),
            fact(Icons.event_outlined, Tr.pick('判定', 'Checked'),
                ruleSet.checkTiming,
                key: const ValueKey('rules-timing')),
            fact(Icons.gavel_outlined, Tr.pick('違反すると', 'If you breach'),
                ruleSet.consequence,
                key: const ValueKey('rules-consequence')),
            if (gameState.userInContinental)
              fact(Icons.public, Tr.pick('大陸大会', 'Continental'),
                  RulesEngine.uefaConsequence),
            if (inGrace)
              fact(
                  Icons.hourglass_top,
                  Tr.pick('猶予', 'Grace'),
                  Tr.pick('最初の季は、違反しても知らせだけで罰はありません。',
                      'In your first season a breach brings a warning only.')),
            if (legal > 0)
              fact(
                  Icons.balance,
                  Tr.pick('法務顧問', 'Legal advisor'),
                  Tr.pick(
                      '罰金が${((1 - AdvisorEngine.fineMultiplier(legal)) * 100).round()}%軽くなります。',
                      'Fines are ${((1 - AdvisorEngine.fineMultiplier(legal)) * 100).round()}% lighter.')),
            // いま受けている罰。
            if (gameState.isTransferBanned)
              _Alert(Tr.pick('補強が禁止されています(あと${save.transferBanSeasons}季)。',
                  'Signings are banned (${Tr.plural(save.transferBanSeasons, 'more season')}).')),
            if (save.wageFreezeSeasons > 0)
              _Alert(Tr.pick(
                  '人件費の上限: 年${formatMoney(annualFromWeekly(save.wageFreezeCap))}まで(あと${save.wageFreezeSeasons}季)。',
                  'Wage cap: ${formatMoney(annualFromWeekly(save.wageFreezeCap))} a year (${Tr.plural(save.wageFreezeSeasons, 'season')} left).')),
            if (save.adminRelegation)
              _Alert(Tr.pick('降格処分: 今季の締めで1つ下の部へ落ちます。',
                  'Administrative relegation: you go down a division at the end of this season.')),
            if (save.pendingPointsDeduction > 0 ||
                (save.league.pointsAdjustments[save.userTeamId] ?? 0) < 0)
              _Alert(Tr.pick(
                  '勝ち点の剥奪: ${save.pendingPointsDeduction > 0 ? '来季 -${save.pendingPointsDeduction}' : '今季 ${save.league.pointsAdjustments[save.userTeamId]}'}',
                  'Points deduction: ${save.pendingPointsDeduction > 0 ? 'next season -${save.pendingPointsDeduction}' : 'this season ${save.league.pointsAdjustments[save.userTeamId]}'}')),
            if (report.penalty != null)
              _Alert(
                inGrace
                    ? Tr.pick('このまま今季を終えると違反です(${report.penalty!.reason})。',
                        'If the season ended now you would be in breach (${report.penalty!.reason}).')
                    : Tr.pick('このまま今季を終えると: ${report.penalty!.reason}。',
                        'If the season ended now: ${report.penalty!.reason}.'),
                key: const ValueKey('rules-penalty-preview'),
              ),
          ],
        ),
      ),
    );
  }
}

/// 状態の小さな札(問題なし・注意・違反)。
class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level});
  final int level;

  @override
  Widget build(BuildContext context) {
    final color = RulesCard.levelColor(context, level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(RulesCard.levelText(level),
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.bold, color: color)),
    );
  }
}

/// 項目1つ: 名前と状態、その下に 今 / 上限 / あといくら。
class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.status});
  final RuleStatus status;

  @override
  Widget build(BuildContext context) {
    final s = status;
    final subtle = SemanticColors.subtleText(context);
    final color = RulesCard.levelColor(context, s.level);
    Widget cell(String head, String value, {bool bold = false}) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(head, style: TextStyle(fontSize: 11, color: subtle)),
              Text(value,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: bold ? FontWeight.bold : FontWeight.w500)),
            ],
          ),
        );
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: color, width: 3)),
        color: Theme.of(context).colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(s.label,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              Text(RulesCard.levelText(s.level),
                  style: TextStyle(fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 2),
          if (s.now == null)
            Text(s.detail)
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                cell(Tr.pick('今', 'Now'), s.now!, bold: true),
                cell(Tr.pick('上限・基準', 'Limit'), s.limit ?? ''),
              ],
            ),
          if (s.gap != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(s.gap!,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight:
                          s.level >= 2 ? FontWeight.bold : FontWeight.normal,
                      color: s.level >= 2 ? color : subtle)),
            ),
        ],
      ),
    );
  }
}

/// いま受けている罰・このままだと受ける罰の1行(赤)。
class _Alert extends StatelessWidget {
  const _Alert(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(text,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: SemanticColors.negative(context))),
      );
}
