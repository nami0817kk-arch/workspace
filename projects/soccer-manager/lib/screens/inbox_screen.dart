import 'package:flutter/material.dart';
import '../theme/semantic_colors.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../state/game_state.dart';
import '../widgets/responsive_body.dart';
import 'news_screen.dart';

/// 受信箱の全部。対応が要るものを上に、その下にお知らせを新しい順に並べる。
///
/// 以前の「すべて見る」はクラブニュースを開いていて、受信箱に出ていた
/// 「対応が要るもの」がどこにも無かった。開いた時点の未読は太字で残す
/// (開いたら既読にするが、どれが新しかったかは分かるように)。
class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  late final int _unreadAtOpen;

  @override
  void initState() {
    super.initState();
    final gs = context.read<GameState>();
    _unreadAtOpen = gs.unreadNewsCount;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) gs.markInboxRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final actions = gs.inboxActions;
    final news = gs.save?.newsLog ?? const [];
    final scheme = Theme.of(context).colorScheme;
    final warn = SemanticColors.ink(context, Colors.orange.shade800);
    return Scaffold(
      appBar: AppBar(
        title: Text(Tr.pick('受信箱', 'Inbox')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const NewsScreen()),
            ),
            child: Text(Tr.pick('検索・絞り込み', 'Search & filter')),
          ),
        ],
      ),
      body: ResponsiveBody(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (actions.isNotEmpty) ...[
              Text(Tr.pick('対応が要るもの', 'Needs your answer'),
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              for (final a in actions)
                ListTile(
                  leading: Icon(Icons.priority_high, color: warn),
                  title: Text(a,
                      style:
                          TextStyle(fontWeight: FontWeight.bold, color: warn)),
                ),
              const Divider(height: 24),
            ],
            Text(Tr.pick('お知らせ', 'News'),
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            if (news.isEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(Tr.pick('まだお知らせはありません', 'Nothing yet')),
              ),
            for (final (i, n) in news.indexed)
              Container(
                color: i.isOdd ? scheme.surfaceContainerLow : null,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 90,
                      child: Text(
                        n.context,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        n.text,
                        style: TextStyle(
                            fontWeight: i < _unreadAtOpen
                                ? FontWeight.bold
                                : FontWeight.normal),
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
