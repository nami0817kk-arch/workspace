import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../state/game_state.dart';

/// クラブの年表(記録室)。優勝・昇降格・大きな決断が新しい順に並ぶ。
class ClubTimelineCard extends StatelessWidget {
  const ClubTimelineCard({super.key});

  static const int _shown = 12;

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final all = gs.save?.timeline ?? const [];
    if (all.isEmpty) return const SizedBox.shrink();
    final recent = all.reversed.take(_shown).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Tr.pick('クラブの年表', 'Club timeline'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            for (final e in recent)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 56,
                      child: Text(Tr.pick('第${e.season}季', 'S${e.season}'),
                          style: const TextStyle(fontSize: 12)),
                    ),
                    Expanded(child: Text(e.text)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
