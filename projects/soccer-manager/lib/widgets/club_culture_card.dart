import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/club_culture.dart';
import '../state/game_state.dart';
import 'help_button.dart';
import 'disabled_reason.dart';
import '../theme/semantic_colors.dart';

/// クラブの文化を選ぶ(1季に1回まで)。
class ClubCultureCard extends StatelessWidget {
  const ClubCultureCard({super.key, this.embedded = false});

  /// 別の札の中に入れるとき(オーナー室の「文化と方針」)。枠を描かない。
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    if (gs.save == null) return const SizedBox.shrink();
    final current = gs.clubCulture;
    final canChange = gs.canChangeClubCulture;
    final small =
        TextStyle(fontSize: 12, color: SemanticColors.subtleText(context));
    final body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TitleWithHelp(
              title: Tr.pick('クラブの文化', 'Club identity'),
              help: Tr.pick(
                  '文化に沿った試合のたびにサポーターの期待+1。変えられるのは1季に1回で、決めたものから変えると期待-${ClubCultureEngine.changePenalty}。',
                  'Each match that fits the identity adds 1 to supporter expectation. You can change it once a season; switching away costs ${ClubCultureEngine.changePenalty}.'),
            ),
            Text(current.description, style: small),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                for (final c in ClubCulture.values)
                  ChoiceChip(
                    label: Text(c.label),
                    selected: c == current,
                    onSelected: canChange && c != current
                        ? (_) => gs.setClubCulture(c)
                        : null,
                  ),
              ],
            ),
            // 変えられるのは1季に1回。今季もう変えたあとは札が全部押せない。
            if (!canChange)
              DisabledReason(
                Tr.pick('今季はもう変えました。次に変えられるのは来季です',
                    'Already changed this season. You can change it again next season'),
                key: const ValueKey('culture-blocked'),
              ),
          ],
        );
    return embedded
        ? Padding(padding: const EdgeInsets.only(bottom: 8), child: body)
        : Card(child: Padding(padding: const EdgeInsets.all(16), child: body));
  }
}
