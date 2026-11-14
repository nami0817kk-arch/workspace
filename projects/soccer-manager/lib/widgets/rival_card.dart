import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../state/game_state.dart';

/// 宿敵(ライバルクラブ)との通算の戦績。
class RivalCard extends StatelessWidget {
  const RivalCard({super.key});

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final rival = gs.rivalTeam;
    if (gs.save == null || rival == null) return const SizedBox.shrink();
    final all = gs.rivalRecord;
    final now = gs.rivalRecordThisSeason;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Tr.pick('宿敵: ${rival.name}', 'Rival: ${rival.name}'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(Tr.pick('通算 ${all.won}勝${all.draw}分${all.lost}敗',
                'All time: ${all.won}W ${all.draw}D ${all.lost}L')),
            Text(
              Tr.pick('今季 ${now.won}勝${now.draw}分${now.lost}敗',
                  'This season: ${now.won}W ${now.draw}D ${now.lost}L'),
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
