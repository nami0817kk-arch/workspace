import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/equity_engine.dart';
import '../state/game_state.dart';

/// オーナーの持分。外部の株主へ株式を売って資金を得る(増資)。売った分は
/// 毎季の配当で出ていく。買い戻すにはプレミアが要る。
class EquityCard extends StatelessWidget {
  const EquityCard({super.key});

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final save = gs.save;
    if (save == null) return const SizedBox.shrink();
    final share = gs.ownerShare;
    final value = gs.clubValue.total;
    final canSell = EquityEngine.sellable(share) > 0;
    final canBuy = share < 100;
    final sale = EquityEngine.salePrice(value, EquityEngine.step);
    final buy = EquityEngine.buybackCost(value, EquityEngine.step);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Tr.pick('持分と株主', 'Ownership'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(Tr.pick('オーナーの持分 $share%(外部 ${100 - share}%)',
                'Your stake $share% (outside ${100 - share}%)')),
            Text(EquityEngine.mood(save.shareholderExpectation),
                style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            Text(
              Tr.pick(
                  '${EquityEngine.step}%を売ると$sale万円。買い戻しは$buy万円。外部の株主には、黒字の半分が持分の割合で配当されます。持分は${EquityEngine.minOwnerShare}%を割れません。',
                  'Selling ${EquityEngine.step}% raises $sale; buying back costs $buy. Outside holders share half of any profit. You must keep ${EquityEngine.minOwnerShare}%.'),
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: canSell ? () => gs.sellStake() : null,
                  child: Text(Tr.pick('株式を売る(増資)', 'Sell a stake')),
                ),
                OutlinedButton(
                  onPressed: canBuy ? () => gs.buyBackStake() : null,
                  child: Text(Tr.pick('買い戻す', 'Buy back')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
