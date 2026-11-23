import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../screens/inbox_screen.dart';
import '../state/game_state.dart';
import '../theme/semantic_colors.dart';

/// 受信箱。直近のお知らせを新しい順に並べる(FM のホームの受信箱に寄せる)。
/// 全部は「すべて見る」から受信箱の画面で読める(絞り込みはその先のニュース画面)。
class InboxCard extends StatelessWidget {
  const InboxCard({super.key});

  /// 状況に出すのは、対応が要るものとお知らせを合わせて3件まで。
  /// 6件出していたころは受信箱だけで1画面を超えていた(2026-11-21)。
  static const int _shown = 3;

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final all = gs.save?.newsLog ?? const [];
    final actions = gs.inboxActions;
    final ultimatumDays = gs.supporterUltimatumDaysLeft;
    if (all.isEmpty && actions.isEmpty && ultimatumDays == null) {
      return const SizedBox.shrink();
    }
    final unread = gs.unreadNewsCount;
    // newsLog は新しい順に積まれている。先頭から読む。
    final shownActions = actions.take(_shown).toList();
    final recent = all.take(_shown - shownActions.length).toList();
    final hidden =
        actions.length - shownActions.length + all.length - recent.length;
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
                // 未読の数は小さな丸に。「受信箱(未読 7)」は横画面の
                // 左の欄で2行に折れていた。
                // 狭い画面・大きい文字では見出しのほうを縮める(ボタンは残す)。
                // Flexible と Spacer が残りを半分ずつ取り合い、見出しが
                // 「受…」に切れていた(2026-11-23)。見出しと丸を Expanded に。
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(Tr.pick('受信箱', 'Inbox'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall),
                      ),
                      if (unread > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 1),
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('$unread',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: scheme.onPrimary)),
                        ),
                    ],
                  ),
                ),
                // 既読にするは印のボタンに(未読の丸を足した分の幅を空ける)。
                if (unread > 0)
                  IconButton(
                    onPressed: gs.markInboxRead,
                    tooltip: Tr.pick('既読にする', 'Mark read'),
                    icon: const Icon(Icons.done_all, size: 20),
                  ),
                TextButton(
                  // 受信箱の全部(対応が要るもの＋お知らせ)を開く。以前は
                  // クラブニュースが開き、対応が要るものが見えなかった。
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const InboxScreen()),
                  ),
                  child: Text(Tr.pick('すべて見る', 'See all')),
                ),
              ],
            ),
            // サポーターの最後通告は、何よりも先に(2026-11-23)。答えを待つ
            // ものとは数えない(数えると節をまとめて進められなくなる)。
            if (ultimatumDays != null)
              Padding(
                key: const ValueKey('inbox-ultimatum'),
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                child: Row(
                  children: [
                    Icon(Icons.campaign,
                        size: 14, color: SemanticColors.negative(context)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                          Tr.pick(
                              '最後通告: 残り$ultimatumDays日でサポーターの期待を${GameStateSupporters.ultimatumLine}以上に(いま${gs.save!.confidence})',
                              'Final warning: get supporter expectation to ${GameStateSupporters.ultimatumLine}+ within ${Tr.plural(ultimatumDays, 'day')} (now ${gs.save!.confidence})'),
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: SemanticColors.negative(context))),
                    ),
                  ],
                ),
              ),
            // 対応が要るもの(オーナーの答えを待っているもの)を先に。
            for (final a in shownActions)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                child: Row(
                  children: [
                    Icon(Icons.priority_high,
                        size: 14,
                        color: SemanticColors.ink(
                            context, Colors.orange.shade800)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(a,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: SemanticColors.ink(
                                  context, Colors.orange.shade800))),
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
                            fontWeight: i < unread
                                ? FontWeight.bold
                                : FontWeight.normal),
                      ),
                    ),
                  ],
                ),
              ),
            if (hidden > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
                child: Text(
                  Tr.pick('ほか$hidden件は「すべて見る」から', '$hidden more in "See all"'),
                  style:
                      TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
