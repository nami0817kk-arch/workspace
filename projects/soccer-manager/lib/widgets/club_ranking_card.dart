import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/club_ranking_engine.dart';
import '../state/game_state.dart';

/// 世界クラブ価値番付。上位と、自クラブの位置。
class ClubRankingCard extends StatelessWidget {
  const ClubRankingCard({super.key});

  static const int _shown = 8;

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    if (gs.save == null) return const SizedBox.shrink();
    final ranked = gs.worldClubRanking;
    final mine = ClubRankingEngine.userRank(ranked);
    final top = ranked.take(_shown).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Tr.pick('世界クラブ価値番付', 'World club value ranking'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              Tr.pick('全${ranked.length}クラブのうち、あなたのクラブは$mine位です。他クラブの価値は見積もりです。',
                  'Your club is $mine of ${ranked.length}. Other clubs are estimates.'),
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < top.length; i++)
              _row(context, i + 1, top[i]),
            if (mine > _shown) ...[
              const Divider(height: 12),
              _row(context, mine, ranked[mine - 1]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, int rank, RankedClub c) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(
          children: [
            SizedBox(width: 32, child: Text('$rank')),
            Expanded(
              child: Text(
                c.name,
                style: TextStyle(
                    fontWeight: c.isUser ? FontWeight.bold : null),
              ),
            ),
            Text(Tr.pick('${c.value}万円', '${c.value}')),
          ],
        ),
      );
}
