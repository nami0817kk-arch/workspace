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
    final actions = gs.inboxActions;
    if (all.isEmpty && actions.isEmpty) return const SizedBox.shrink();
    final unread = gs.unreadNewsCount;
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
                  child: Text(
                      unread > 0
                          ? Tr.pick('受信箱(未読 $unread)', 'Inbox ($unread unread)')
                          : Tr.pick('受信箱', 'Inbox'),
                      style: Theme.of(context).textTheme.titleSmall),
                ),
                if (unread > 0)
                  TextButton(
                    onPressed: gs.markInboxRead,
                    child: Text(Tr.pick('既読にする', 'Mark read')),
                  ),
                TextButton(
                  onPressed: () {
                    gs.markInboxRead();
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => const NewsScreen()),
                    );
                  },
                  child: Text(Tr.pick('すべて見る', 'See all')),
                ),
              ],
            ),
            // 対応が要るもの(オーナーの答えを待っているもの)を先に。
            for (final a in actions)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                child: Row(
                  children: [
                    Icon(Icons.priority_high,
                        size: 14, color: Colors.orange.shade800),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(a,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade800)),
                    ),
                  ],
                ),
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
                        // 未読は太字。
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                i < unread ? FontWeight.bold : FontWeight.normal),
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
