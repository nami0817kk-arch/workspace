import 'package:flutter/material.dart';

import '../models/career.dart';

/// 今季の収支の見込み。雇う前に足りるかどうかが分かるようにする。
///
/// 年俸だけを見て世界的なコーチを雇い、シーズンの終わりに貯蓄が尽きて
/// 黙って全員が離れていく、という壊れ方をしていた。
class BudgetLines extends StatelessWidget {
  const BudgetLines({super.key, required this.state});

  final CareerState state;

  static String _yen(int man) => man >= 10000
      ? '${(man / 10000).toStringAsFixed(1)}億'
      : '$man万';

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
        Text('貯蓄 ${state.finances.savingsLabel}',
            style: theme.textTheme.bodyMedium),
        const SizedBox(height: 2),
        Text(
          '今季の見込み  年俸 ${_yen(budget.salary)}'
          '${budget.sponsor > 0 ? '＋スポンサー ${_yen(budget.sponsor)}' : ''}'
          ' − 手数料 ${_yen(budget.agentFee)}'
          ' − 税 ${_yen(budget.tax)}'
          ' − 生活 ${_yen(budget.living)}'
          '${budget.staff > 0 ? ' − 専属 ${_yen(budget.staff)}' : ''}',
          style: muted,
        ),
        const SizedBox(height: 2),
        Text(
          '手取り ${budget.net >= 0 ? '＋' : '−'}${_yen(budget.net.abs())}円'
          '  →  シーズン末の貯蓄 '
          '${state.projectedSavings >= 0 ? '' : '−'}'
          '${_yen(state.projectedSavings.abs())}円',
          style: theme.textTheme.bodySmall?.copyWith(
            color: short ? theme.colorScheme.error : theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (short) ...[
          const SizedBox(height: 4),
          Text(
            'このままだと今季末に貯蓄が尽き、専属スタッフは全員離れる。'
            '雇う人数を減らすか、生活水準を下げること。',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.error),
          ),
        ],
      ],
    );
  }
}
