import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/equity_engine.dart';
import '../state/game_state.dart';
import '../logic/economy_scale.dart';
import 'help_button.dart';
import 'disabled_reason.dart';

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
            // 決まりは「?」の中へ。金額はボタンに添える(2026-11-21)。
            TitleWithHelp(
              title: Tr.pick('持分と株主', 'Ownership'),
              help: Tr.pick(
                  '株式を${EquityEngine.step}%ずつ外部の株主へ売って資金を得られます(増資)。外部の株主には、黒字の半分が持分の割合で配当されます。買い戻すには売った値より多くかかります。持分は${EquityEngine.minOwnerShare}%を割れません。',
                  'Sell ${EquityEngine.step}% at a time to outside holders to raise money. They share half of any profit by their stake. Buying back costs more than you sold for. You must keep ${EquityEngine.minOwnerShare}%.'),
            ),
            Text(Tr.pick('オーナーの持分 $share%(外部 ${100 - share}%)',
                'Your stake $share% (outside ${100 - share}%)')),
            Text(EquityEngine.mood(save.shareholderExpectation),
                style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                FilledButton.tonal(
                  onPressed: canSell ? () => gs.sellStake() : null,
                  child: Text(Tr.pick(
                      '${EquityEngine.step}%売る(+${formatMoney(sale)})',
                      'Sell ${EquityEngine.step}% (+${formatMoney(sale)})')),
                ),
                OutlinedButton(
                  onPressed: canBuy ? () => gs.buyBackStake() : null,
                  child: Text(Tr.pick('買い戻す(${formatMoney(buy)})',
                      'Buy back (${formatMoney(buy)})')),
                ),
              ],
            ),
            // 売る・買い戻すが押せない理由(持分の下限・外部の株主がいない)。
            if (!canSell)
              DisabledReason(
                Tr.pick('持分は${EquityEngine.minOwnerShare}%を割れないので、これ以上は売れません',
                    'You must keep ${EquityEngine.minOwnerShare}%, so you cannot sell any more'),
                key: const ValueKey('equity-sell-blocked'),
              ),
            if (!canBuy)
              DisabledReason(
                Tr.pick('外部の株主がいないので、買い戻す株がありません',
                    'There are no outside holders, so there is nothing to buy back'),
                key: const ValueKey('equity-buy-blocked'),
              ),
          ],
        ),
      ),
    );
  }
}
