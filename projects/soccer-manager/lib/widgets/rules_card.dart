import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/economy_scale.dart';
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
          1 => Colors.orange.shade700,
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
            if (gameState.isTransferBanned) ...[
              const SizedBox(height: 8),
              Text(
                Tr.pick('補強が禁止されています(あと${save.transferBanSeasons}季)。',
                    'Signings are banned (${save.transferBanSeasons} more seasons).'),
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
