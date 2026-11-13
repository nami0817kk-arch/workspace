import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../state/game_state.dart';

/// 次の試合を「勝負の試合」にするか決める帯。
///
/// ふだんの試合は監督が先発と構えを決める。宣言した試合(年に数回)だけ、
/// 先発と戦術を自分で決める。
class BigMatchBar extends StatelessWidget {
  const BigMatchBar({super.key});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final theme = Theme.of(context);

    if (gameState.isNextMatchBig) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.amber),
        ),
        child: Row(
          children: [
            const Icon(Icons.bolt, color: Colors.amber),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                Tr.pick('勝負の試合です。先発と戦術はあなたが決めます。',
                    'Big match: you pick the XI and tactics.'),
                style: theme.textTheme.bodyMedium,
              ),
            ),
            TextButton(
              onPressed: () => context.read<GameState>().cancelBigMatch(),
              child: Text(Tr.pick('取り消す', 'Cancel')),
            ),
          ],
        ),
      );
    }

    final left = gameState.bigMatchesLeft;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            Tr.pick('ふだんは監督が先発と構えを決めます。',
                'Usually the manager picks the XI and approach.'),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed:
                left > 0 ? () => context.read<GameState>().declareBigMatch() : null,
            icon: const Icon(Icons.bolt),
            label: Text(Tr.pick('勝負の試合にする(今季あと$left回)',
                'Call it a big match ($left left this season)')),
          ),
        ],
      ),
    );
  }
}
