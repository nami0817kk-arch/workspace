import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/club_license.dart';
import '../state/game_state.dart';

/// 1つ上の部のクラブライセンスを満たしているか。満たさないと昇格できない。
class ClubLicenseCard extends StatelessWidget {
  const ClubLicenseCard({super.key});

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final up = gs.nextTierUp;
    if (gs.save == null || up == null) return const SizedBox.shrink();
    final unmet = gs.clubLicenseUnmet(up);
    final need = ClubLicenseEngine.stadiumLevelFor(up);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Tr.pick('クラブライセンス($up部)', 'Club licence (tier $up)'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
                Tr.pick(
                    '$up部に上がるには、スタジアム$need段階以上${ClubLicenseEngine.needsSolvency(up) ? 'と、季の終わりに資金がマイナスでないこと' : ''}が要ります。満たさないと、昇格を決めても権利は次の順位のクラブに移ります。',
                    'To go up to tier $up you need a level $need stadium${ClubLicenseEngine.needsSolvency(up) ? ' and funds out of the red at the end of the season' : ''}. Without it, the promotion place passes to the next club.'),
                style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 6),
            if (unmet.isEmpty)
              Text(Tr.pick('今の状態なら、ライセンスは下ります',
                  'As things stand, the licence would be granted'))
            else ...[
              Text(Tr.pick('今の状態では下りません:', 'As things stand, it would be refused:'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
              for (final u in unmet) Text(Tr.pick('・$u', '- $u')),
            ],
          ],
        ),
      ),
    );
  }
}
