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
    // スタジアムが足りないまま昇格した季は、その期限を出す(1部でも)。
    final grace = gs.stadiumGraceNote;
    if (gs.save == null || (up == null && grace == null)) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    final graceText = grace == null
        ? null
        : Text(
            grace,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                color: gs.stadiumMeetsLicense(gs.currentDivisionTier)
                    ? null
                    : scheme.error),
          );
    if (up == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(Tr.pick('クラブライセンス', 'Club licence'),
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              graceText!,
            ],
          ),
        ),
      );
    }
    final unmet = gs.clubLicenseUnmet(up);
    final need = ClubLicenseEngine.stadiumLevelFor(up);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (graceText != null) ...[graceText, const SizedBox(height: 6)],
            Text(Tr.pick('クラブライセンス($up部)', 'Club licence (tier $up)'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
                Tr.pick(
                    '$up部に上がるには、スタジアム$need段階以上${ClubLicenseEngine.needsSolvency(up) ? 'と、季の終わりに資金がマイナスでないこと' : ''}が要ります。スタジアムだけが足りないなら1年の猶予つきで上がれますが、その季のうちに届かないと降格になります。ほかの条件を満たさないと、昇格を決めても権利は次の順位のクラブに移ります。',
                    'To go up to tier $up you need a level $need stadium${ClubLicenseEngine.needsSolvency(up) ? ' and funds out of the red at the end of the season' : ''}. If only the stadium falls short you can go up with a year\'s grace, but you are relegated if it is not ready by the end of that season. Miss anything else and the promotion place passes to the next club.'),
                style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 6),
            if (unmet.isEmpty)
              Text(Tr.pick('今の状態なら、ライセンスは下ります',
                  'As things stand, the licence would be granted'))
            else if (gs.clubLicenseUnmetExceptStadium(up).isEmpty)
              Text(
                  Tr.pick('今の状態なら、スタジアムの1年の猶予つきで上がれます: ${unmet.join('、')}',
                      'As things stand, you would go up with a year\'s grace on the stadium: ${unmet.join('; ')}'),
                  style: TextStyle(color: scheme.error))
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
