import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/club_comparison.dart';
import '../logic/economy_scale.dart';
import '../state/game_state.dart';

/// 同じリーグのクラブと比べる(選手の価値・年俸の総額・チームの力)。
class ClubComparisonCard extends StatelessWidget {
  const ClubComparisonCard({super.key});

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final save = gs.save;
    if (save == null) return const SizedBox.shrink();
    final teams = save.league.teams;
    final userId = save.userTeamId;
    final rows = [
      (
        Tr.pick('選手の価値の合計', 'Squad value'),
        ClubComparisonEngine.squadValue(teams, userId),
        true,
      ),
      (
        Tr.pick('年俸の総額', 'Wage bill'),
        ClubComparisonEngine.wageBill(teams, userId),
        true,
      ),
      (
        Tr.pick('チームの力', 'Team strength'),
        ClubComparisonEngine.strength(teams, userId),
        false,
      ),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Tr.pick('リーグの他クラブと比べる', 'Compared with the league'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final (label, r, money) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(child: Text(label)),
                    Text(Tr.pick(
                        '${money ? formatMoney(r.mine) : r.mine}(${r.clubs}クラブ中${r.rank}位・真ん中${money ? formatMoney(r.median) : r.median})',
                        '${money ? formatMoney(r.mine) : r.mine} (#${r.rank} of ${r.clubs}, median ${money ? formatMoney(r.median) : r.median})')),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
