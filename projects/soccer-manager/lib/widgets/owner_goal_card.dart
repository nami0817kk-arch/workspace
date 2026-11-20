import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../models/owner_goal.dart';
import '../state/game_state.dart';

/// オーナーの目標を決める・追っているカード。
///
/// 決めていないあいだは選択肢を出し、決めたら期限までの残りを見せる。
/// 達成は殿堂に残り、期限切れは目標が消えて、また選べる。
class OwnerGoalCard extends StatelessWidget {
  const OwnerGoalCard({super.key});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final goal = gameState.ownerGoal;
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.flag, color: Colors.amber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    goal == null
                        ? Tr.pick('オーナーの目標を決めよう', 'Choose your owner goal')
                        : Tr.pick('オーナーの目標', 'Owner goal'),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (goal != null) ...[
              Text(goal.label, style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                Tr.pick('期限まで あと${gameState.ownerGoalSeasonsLeft}シーズン。達成は殿堂に残ります。',
                    '${gameState.ownerGoalSeasonsLeft} seasons left. Achievements join the hall of fame.'),
                style: theme.textTheme.bodySmall,
              ),
            ] else ...[
              Text(
                Tr.pick('達成すると殿堂に残り、売却後も消えません。',
                    'Achievements stay in the hall of fame, even after a sale.'),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final g in gameState.selectableOwnerGoals)
                    ActionChip(
                      label: Text(
                          '${g.label}(${Tr.pick('${g.deadlineSeasons}年', '${g.deadlineSeasons}y')})'),
                      onPressed: () =>
                          context.read<GameState>().setOwnerGoal(g),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
