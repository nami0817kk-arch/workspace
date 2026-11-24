import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/board_engine.dart';
import '../logic/risk_engine.dart';
import '../state/game_state.dart';
import '../logic/economy_scale.dart';
import 'help_button.dart';

/// 保険・災害基金。突発の出来事に備える。地域貢献は「クラブ > ファンと街」の
/// CommunityCard へ移した(2026-11-24。地域の用件を1か所に)。
class RiskCard extends StatelessWidget {
  const RiskCard({super.key});

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final save = gs.save;
    if (save == null) return const SizedBox.shrink();
    final tier = save.currentDivisionTier;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TitleWithHelp(
              title: Tr.pick('備えと保険', 'Safeguards and insurance'),
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
          ],
        ),
      ),
    );
  }
}
