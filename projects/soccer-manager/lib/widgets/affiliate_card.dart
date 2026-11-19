import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/economy_scale.dart';
import '../state/game_state.dart';

/// 系列クラブ。提携先の選手は2割引で取れ、貸し出しは提携先へ出場機会付きで送る。
class AffiliateCard extends StatelessWidget {
  const AffiliateCard({super.key});

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    if (gs.save == null) return const SizedBox.shrink();
    final current = gs.affiliateClub;
    final fee = gs.scaledMoney(GameStateAffiliate.annualFee);
    final candidates = gs.affiliateCandidates();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Tr.pick('系列クラブ', 'Affiliate club'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
                Tr.pick(
                    '自クラブより弱いクラブと提携します(年会費${formatMoney(fee)})。提携先の選手は2割引で取れ、貸し出しは提携先へ出場機会付きで送ります。',
                    'Partner a weaker club (${formatMoney(fee)} a year). Their players come 20% cheaper, and your loans go there with playing time guaranteed.'),
                style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            if (current != null)
              Row(
                children: [
                  Expanded(
                      child: Text(Tr.pick('提携先: ${current.name}',
                          'Partner: ${current.name}'))),
                  TextButton(
                    onPressed: () => gs.endAffiliate(),
                    child: Text(Tr.pick('提携をやめる', 'End it')),
                  ),
                ],
              ),
            if (current == null)
              if (candidates.isEmpty)
                Text(Tr.pick('提携できるクラブがありません',
                    'No club to partner with yet'))
              else
                for (final t in candidates)
                  Row(
                    children: [
                      Expanded(
                          child: Text(Tr.pick('${t.name}(力${t.overallRating})',
                              '${t.name} (strength ${t.overallRating})'))),
                      FilledButton.tonal(
                        onPressed: gs.save!.budget >= fee
                            ? () => gs.setAffiliateClub(t.id)
                            : null,
                        child: Text(Tr.pick('提携する', 'Partner')),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }
}
