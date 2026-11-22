import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/media_deals_engine.dart';
import '../state/game_state.dart';
import '../logic/economy_scale.dart';

/// スタジアムの命名権と、放映権の配分(国のリーグの式。選ぶものは無い)。
class MediaDealsCard extends StatelessWidget {
  const MediaDealsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final save = gs.save;
    if (save == null) return const SizedBox.shrink();
    final naming = save.namingDeal;
    final offers = save.pendingNamingOffers;
    final holiday = save.tvHolidaySeasons;
    final shares = MediaDealsEngine.sharesFor(gs.currentLeagueTheme);
    String pct(double v) => (v * 100).round().toString();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Tr.pick('命名権と放映権', 'Naming rights and TV money'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(Tr.pick('スタジアムの命名権', 'Stadium naming rights'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            if (naming != null)
              Text(Tr.pick(
                  '${naming.name}: 週${formatMoney(naming.weeklyIncome)}・残り${naming.yearsRemaining}年',
                  '${naming.name}: ${formatMoney(naming.weeklyIncome)}/week, ${naming.yearsRemaining} yr left'))
            else if (offers.isEmpty)
              Text(Tr.pick('提示はありません(次のシーズン末に出ます)',
                  'No offers (next ones come at season end)'))
            else
              for (var i = 0; i < offers.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(Tr.pick(
                            '${offers[i].name} 週${formatMoney(offers[i].weeklyIncome)}・${offers[i].yearsRemaining}年',
                            '${offers[i].name} ${formatMoney(offers[i].weeklyIncome)}/week, ${offers[i].yearsRemaining} yr')),
                      ),
                      FilledButton.tonal(
                        onPressed: () => gs.chooseNamingRights(i),
                        child: Text(Tr.pick('結ぶ', 'Sign')),
                      ),
                    ],
                  ),
                ),
            const Divider(height: 24),
            Text(Tr.pick('放映権(リーグの配分)', 'TV money (league distribution)'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(Tr.pick(
                '均等割${pct(shares.equal)}%・順位${pct(shares.merit)}%・中継回数${pct(shares.facility)}%',
                'Equal share ${pct(shares.equal)}%, merit ${pct(shares.merit)}%, facility fees ${pct(shares.facility)}%')),
            Text(
                Tr.pick(
                    '季の間に4回で${formatMoney(gs.guaranteedBroadcastAnnual)}、順位と中継の分は季末。今の順位なら年${formatMoney(gs.projectedBroadcastTotal)}',
                    '${formatMoney(gs.guaranteedBroadcastAnnual)} in four payments, the merit and facility part at season end. At the current position: ${formatMoney(gs.projectedBroadcastTotal)} a year'),
                style: const TextStyle(fontSize: 12)),
            if (holiday > 0)
              Text(
                  Tr.pick('前払いの精算中: あと$holiday季は季末の配分が出ません',
                      'Advance in repayment: no season-end TV money for $holiday more season(s)'),
                  style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
