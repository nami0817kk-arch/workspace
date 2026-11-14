import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/media_deals_engine.dart';
import '../state/game_state.dart';

/// スタジアムの命名権と、放映権の分配金の受け取り方。
class MediaDealsCard extends StatelessWidget {
  const MediaDealsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final save = gs.save;
    if (save == null) return const SizedBox.shrink();
    final tier = save.currentDivisionTier;
    final naming = save.namingDeal;
    final offers = save.pendingNamingOffers;
    final holiday = save.tvHolidaySeasons;
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
                  '${naming.name}: 週${naming.weeklyIncome}万円・残り${naming.yearsRemaining}年',
                  '${naming.name}: ${naming.weeklyIncome}/week, ${naming.yearsRemaining} yr left'))
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
                            '${offers[i].name} 週${offers[i].weeklyIncome}万円・${offers[i].yearsRemaining}年',
                            '${offers[i].name} ${offers[i].weeklyIncome}/week, ${offers[i].yearsRemaining} yr')),
                      ),
                      FilledButton.tonal(
                        onPressed: () => gs.chooseNamingRights(i),
                        child: Text(Tr.pick('結ぶ', 'Sign')),
                      ),
                    ],
                  ),
                ),
            const Divider(height: 24),
            Text(Tr.pick('放映権の分配金(基準 ${MediaDealsEngine.tvBase(tier)}万円/季)',
                'TV money (base ${MediaDealsEngine.tvBase(tier)}/season)'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            SegmentedButton<TvDeal>(
              segments: [
                for (final d in TvDeal.values)
                  ButtonSegment(value: d, label: Text(d.label)),
              ],
              selected: {save.tvDeal},
              onSelectionChanged: gs.canChangeClubPolicy
                  ? (s) => gs.setTvDeal(s.first)
                  : null,
            ),
            const SizedBox(height: 4),
            Text(save.tvDeal.summary, style: const TextStyle(fontSize: 12)),
            if (!gs.canChangeClubPolicy)
              Text(Tr.pick('受け取り方は開幕前にだけ変えられます',
                  'You can only change this before the season starts'),
                  style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            if (holiday > 0)
              Text(Tr.pick('前払いの精算中: あと$holiday季は分配金が出ません',
                  'Advance in repayment: no TV money for $holiday more season(s)'))
            else
              OutlinedButton(
                onPressed: () => gs.takeTvAdvance(),
                child: Text(Tr.pick(
                    '前払いを受ける(${MediaDealsEngine.advanceAmount(tier)}万円・以後${MediaDealsEngine.advanceHolidaySeasons}季は分配金なし)',
                    'Take an advance (${MediaDealsEngine.advanceAmount(tier)}; no TV money for ${MediaDealsEngine.advanceHolidaySeasons} seasons)')),
              ),
          ],
        ),
      ),
    );
  }
}
