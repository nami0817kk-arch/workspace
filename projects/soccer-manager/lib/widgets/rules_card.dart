import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/economy_scale.dart';
import '../logic/league_rules.dart';
import '../state/game_state.dart';
import '../theme/semantic_colors.dart';
import 'help_button.dart';

/// このクラブのいる国の財務規則と、いまの状況。クラブ経営の画面に置く。
class RulesCard extends StatelessWidget {
  const RulesCard({super.key});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final save = gameState.save;
    if (save == null) return const SizedBox.shrink();
    final report = gameState.ruleReport;
    final ruleSet = gameState.ruleSet;

    Color levelColor(int level) => switch (level) {
          2 => SemanticColors.negative(context),
          1 => SemanticColors.ink(context, Colors.orange.shade700),
          _ => SemanticColors.positive(context),
        };

    String levelText(int level) => switch (level) {
          2 => Tr.pick('違反', 'Breach'),
          1 => Tr.pick('注意', 'Caution'),
          _ => Tr.pick('問題なし', 'OK'),
        };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 規則の説明は「?」の中へ。いまの状況(問題なし/注意/違反)を先に。
            TitleWithHelp(
              title: Tr.pick('リーグの規則: ${ruleSet.label}',
                  'League rules: ${ruleSet.label}'),
              help: ruleSet.summary,
            ),
            for (final s in report.statuses)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(child: Text('${s.label}: ${s.detail}')),
                    Text(levelText(s.level),
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: levelColor(s.level))),
                  ],
                ),
              ),
            // スペイン式: 上限までの空きと、上限を超えている間に売った分から
            // 使える額(売った人件費の一部)。
            if (ruleSet == RuleSet.spain) ...[
              const SizedBox(height: 4),
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
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (gameState.isTransferBanned) ...[
              const SizedBox(height: 8),
              Text(
                Tr.pick('補強が禁止されています(あと${save.transferBanSeasons}季)。',
                    'Signings are banned (${Tr.plural(save.transferBanSeasons, 'more season')}).'),
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: SemanticColors.negative(context)),
              ),
            ],
            if (save.wageFreezeSeasons > 0) ...[
              const SizedBox(height: 4),
              Text(
                Tr.pick(
                    '人件費の上限: 年${formatMoney(annualFromWeekly(save.wageFreezeCap))}まで(あと${save.wageFreezeSeasons}季)。',
                    'Wage cap: ${formatMoney(annualFromWeekly(save.wageFreezeCap))} a year (${Tr.plural(save.wageFreezeSeasons, 'season')} left).'),
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: SemanticColors.negative(context)),
              ),
            ],
            if (save.adminRelegation) ...[
              const SizedBox(height: 4),
              Text(
                Tr.pick('降格処分: 今季の締めで1つ下の部へ落ちます。',
                    'Administrative relegation: you go down a division at the end of this season.'),
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: SemanticColors.negative(context)),
              ),
            ],
            if (save.pendingPointsDeduction > 0 ||
                (save.league.pointsAdjustments[save.userTeamId] ?? 0) < 0) ...[
              const SizedBox(height: 4),
              Text(
                Tr.pick(
                    '勝ち点の剥奪: ${save.pendingPointsDeduction > 0 ? '来季 -${save.pendingPointsDeduction}' : '今季 ${save.league.pointsAdjustments[save.userTeamId]}'}',
                    'Points deduction: ${save.pendingPointsDeduction > 0 ? 'next season -${save.pendingPointsDeduction}' : 'this season ${save.league.pointsAdjustments[save.userTeamId]}'}'),
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: SemanticColors.negative(context)),
              ),
            ],
            if (report.penalty != null) ...[
              const SizedBox(height: 8),
              Text(
                Tr.pick('このまま今季を終えると: ${report.penalty!.reason}。',
                    'If the season ended now: ${report.penalty!.reason}.'),
                style: TextStyle(color: SemanticColors.negative(context)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
