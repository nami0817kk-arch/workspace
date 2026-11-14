import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/proposal_engine.dart';
import '../state/game_state.dart';

/// 監督からの提案(承認待ち)。承認すると実行され、却下するとしばらく出ない。
class ProposalCard extends StatelessWidget {
  const ProposalCard({super.key});

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final list = gs.save?.proposals ?? const <ManagerProposal>[];
    if (list.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Tr.pick('監督からの提案', 'Manager\'s proposals'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            for (final p in list)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('${p.kind.label}: ${p.playerName}'),
                    ),
                    TextButton(
                      onPressed: () => gs.declineProposal(p.id),
                      child: Text(Tr.pick('却下', 'Decline')),
                    ),
                    FilledButton.tonal(
                      onPressed: () => gs.approveProposal(p.id),
                      child: Text(Tr.pick('承認', 'Approve')),
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
