import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../models/owner_event.dart';
import '../state/game_state.dart';
import '../logic/economy_scale.dart';
import 'decision_card.dart';

/// オーナーの判断を迫る事件のカード。答えを選ぶまで残る。
///
/// 題と答えのボタンだけを出し、説明と答えごとの効き目は押すと開く
/// (2026-11-25。[DecisionCard])。
class OwnerEventCard extends StatelessWidget {
  const OwnerEventCard({super.key});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final kind = gameState.pendingOwnerEvent;
    if (kind == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final options = kind.options;

    String signed(int v) => v > 0 ? '+$v' : '$v';

    return DecisionCard(
      icon: Icons.warning_amber_rounded,
      title: kind.title,
      detail: kind.body,
      color: scheme.errorContainer,
      onColor: scheme.onErrorContainer,
      choices: [
        for (var i = 0; i < options.length; i++)
          DecisionChoice(
            options[i].label,
            () => context.read<GameState>().resolveOwnerEvent(i),
            effect: [
              // 答えが実際に起こすこと(エースの売却など)。
              if (gameState.ownerEventOptionEffect(kind, i) case final effect?)
                effect,
              if (options[i].fundsDelta != 0)
                Tr.pick(
                    '資金${formatMoneySigned(gameState.scaledMoney(options[i].fundsDelta))}',
                    'Funds ${formatMoneySigned(gameState.scaledMoney(options[i].fundsDelta))}'),
              Tr.pick(
                  'サポーター${signed(options[i].supportersDelta)} / 株主${signed(options[i].shareholdersDelta)}',
                  'Supporters ${signed(options[i].supportersDelta)} / Shareholders ${signed(options[i].shareholdersDelta)}'),
            ].join(' / '),
          ),
      ],
    );
  }
}
