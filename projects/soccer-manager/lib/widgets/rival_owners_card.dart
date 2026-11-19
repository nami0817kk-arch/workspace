import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../state/game_state.dart';
import '../theme/semantic_colors.dart';

/// 同じリーグで競う他のオーナー。
class RivalOwnersCard extends StatelessWidget {
  const RivalOwnersCard({super.key});

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final rivals = gs.rivalOwners;
    if (rivals.isEmpty) return const SizedBox.shrink();
    final small =
        TextStyle(fontSize: 12, color: SemanticColors.subtleText(context));
    String stars(int n) => List.filled(n, '*').join();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Tr.pick('競い合うオーナー', 'Rival owners'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            for (final r in rivals)
              Text(Tr.pick(
                  '${r.clubName}: ${r.name}・野心 ${stars(r.ambition)}・今季の補強 ${r.signingsThisSeason}人',
                  '${r.clubName}: ${r.name}, ambition ${stars(r.ambition)}, signed ${r.signingsThisSeason} this season')),
            const SizedBox(height: 4),
            Text(
                Tr.pick('窓が開くたびに、野心の数だけ自由契約から選手を足します。交渉中の選手を横取りしに来るのも、まずこのオーナーたちです。',
                    'Each window they add as many free agents as their ambition allows, and they are first in line to gatecrash your negotiations.'),
                style: small),
          ],
        ),
      ),
    );
  }
}
