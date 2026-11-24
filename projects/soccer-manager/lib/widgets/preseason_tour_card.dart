import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/economy_scale.dart';
import '../models/preseason_camp.dart';
import '../state/game_state.dart';

/// 開幕前に海外ツアーへ出るか(興行の判断なのでオーナーが決める)。
/// 練習のキャンプは監督の仕事なので、ここには出さない。
class PreseasonTourCard extends StatelessWidget {
  const PreseasonTourCard({super.key});

  /// カードを出すか: 開幕前(まだリーグ戦が1つも済んでいない)で、未決のとき。
  static bool visible(GameState gs) => gs.preseasonTourPending;

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    if (!visible(gs)) return const SizedBox.shrink();
    const tour = PreseasonCamp.overseasTour;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Tr.pick('開幕前の海外ツアー', 'Pre-season overseas tour'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              Tr.pick(
                  '興行の収入${formatMoney(gs.scaledMoney(tour.revenue))}が入りますが、移動の疲れ(+${tour.fatigueCost})を残して開幕します。',
                  'Brings in ${formatMoney(gs.scaledMoney(tour.revenue))}, but the squad starts the season tired (+${tour.fatigueCost} fatigue).'),
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                FilledButton(
                  onPressed: () => gs.choosePreseasonCamp(tour),
                  child: Text(Tr.pick('ツアーに出る', 'Go on tour')),
                ),
                OutlinedButton(
                  onPressed: () => gs.choosePreseasonCamp(PreseasonCamp.none),
                  child: Text(Tr.pick('出ない', 'Stay home')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
