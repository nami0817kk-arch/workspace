import 'package:flutter/material.dart';

import '../game/formulas.dart';
import '../l10n/lang.dart';
import '../models/career.dart';

/// 今季の収支の見込み。雇う前に足りるかどうかが分かるようにする。
///
/// 年俸だけを見て世界的なコーチを雇い、シーズンの終わりに貯蓄が尽きて
/// 黙って全員が離れていく、という壊れ方をしていた。
class BudgetLines extends StatelessWidget {
  const BudgetLines({super.key, required this.state});

  final CareerState state;

  static String _yen(int man) => man >= 10000
      ? tr('${(man / 10000).toStringAsFixed(1)}億', 'JPY ${(man / 100).round()}M')
      : tr('$man万', 'JPY ${(man / 100).toStringAsFixed(1)}M');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final budget = state.budget;
    final short = state.willRunOut;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr('貯蓄 ${state.finances.savingsLabel}', 'Savings ${state.finances.savingsLabel}'),
            style: theme.textTheme.bodyMedium),
        const SizedBox(height: 2),
        Text(
          tr('今季の見込み  年俸 ${_yen(budget.salary)}'
          '${budget.sponsor > 0 ? '＋スポンサー ${_yen(budget.sponsor)}' : ''}'
          ' − 手数料 ${_yen(budget.agentFee)}'
          ' − 税 ${_yen(budget.tax)}'
          ' − 生活 ${_yen(budget.living)}'
          '${budget.staff > 0 ? ' − 専属 ${_yen(budget.staff)}' : ''}', 'This season  wage ${_yen(budget.salary)}${budget.sponsor > 0 ? ' + sponsor ${_yen(budget.sponsor)}' : ''} − agent ${_yen(budget.agentFee)} − tax ${_yen(budget.tax)} − living ${_yen(budget.living)}${budget.staff > 0 ? ' − staff ${_yen(budget.staff)}' : ''}'),
          style: muted,
        ),
        // **出場給。** 基準の試合数でちょうど 0 になるので、
        // 普通に出ていれば何も出ない。欠けた年だけ赤く出る。
        if (budget.appearanceBonus != 0)
          Text(
            tr('出場給 ${budget.appearanceBonus > 0 ? '＋' : '−'}'
            '${_yen(budget.appearanceBonus.abs())}円'
            '（${state.seasonStats.appearances}試合 / 基準'
            '${Formulas.appearanceBaseline}）', 'Appearance pay ${budget.appearanceBonus > 0 ? '+' : '−'}${_yen(budget.appearanceBonus.abs())} (${plural(state.seasonStats.appearances, 'game')} / baseline ${Formulas.appearanceBaseline})'),
            style: muted?.copyWith(
              color: budget.appearanceBonus > 0
                  ? theme.colorScheme.primary
                  : theme.colorScheme.error,
            ),
          ),
        const SizedBox(height: 2),
        Text(
          tr('手取り ${budget.net >= 0 ? '＋' : '−'}${_yen(budget.net.abs())}円'
          '  →  シーズン末の貯蓄 '
          '${state.projectedSavings >= 0 ? '' : '−'}'
          '${_yen(state.projectedSavings.abs())}円', 'Net ${budget.net >= 0 ? '+' : '−'}${_yen(budget.net.abs())}  →  savings at season end ${state.projectedSavings >= 0 ? '' : '−'}${_yen(state.projectedSavings.abs())}'),
          style: theme.textTheme.bodySmall?.copyWith(
            color: short ? theme.colorScheme.error : theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (short) ...[
          const SizedBox(height: 4),
          Text(
            tr('このままだと今季末に貯蓄が尽き、専属スタッフは全員離れる。'
            '雇う人数を減らすか、生活水準を下げること。', 'At this rate your savings run out by the end of the season and every staff member leaves. Hire fewer of them, or live more cheaply.'),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.error),
          ),
        ],
      ],
    );
  }
}
