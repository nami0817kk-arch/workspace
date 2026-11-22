import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/contract_style.dart';
import '../logic/economy_scale.dart';
import '../models/player.dart';
import '../state/game_state.dart';

/// 契約の中身(出来高・段階昇給)。固定の契約を組み替えられる。
class ContractStyleCard extends StatelessWidget {
  final Player player;

  const ContractStyleCard({super.key, required this.player});

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final current = gs.contractStyleOf(player);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                Tr.pick('契約の中身: ${current.label}',
                    'Contract type: ${current.label}'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            if (player.goalBonus > 0)
              Text(Tr.pick('出来高: 1点ごとに${formatMoney(player.goalBonus)}',
                  'Goal bonus: ${formatMoney(player.goalBonus)} per goal')),
            if (player.raisePct > 0)
              Text(Tr.pick('段階昇給: 季が変わるたびに年俸+${player.raisePct}%',
                  'Stepped rises: salary +${player.raisePct}% every season')),
            if (gs.canChangeContractStyle(player)) ...[
              const SizedBox(height: 6),
              for (final s in [ContractStyle.goalBonus, ContractStyle.stepped])
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Expanded(
                          child: Text(s.summary,
                              style: const TextStyle(fontSize: 12))),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () => gs.changeContractStyle(player.id, s),
                        child: Text(Tr.pick('${s.label}にする', 'Use ${s.label}')),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
