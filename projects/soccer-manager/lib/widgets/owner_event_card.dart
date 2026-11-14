import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../models/owner_event.dart';
import '../state/game_state.dart';

/// オーナーの判断を迫る事件のカード。答えを選ぶまで残る。
class OwnerEventCard extends StatelessWidget {
  const OwnerEventCard({super.key});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final kind = gameState.pendingOwnerEvent;
    if (kind == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final options = kind.options;

    String signed(int v) => v > 0 ? '+$v' : '$v';

    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(kind.title, style: theme.textTheme.titleSmall),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(kind.body),
            const SizedBox(height: 10),
            for (var i = 0; i < options.length; i++) ...[
              OutlinedButton(
                onPressed: () => context.read<GameState>().resolveOwnerEvent(i),
                child: Text(options[i].label, textAlign: TextAlign.center),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 8),
                child: Text(
                  Tr.pick(
                      'サポーター${signed(options[i].supportersDelta)} / 株主${signed(options[i].shareholdersDelta)}',
                      'Supporters ${signed(options[i].supportersDelta)} / Shareholders ${signed(options[i].shareholdersDelta)}'),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
