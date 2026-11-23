import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/board_engine.dart';
import '../logic/risk_engine.dart';
import '../state/game_state.dart';
import '../logic/economy_scale.dart';
import 'help_button.dart';

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
            TitleWithHelp(
              title: Tr.pick('備えと地域貢献', 'Safeguards and community'),
              help: Tr.pick(
                  'シーズンの終わりに、不祥事・設備故障・災害のどれかが起きることがあります(約35%)。保険は損失の半分を持ち、基金は残りを先に払います。\n\n地域貢献(Lv1以上)を続けている間は、毎月サポーターの期待が+${BoardEngine.communityMonthlyDelta}。レベルを上げるほど不祥事の傷が浅くなります。',
                  'At season end a scandal, breakdown or disaster may strike (about 35%). Insurance covers half; the fund pays the rest first.\n\nWhile you keep up community work (Lv1 or higher), supporter expectation rises by ${BoardEngine.communityMonthlyDelta} every month. Higher levels soften scandals.'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: save.insured,
              onChanged: (v) => gs.setInsured(v),
              title: Text(Tr.pick(
                  '保険に入る(毎季 ${formatMoney(RiskEngine.premium(tier))})',
                  'Insurance (${formatMoney(RiskEngine.premium(tier))} per season)')),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(Tr.pick('災害基金 ${formatMoney(save.reserveFund)}',
                      'Disaster fund ${formatMoney(save.reserveFund)}')),
                ),
                OutlinedButton(
                  onPressed: () => gs.depositReserveFund(gs.scaledMoney(200)),
                  child: Text('+${formatMoney(gs.scaledMoney(200))}'),
                ),
                const SizedBox(width: 6),
                OutlinedButton(
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
            // Lv0 では「期待が0上がる」と出ていた。今の効き目があれば
            // それを、まだ無ければ次のレベルで何が起きるかを出す。
            Text(
              level == 0
                  ? Tr.pick(
                      'Lv1にすると地域活動が始まり、毎月サポーターの期待が+${BoardEngine.communityMonthlyDelta}されます。',
                      'At Lv1 community work begins, and supporter expectation rises by ${BoardEngine.communityMonthlyDelta} every month.')
                  : Tr.pick(
                      '地域活動を続けています。毎月サポーターの期待が+${BoardEngine.communityMonthlyDelta}されます。',
                      'Community work is ongoing: supporter expectation rises by ${BoardEngine.communityMonthlyDelta} every month.'),
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 4),
            FilledButton(
              onPressed: level < RiskEngine.maxCommunityLevel
                  ? () => gs.upgradeCommunity()
                  : null,
              child: Text(level < RiskEngine.maxCommunityLevel
                  ? Tr.pick(
                      'Lv$nextにする(${formatMoney(gs.scaledMoney(RiskEngine.communityCost(next)))})',
                      'Raise to Lv$next (${formatMoney(gs.scaledMoney(RiskEngine.communityCost(next)))})')
                  : Tr.pick('最大です', 'Maxed')),
            ),
          ],
        ),
      ),
    );
  }
}
