import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/policy_engine.dart';
import '../state/game_state.dart';

/// オーナーが選ぶクラブの方針。開幕前にだけ変えられる。
class ClubPolicyCard extends StatelessWidget {
  const ClubPolicyCard({super.key});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    if (gameState.save == null) return const SizedBox.shrink();
    final current = gameState.clubPolicy;
    final canChange = gameState.canChangeClubPolicy;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Tr.pick('クラブの方針', 'Club policy'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              canChange
                  ? Tr.pick('シーズンの開幕前だけ変えられます。シーズン末に採点されます。',
                      'You can change this only before the season starts. It is scored at the end.')
                  : Tr.pick('今シーズンはもう変えられません。シーズン末に採点されます。',
                      'It is locked for this season and will be scored at the end.'),
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final p in ClubPolicy.values)
                  ChoiceChip(
                    label: Text(p.label),
                    selected: p == current,
                    onSelected: canChange && p != current
                        ? (_) => context.read<GameState>().setClubPolicy(p)
                        : null,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(current.summary, style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
