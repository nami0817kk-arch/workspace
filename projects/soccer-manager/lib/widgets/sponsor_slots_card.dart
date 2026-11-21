import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/economy_scale.dart';
import '../logic/sponsor_slots.dart';
import '../state/game_state.dart';
import 'help_button.dart';

/// 枠ごとのスポンサー(袖・背中・練習着)。胸のスポンサーとは別の会社と結ぶ。
class SponsorSlotsCard extends StatelessWidget {
  const SponsorSlotsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    if (gs.save == null) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TitleWithHelp(
              title: Tr.pick('枠ごとのスポンサー', 'Other sponsor slots'),
              help: Tr.pick('胸のスポンサーとは別の会社と結べます。空いた枠には季の始めに提示が来ます。',
                  'Each slot can carry a different company from your shirt sponsor. Empty slots get an offer at the start of each season.'),
            ),
            for (final slot in SponsorSlot.values) _SlotRow(slot: slot),
          ],
        ),
      ),
    );
  }
}

class _SlotRow extends StatelessWidget {
  const _SlotRow({required this.slot});

  final SponsorSlot slot;

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final deal = gs.slotSponsor(slot);
    final offer = gs.slotSponsorOffer(slot);
    final String text;
    if (deal != null) {
      text = Tr.pick(
          '${slot.label}: ${deal.name}・週${formatMoney(deal.weeklyIncome)}・残り${deal.yearsRemaining}年',
          '${slot.label}: ${deal.name}, ${formatMoney(deal.weeklyIncome)}/week, ${deal.yearsRemaining} yr left');
    } else if (offer != null) {
      text = Tr.pick(
          '${slot.label}: ${offer.name}から提示・週${formatMoney(offer.weeklyIncome)}・${offer.yearsRemaining}年',
          '${slot.label}: offer from ${offer.name}, ${formatMoney(offer.weeklyIncome)}/week, ${offer.yearsRemaining} yr');
    } else {
      text = Tr.pick('${slot.label}: 空き(次の季の始めに提示が来ます)',
          '${slot.label}: empty (an offer comes next season)');
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(text)),
          if (deal == null && offer != null) ...[
            TextButton(
              onPressed: () => gs.declineSlotSponsor(slot),
              child: Text(Tr.pick('見送る', 'Decline')),
            ),
            FilledButton.tonal(
              onPressed: () => gs.signSlotSponsor(slot),
              child: Text(Tr.pick('結ぶ', 'Sign')),
            ),
          ],
        ],
      ),
    );
  }
}
