import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/advisor_engine.dart';
import '../state/game_state.dart';

/// 経営アドバイザー。レベルを上げるほど効果が大きく、毎季の報酬も増える。
class AdvisorCard extends StatelessWidget {
  const AdvisorCard({super.key});

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final save = gs.save;
    if (save == null) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Tr.pick('経営アドバイザー', 'Advisors'),
                style: Theme.of(context).textTheme.titleMedium),
            Text(
              Tr.pick('毎季の報酬の合計 ${AdvisorEngine.totalSalary(save.advisors)}万円',
                  'Total fees per season ${AdvisorEngine.totalSalary(save.advisors)}'),
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 4),
            for (final a in Advisor.values)
              _row(gs, a, save.advisors[a.name] ?? 0),
          ],
        ),
      ),
    );
  }

  Widget _row(GameState gs, Advisor a, int level) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${a.label} Lv$level',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    level == 0
                        ? Tr.pick('未契約', 'Not hired')
                        : '${a.effect(level)}(${Tr.pick('${AdvisorEngine.salary(level)}万円/季', '${AdvisorEngine.salary(level)}/season')})',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed:
                  level > 0 ? () => gs.setAdvisorLevel(a, level - 1) : null,
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: level < AdvisorEngine.maxLevel
                  ? () => gs.setAdvisorLevel(a, level + 1)
                  : null,
            ),
          ],
        ),
      );
}
