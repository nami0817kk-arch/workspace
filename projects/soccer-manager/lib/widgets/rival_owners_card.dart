import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../state/game_state.dart';
import '../theme/semantic_colors.dart';
import 'help_button.dart';

/// 同じリーグで競う他のオーナー。
class RivalOwnersCard extends StatelessWidget {
  const RivalOwnersCard({super.key});

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final rivals = gs.rivalOwners;
    if (rivals.isEmpty) return const SizedBox.shrink();
    final small =
        TextStyle(fontSize: 12, color: SemanticColors.subtleText(context));
    // 「***」は星に見えなかったので ★ にする(2026-11-21)。
    String stars(int n) => List.filled(n, '★').join();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TitleWithHelp(
              title: Tr.pick('競い合うオーナー', 'Rival owners'),
              help: Tr.pick(
                  '窓が開くたびに、野心(★の数)だけ自由契約から選手を足します。交渉中の選手を横取りしに来るのも、まずこのオーナーたちです。',
                  'Each window they add as many free agents as their ambition (stars) allows, and they are first in line to gatecrash your negotiations.'),
            ),
            for (final r in rivals)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text.rich(TextSpan(children: [
                  TextSpan(
                      text: '${r.clubName}  ',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  TextSpan(
                      text: Tr.pick('${r.name}・野心 ', '${r.name}, ambition '),
                      style: small),
                  TextSpan(
                      text: stars(r.ambition),
                      style: TextStyle(
                          color: SemanticColors.ink(context, Colors.amber))),
                  TextSpan(
                      text: Tr.pick('・今季の補強 ${r.signingsThisSeason}人',
                          ', signed ${r.signingsThisSeason} this season'),
                      style: small),
                ])),
              ),
          ],
        ),
      ),
    );
  }
}
