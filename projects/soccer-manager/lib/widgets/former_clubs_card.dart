import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../state/game_state.dart';

/// 手放したクラブのその後。
class FormerClubsCard extends StatelessWidget {
  const FormerClubsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final list = gs.formerClubsAfter;
    if (list.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Tr.pick('手放したクラブのその後', 'Your former clubs'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final (name, st) in list)
              Text(st == null
                  ? Tr.pick('$name: 季の終わりに分かります',
                      '$name: known at the end of the season')
                  : Tr.pick('$name: 第${st[0]}季は${st[1]}部の${st[2]}位',
                      '$name: season ${st[0]}, Tier ${st[1]}, finished ${Tr.ordinal(st[2])}')),
          ],
        ),
      ),
    );
  }
}
