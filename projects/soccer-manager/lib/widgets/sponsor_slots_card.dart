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
    // 額は胸のスポンサーと同じく1年あたり(1節の額 × 季の節の数)で出す。
    // 以前は「週」と書いていたが、入るのは毎節で、胸のスポンサーの
    // 「/年」とも単位が揃っていなかった(2026-11-23)。
    final md = gs.matchdaysPerSeason;
    final String text;
    if (deal != null) {
      text = Tr.pick(
          '${slot.label}: ${deal.name}・年${formatMoney(deal.weeklyIncome * md)}・残り${deal.yearsRemaining}年',
          '${slot.label}: ${deal.name}, ${formatMoney(deal.weeklyIncome * md)} a year, ${Tr.plural(deal.yearsRemaining, 'year')} left');
    } else if (offer != null) {
      text = Tr.pick(
          '${slot.label}: ${offer.name}から提示・年${formatMoney(offer.weeklyIncome * md)}・${offer.yearsRemaining}年',
          '${slot.label}: offer from ${offer.name}, ${formatMoney(offer.weeklyIncome * md)} a year for ${Tr.plural(offer.yearsRemaining, 'year')}');
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
