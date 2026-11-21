import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/economy_scale.dart';
import '../state/game_state.dart';
import 'help_button.dart';

/// 系列クラブ。提携先の選手は2割引で取れ、貸し出しは提携先へ出場機会付きで送る。
class AffiliateCard extends StatefulWidget {
  const AffiliateCard({super.key});

  @override
  State<AffiliateCard> createState() => _AffiliateCardState();
}

class _AffiliateCardState extends State<AffiliateCard> {
  /// 候補は上の3つだけ出し、残りは「もっと見る」で(2026-11-21)。
  static const _shown = 3;
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    if (gs.save == null) return const SizedBox.shrink();
    final current = gs.affiliateClub;
    final fee = gs.scaledMoney(GameStateAffiliate.annualFee);
    final candidates = gs.affiliateCandidates();
    final visible = _all ? candidates : candidates.take(_shown).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TitleWithHelp(
              title: Tr.pick('系列クラブ(年会費${formatMoney(fee)})',
                  'Affiliate club (${formatMoney(fee)} a year)'),
              help: Tr.pick(
                  '自クラブより弱いクラブと提携します(年会費${formatMoney(fee)})。提携先の選手は2割引で取れ、貸し出しは提携先へ出場機会付きで送ります。',
                  'Partner a weaker club (${formatMoney(fee)} a year). Their players come 20% cheaper, and your loans go there with playing time guaranteed.'),
            ),
            if (current != null)
              Row(
                children: [
                  Expanded(
                      child: Text(Tr.pick(
                          '提携先: ${current.name}', 'Partner: ${current.name}'))),
                  TextButton(
                    onPressed: () => gs.endAffiliate(),
                    child: Text(Tr.pick('提携をやめる', 'End it')),
                  ),
                ],
              ),
            if (current == null)
              if (candidates.isEmpty)
                Text(Tr.pick('提携できるクラブがありません', 'No club to partner with yet'))
              else ...[
                for (final t in visible)
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
                if (candidates.length > _shown)
                  TextButton(
                    onPressed: () => setState(() => _all = !_all),
                    child: Text(_all
                        ? Tr.pick('閉じる', 'Show fewer')
                        : Tr.pick('もっと見る(ほか${candidates.length - _shown})',
                            'Show more (${candidates.length - _shown} more)')),
                  ),
              ],
          ],
        ),
      ),
    );
  }
}
