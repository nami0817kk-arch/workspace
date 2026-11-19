import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/economy_scale.dart';
import '../logic/injury_care.dart';
import '../state/game_state.dart';

/// 大きな怪我をした選手の、手術か保存療法かの判断。
class SurgeryDecisionCard extends StatelessWidget {
  const SurgeryDecisionCard({super.key});

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final players = gs.playersAwaitingSurgeryDecision;
    if (players.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Tr.pick('手術か、保存療法か', 'Surgery or rest?'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              Tr.pick(
                  '手術は${formatMoney(gs.surgeryCost)}かかり、離脱が${InjuryCare.surgeryExtraWeeks}週延びますが、再発しません。保存療法は離脱が${InjuryCare.restSavedWeeks}週縮みますが、治ったときに${(InjuryCare.setbackChance * 100).round()}%で再発し、${InjuryCare.setbackWeeks}週休みます。',
                  'Surgery costs ${formatMoney(gs.surgeryCost)} and adds ${InjuryCare.surgeryExtraWeeks} weeks, but there is no setback. Rest saves ${InjuryCare.restSavedWeeks} weeks, but there is a ${(InjuryCare.setbackChance * 100).round()}% chance of a ${InjuryCare.setbackWeeks}-week setback.'),
              style: const TextStyle(fontSize: 12),
            ),
            for (final p in players) ...[
              const SizedBox(height: 8),
              Text(Tr.pick('${p.name}: ${InjuryCare.describe(p)}(あと${p.injuryWeeks}週)',
                  '${p.name}: ${InjuryCare.describe(p)} (${p.injuryWeeks} weeks)')),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton(
                    onPressed: () => gs.decideSurgery(p.id, surgery: true),
                    child: Text(Tr.pick('手術する', 'Operate')),
                  ),
                  OutlinedButton(
                    onPressed: () => gs.decideSurgery(p.id, surgery: false),
                    child: Text(Tr.pick('保存療法', 'Rest it')),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
