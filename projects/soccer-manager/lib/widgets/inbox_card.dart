import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../screens/news_screen.dart';
import '../state/game_state.dart';

/// 受信箱。直近のお知らせを新しい順に並べる(FM のホームの受信箱に寄せる)。
/// 全部は「すべて見る」から、ニュース画面で絞り込んで読める。
class InboxCard extends StatelessWidget {
  const InboxCard({super.key});

  static const int _shown = 6;

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final all = gs.save?.newsLog ?? const [];
    if (all.isEmpty) return const SizedBox.shrink();
    // newsLog は新しい順に積まれている。先頭から読む。
    final recent = all.take(_shown).toList();
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.inbox_outlined, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(Tr.pick('受信箱', 'Inbox'),
                      style: Theme.of(context).textTheme.titleSmall),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const NewsScreen()),
                  ),
                  child: Text(Tr.pick('すべて見る', 'See all')),
                ),
              ],
            ),
            for (final (i, n) in recent.indexed)
              Container(
                color: i.isOdd ? scheme.surfaceContainerLow : null,
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 76,
                      child: Text(
                        n.context,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        n.text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
