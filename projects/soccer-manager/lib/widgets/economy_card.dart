import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/economy_engine.dart';
import '../state/game_state.dart';
import '../theme/semantic_colors.dart';

/// 景気(今季と来季の予報)。クラブ経営の画面に置く。
class EconomyCard extends StatelessWidget {
  const EconomyCard({super.key});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    if (gameState.save == null) return const SizedBox.shrink();
    final now = gameState.economyPhase;
    final next = gameState.economyNext;

    Color color(EconomyPhase p) => switch (p) {
          EconomyPhase.boom => SemanticColors.positive(context),
          EconomyPhase.slump => SemanticColors.negative(context),
          EconomyPhase.normal => Theme.of(context).colorScheme.onSurface,
        };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Tr.pick('景気', 'Economy'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              Tr.pick('今季: ${now.label}', 'This season: ${now.label}'),
              style: TextStyle(fontWeight: FontWeight.bold, color: color(now)),
            ),
            Text(now.summary, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 6),
            Text(
              Tr.pick('来季の予報: ${next.label}', 'Next season: ${next.label}'),
              style: TextStyle(fontWeight: FontWeight.bold, color: color(next)),
            ),
            if (next == EconomyPhase.slump)
              Text(
                Tr.pick('来季は不況の見込みです。人件費を絞るか、資金を厚くしておきましょう。',
                    'A slump is forecast. Trim wages or build a cash buffer.'),
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }
}
