import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/tr.dart';
import '../screens/inbox_screen.dart';
import '../state/game_state.dart';

/// 受信箱の入口。状況には**件数の1行だけ**を出し、押すと受信箱の画面が開く。
///
/// 2026-11-25 に1行にした。以前は対応が要るもの(「オーナーの判断を待つ
/// 出来事があります」)とお知らせを3件まで並べていて、同じ用件が右の
/// 「やること」の札と二重に出ていた。答えるものは「やること」に、読むものは
/// 受信箱の画面に。
class InboxCard extends StatelessWidget {
  const InboxCard({super.key});

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final all = gs.save?.newsLog ?? const [];
    if (all.isEmpty) return const SizedBox.shrink();
    final unread = gs.unreadNewsCount;
    final scheme = Theme.of(context).colorScheme;
    // 新しい順に積まれている。いちばん新しいものの題を1行で添える。
    final latest = all.first;
    return Card(
      key: const ValueKey('inbox-line'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const InboxScreen()),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                const Icon(Icons.inbox_outlined, size: 20),
                const SizedBox(width: 8),
                Text(Tr.pick('受信箱', 'Inbox'),
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                if (unread > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      Tr.pick('未読$unread', '$unread new'),
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: scheme.onPrimary),
                    ),
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    latest.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
                ),
                Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
