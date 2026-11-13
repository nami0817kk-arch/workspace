import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/budget_engine.dart';
import '../models/budget_plan.dart';
import '../state/game_state.dart';

/// オーナーが年の予算を5つの配り先へ配るカード。
///
/// 1つを動かすと残りが比率に応じて分け直され、合計は100%のまま。
/// 指を離したときに保存する(動かしている間は画面の中だけで更新する)。
class BudgetPlanCard extends StatefulWidget {
  const BudgetPlanCard({super.key});

  @override
  State<BudgetPlanCard> createState() => _BudgetPlanCardState();
}

class _BudgetPlanCardState extends State<BudgetPlanCard> {
  BudgetPlan? _draft;

  String _effect(BudgetCategory c, BudgetPlan plan) {
    String pct(double m) {
      final d = ((m - 1) * 100).round();
      return d >= 0 ? '+$d%' : '$d%';
    }

    switch (c) {
      case BudgetCategory.signing:
        return Tr.pick('週給の上限 ${pct(BudgetEngine.wageCapMultiplier(plan))}',
            'Wage cap ${pct(BudgetEngine.wageCapMultiplier(plan))}');
      case BudgetCategory.youth:
        return Tr.pick('効きは育成まわりに(準備中)', 'Youth effect (coming soon)');
      case BudgetCategory.facilities:
        final m = BudgetEngine.facilityCostMultiplier(plan);
        return Tr.pick('増築費 ${pct(m)}', 'Upgrade cost ${pct(m)}');
      case BudgetCategory.marketing:
        return Tr.pick('週収入 ${pct(BudgetEngine.incomeMultiplier(plan))}',
            'Weekly income ${pct(BudgetEngine.incomeMultiplier(plan))}');
      case BudgetCategory.dividend:
        final d = BudgetEngine.dividendExpectationDelta(plan);
        return Tr.pick('株主の期待 毎年 ${d >= 0 ? '+' : ''}$d',
            "Shareholders' confidence ${d >= 0 ? '+' : ''}$d per year");
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final plan = _draft ?? gameState.budgetPlan;
    final pool = gameState.annualBudgetPool;
    final amounts = BudgetEngine.allocate(pool, plan);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Tr.pick('今年の予算の配り方', 'How to split this year\'s budget'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              Tr.pick('総額 $pool万円。1つ増やすと、他が比率に応じて減ります。',
                  'Total $pool. Raising one lowers the others in proportion.'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            for (final c in BudgetCategory.values) ...[
              Text('${c.label}  ${plan.share(c)}%'
                  '(${amounts[c]}${Tr.pick('万円', '')})'),
              Text(_effect(c, plan),
                  style: Theme.of(context).textTheme.bodySmall),
              Slider(
                value: plan.share(c).toDouble(),
                min: 0,
                max: 100,
                divisions: 100,
                label: '${plan.share(c)}%',
                onChanged: (v) =>
                    setState(() => _draft = plan.withShare(c, v.round())),
                onChangeEnd: (v) async {
                  await gameState.setBudgetShare(c, v.round());
                  if (mounted) setState(() => _draft = null);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
