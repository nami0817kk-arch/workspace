import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/contract_engine.dart';
import '../logic/proposal_engine.dart';
import '../state/game_state.dart';

String _contractNote(GameState gs, ManagerProposal p) {
  if (p.kind != ProposalKind.renew) return '';
  final player =
      gs.userTeam.players.where((x) => x.id == p.playerId).firstOrNull;
  if (player == null) return '';
  return Tr.pick('(${ContractEngine.contractLabel(player)})',
      ' (${ContractEngine.contractLabel(player)})');
}

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
            // 移籍の「監督の補強案」(買う候補)と紛れないよう、中身を名前に入れる。
            Text(
                Tr.pick('監督からの提案(契約更新・ユース昇格)',
                    'Manager\'s proposals (renewals & promotions)'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            for (final p in list)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      // 契約更新は、「選手 > 登録と契約」と同じ契約の書き方を
                      // 添える(同じ選手が両方に出るので、表示を揃える)。
                      child: Text(
                          '${p.kind.label}: ${p.playerName}${_contractNote(gs, p)}'),
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
