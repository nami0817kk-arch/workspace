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

    // 決める前は1行の札だけ。7つの選択肢を状況に並べると、それだけで
    // 2画面分あった(2026-11-21)。押すと選ぶ画面が開く。
    if (goal == null) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.flag, color: Colors.amber),
          title: Text(Tr.pick('オーナーの目標を決める', 'Choose your owner goal'),
              style: theme.textTheme.titleSmall),
          subtitle: Text(Tr.pick('達成すると殿堂に残り、売却後も消えません。',
              'Achievements stay in the hall of fame, even after a sale.')),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => choose(context),
        ),
      );
    }

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
                    Tr.pick('オーナーの目標', 'Owner goal'),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(goal.label, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              Tr.pick(
                  '期限まで あと${gameState.ownerGoalSeasonsLeft}シーズン。達成は殿堂に残ります。',
                  '${Tr.plural(gameState.ownerGoalSeasonsLeft, 'season')} left. Achievements join the hall of fame.'),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  /// 目標を選ぶ画面(下から出る一覧)。今週の決断のカードからも開く。
  static Future<void> choose(BuildContext context) async {
    final game = context.read<GameState>();
    final picked = await showModalBottomSheet<OwnerGoal>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Text(Tr.pick('オーナーの目標を選ぶ', 'Choose your owner goal'),
                    style: Theme.of(ctx).textTheme.titleMedium),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                    Tr.pick('達成すると殿堂に残り、売却後も消えません。期限を過ぎると目標は消え、また選べます。',
                        'Achievements stay in the hall of fame, even after a sale. Missed goals expire and you can pick again.'),
                    style: Theme.of(ctx).textTheme.bodySmall),
              ),
              for (final g in game.selectableOwnerGoals)
                ListTile(
                  leading: const Icon(Icons.flag_outlined),
                  title: Text(g.label),
                  trailing: Text(Tr.pick('期限${g.deadlineSeasons}年',
                      Tr.plural(g.deadlineSeasons, 'season'))),
                  onTap: () => Navigator.of(ctx).pop(g),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (picked != null) game.setOwnerGoal(picked);
  }
}
