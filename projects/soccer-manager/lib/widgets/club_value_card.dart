import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../state/game_state.dart';
import '../theme/semantic_colors.dart';

/// クラブ価値(いま売ったらいくらか、の目安)と内訳、シーズンごとの推移。
class ClubValueCard extends StatelessWidget {
  const ClubValueCard({super.key});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final save = gameState.save;
    if (save == null) return const SizedBox.shrink();
    final value = gameState.clubValue;
    final history = gameState.clubValueHistory;
    final goalActive = save.ownerGoalStartValue > 0 &&
        gameState.ownerGoal != null &&
        gameState.ownerGoal!.name == 'clubValue';

    Text money(int v, {bool bold = false, Color? color}) => Text(
          Tr.pick('$v万円', '$v'),
          style: TextStyle(
              fontWeight: bold ? FontWeight.bold : null, color: color),
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Tr.pick('クラブ価値', 'Club value'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              Tr.pick('${value.total}万円', '${value.total}'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (goalActive)
              Text(
                Tr.pick(
                    '目標の開始時の${(value.total / save.ownerGoalStartValue).toStringAsFixed(2)}倍(2倍で達成)',
                    '${(value.total / save.ownerGoalStartValue).toStringAsFixed(2)}x since you set the goal (2x to win)'),
                style: const TextStyle(fontSize: 12),
              ),
            const SizedBox(height: 8),
            for (final (label, amount) in value.lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Row(
                  children: [
                    Expanded(child: Text(label)),
                    money(amount,
                        color: amount < 0
                            ? SemanticColors.negative(context)
                            : null),
                  ],
                ),
              ),
            if (history.isNotEmpty) ...[
              const Divider(height: 20),
              Text(Tr.pick('シーズン末の推移', 'End-of-season history'),
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold)),
              for (var i = history.length - 1; i >= 0; i--)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Row(
                    children: [
                      Expanded(
                          child: Text(Tr.pick('第${history[i].$1}季',
                              'Season ${history[i].$1}'))),
                      Text(
                        i > 0
                            ? Tr.pick(
                                '${history[i].$2}万円 (${history[i].$2 - history[i - 1].$2 >= 0 ? '+' : ''}${history[i].$2 - history[i - 1].$2})',
                                '${history[i].$2} (${history[i].$2 - history[i - 1].$2 >= 0 ? '+' : ''}${history[i].$2 - history[i - 1].$2})')
                            : Tr.pick('${history[i].$2}万円', '${history[i].$2}'),
                        style: TextStyle(
                          color: i > 0 &&
                                  history[i].$2 < history[i - 1].$2
                              ? SemanticColors.negative(context)
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
