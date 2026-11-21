import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/club_culture.dart';
import '../state/game_state.dart';
import 'help_button.dart';
import '../theme/semantic_colors.dart';

/// クラブの文化を選ぶ(1季に1回まで)。
class ClubCultureCard extends StatelessWidget {
  const ClubCultureCard({super.key});

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    if (gs.save == null) return const SizedBox.shrink();
    final current = gs.clubCulture;
    final canChange = gs.canChangeClubCulture;
    final small =
        TextStyle(fontSize: 12, color: SemanticColors.subtleText(context));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TitleWithHelp(
              title: Tr.pick('クラブの文化', 'Club identity'),
              help: Tr.pick(
                  '文化に沿った試合のたびにサポーターの期待+1。変えられるのは1季に1回で、決めたものから変えると期待-${ClubCultureEngine.changePenalty}。',
                  'Each match that fits the identity adds 1 to fan faith. You can change it once a season; switching away costs ${ClubCultureEngine.changePenalty}.'),
            ),
            Text(current.description, style: small),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                for (final c in ClubCulture.values)
                  ChoiceChip(
                    label: Text(c.label),
                    selected: c == current,
                    onSelected: canChange && c != current
                        ? (_) => gs.setClubCulture(c)
                        : null,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
