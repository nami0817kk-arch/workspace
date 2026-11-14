import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/project_engine.dart';
import '../state/game_state.dart';

/// 投資案件。着手して、しばらくしてから効果が出る。
class ProjectCard extends StatelessWidget {
  const ProjectCard({super.key});

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
            Text(Tr.pick('投資案件', 'Projects'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final p in ClubProject.values)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.label,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          Text(p.summary, style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _action(gs, save.projects, p),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _action(GameState gs, Map<String, int> projects, ClubProject p) {
    final left = ProjectEngine.seasonsLeft(projects, p);
    if (left == null) {
      return FilledButton.tonal(
        onPressed: () => gs.startProject(p),
        child: Text(Tr.pick('${p.cost}万円で着手(${p.buildSeasons}季)',
            'Start ${p.cost} (${p.buildSeasons} season)')),
      );
    }
    return Text(left == 0
        ? Tr.pick('稼働中', 'Running')
        : Tr.pick('建設中(あと$left季)', 'Building ($left left)'));
  }
}
