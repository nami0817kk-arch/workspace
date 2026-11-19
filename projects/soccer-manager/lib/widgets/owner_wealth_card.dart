import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/economy_scale.dart';
import '../state/game_state.dart';

/// オーナー個人の財布。クラブへ出資する・貸す・返してもらう。
class OwnerWealthCard extends StatelessWidget {
  const OwnerWealthCard({super.key});

  Future<void> _ask(
    BuildContext context, {
    required String title,
    required int max,
    required Future<bool> Function(int) action,
  }) async {
    if (max <= 0) return;
    var v = (max / 4).roundToDouble();
    final amount = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(formatMoney(v.round())),
              Slider(
                value: v,
                max: max.toDouble(),
                divisions: 20,
                onChanged: (x) => setState(() => v = x),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(Tr.pick('やめる', 'Never mind')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, v.round()),
              child: Text(Tr.pick('決める', 'Confirm')),
            ),
          ],
        ),
      ),
    );
    if (amount == null || amount <= 0) return;
    await action(amount);
  }

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final save = gs.save;
    if (save == null) return const SizedBox.shrink();
    final wealth = gs.ownerWealth;
    final owed = gs.ownerLoanBalance;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Tr.pick('オーナーの財布', 'Your own money'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(Tr.pick('個人資産 ${formatMoney(wealth)}', 'Personal wealth ${formatMoney(wealth)}')),
            Text(Tr.pick(
                'クラブへの貸付 ${formatMoney(owed)}(毎月の利息 ${formatMoney(gs.ownerLoanMonthlyInterest)})',
                'Lent to the club ${formatMoney(owed)} (monthly interest ${formatMoney(gs.ownerLoanMonthlyInterest)})')),
            const SizedBox(height: 4),
            Text(
              Tr.pick(
                  '本業の収入が毎月入ります。出資は返ってきませんが株主に喜ばれます(1季に1回)。貸付は年利${GameStateOwner.loanRatePercent}%で、クラブが毎月利息を払い、いつでも返せます。',
                  'Your business pays you every month. Money you put in never comes back, but the shareholders like it (once a season). Loans earn ${GameStateOwner.loanRatePercent}% a year; the club pays interest monthly and can repay any time.'),
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                FilledButton.tonal(
                  onPressed: wealth > 0
                      ? () => _ask(context,
                          title: Tr.pick('クラブへ出資する', 'Put money in'),
                          max: wealth,
                          action: gs.injectCapital)
                      : null,
                  child: Text(Tr.pick('出資する', 'Invest')),
                ),
                OutlinedButton(
                  onPressed: wealth > 0
                      ? () => _ask(context,
                          title: Tr.pick('クラブへ貸す', 'Lend to the club'),
                          max: wealth,
                          action: gs.lendToClub)
                      : null,
                  child: Text(Tr.pick('貸す', 'Lend')),
                ),
                OutlinedButton(
                  onPressed: owed > 0 && save.budget > 0
                      ? () => _ask(context,
                          title: Tr.pick('貸付を返してもらう', 'Take repayment'),
                          max: owed < save.budget ? owed : save.budget,
                          action: gs.repayOwnerLoan)
                      : null,
                  child: Text(Tr.pick('返してもらう', 'Take repayment')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
