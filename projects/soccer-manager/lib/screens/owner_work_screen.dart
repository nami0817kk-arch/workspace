import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../models/owner_work.dart';
import '../services/feedback_service.dart';
import '../state/game_state.dart';
import '../theme/semantic_colors.dart';
import '../widgets/responsive_body.dart';

/// オーナーの仕事。資金と2つの期待を動かす手を、分野ごとに並べる。
/// どの手も1シーズンに1回。何かを得て何かを払う。
class OwnerWorkScreen extends StatelessWidget {
  const OwnerWorkScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final save = game.save;
    return Scaffold(
      appBar: AppBar(title: Text(Tr.pick('オーナーの仕事', 'Owner\'s work'))),
      body: save == null
          ? const SizedBox.shrink()
          : ResponsiveBody(
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  Text(
                    Tr.pick(
                        '資金 ${save.budget}万円。どの手も1シーズンに1回だけ打てます。',
                        'Funds ${save.budget}. Each move can be made once per season.'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  for (final cat in OwnerWorkCategory.values) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 4),
                      child: Text(cat.label,
                          style: Theme.of(context).textTheme.titleSmall),
                    ),
                    for (final w in ownerWorks.where((w) => w.category == cat))
                      _WorkTile(work: w),
                  ],
                ],
              ),
            ),
    );
  }
}

class _WorkTile extends StatelessWidget {
  const _WorkTile({required this.work});

  final OwnerWork work;

  Widget _chip(BuildContext context, String label, int v) {
    if (v == 0) return const SizedBox.shrink();
    final color = v > 0
        ? SemanticColors.positive(context)
        : SemanticColors.negative(context);
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Text('$label ${v > 0 ? '+' : ''}$v',
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.bold, color: color)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final done = game.ownerWorkDoneThisSeason(work);
    final can = game.canDoOwnerWork(work);
    final funds = work.funds;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(work.title,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(work.description,
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 6),
                  Wrap(
                    children: [
                      _chip(context, Tr.pick('資金', 'Funds'), funds),
                      _chip(context, Tr.pick('サポーター', 'Fans'),
                          work.supporters),
                      _chip(context, Tr.pick('株主', 'Shareholders'),
                          work.shareholders),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: can
                  ? () async {
                      FeedbackService.tap();
                      await context
                          .read<GameState>()
                          .doOwnerWork(work.id);
                    }
                  : null,
              child: Text(done
                  ? Tr.pick('今季済み', 'Done')
                  : Tr.pick('実行', 'Do it')),
            ),
          ],
        ),
      ),
    );
  }
}
