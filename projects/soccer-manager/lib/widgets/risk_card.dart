import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/risk_engine.dart';
import '../state/game_state.dart';
import '../logic/economy_scale.dart';

/// 保険・災害基金・地域貢献。突発の出来事に備え、サポーターとの関係を育てる。
class RiskCard extends StatelessWidget {
  const RiskCard({super.key});

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final save = gs.save;
    if (save == null) return const SizedBox.shrink();
    final tier = save.currentDivisionTier;
    final level = save.communityLevel;
    final next = level + 1;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Tr.pick('備えと地域貢献', 'Safeguards and community'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              Tr.pick(
                  'シーズンの終わりに、不祥事・設備故障・災害のどれかが起きることがあります(約35%)。保険は損失の半分を持ち、基金は残りを先に払います。',
                  'At season end a scandal, breakdown or disaster may strike (about 35%). Insurance covers half; the fund pays the rest first.'),
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: save.insured,
              onChanged: (v) => gs.setInsured(v),
              title: Text(Tr.pick('保険に入る(毎季 ${formatMoney(RiskEngine.premium(tier))})',
                  'Insurance (${formatMoney(RiskEngine.premium(tier))} per season)')),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(Tr.pick('災害基金 ${formatMoney(save.reserveFund)}',
                      'Disaster fund ${formatMoney(save.reserveFund)}')),
                ),
                TextButton(
                  onPressed: () => gs.depositReserveFund(gs.scaledMoney(200)),
                  child: Text('+${formatMoney(gs.scaledMoney(200))}'),
                ),
                TextButton(
                  onPressed: save.reserveFund > 0
                      ? () => gs.depositReserveFund(
                          -gs.scaledMoney(200).clamp(0, save.reserveFund))
                      : null,
                  child: Text('-${formatMoney(gs.scaledMoney(200))}'),
                ),
              ],
            ),
            const Divider(height: 20),
            Text(Tr.pick('地域貢献 Lv$level / ${RiskEngine.maxCommunityLevel}',
                'Community Lv$level / ${RiskEngine.maxCommunityLevel}')),
            Text(
              Tr.pick(
                  '毎季末にサポーターの期待が${RiskEngine.communityTrustGain(level)}上がり、不祥事の傷も浅くなります。',
                  'Each season end supporters rise by ${RiskEngine.communityTrustGain(level)}, and scandals hurt less.'),
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 4),
            OutlinedButton(
              onPressed: level < RiskEngine.maxCommunityLevel
                  ? () => gs.upgradeCommunity()
                  : null,
              child: Text(level < RiskEngine.maxCommunityLevel
                  ? Tr.pick('Lv$nextにする(${formatMoney(gs.scaledMoney(RiskEngine.communityCost(next)))})',
                      'Raise to Lv$next (${formatMoney(gs.scaledMoney(RiskEngine.communityCost(next)))})')
                  : Tr.pick('最大です', 'Maxed')),
            ),
          ],
        ),
      ),
    );
  }
}
