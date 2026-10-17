import 'package:flutter/material.dart';

import '../game/achievements.dart';
import 'controller.dart';

/// 実績の一覧。解除したものは色がつき、未解除は条件を見せたまま灰色。
class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key, required this.controller});
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final done = controller.unlocked;
        final n = achievements.where((a) => done.contains(a.id)).length;
        return Scaffold(
          appBar: AppBar(title: const Text('実績')),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('解除した実績 $n / ${achievements.length}',
                                key: const Key('achievements-count'),
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: n / achievements.length,
                              minHeight: 10,
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ]),
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final a in achievements)
                    _Tile(a: a, unlocked: done.contains(a.id)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.a, required this.unlocked});
  final Achievement a;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Card(
        child: ListTile(
          key: Key('ach-${a.id}'),
          leading: Icon(
            unlocked ? Icons.military_tech : Icons.lock_outline,
            color: unlocked ? const Color(0xFFE53935) : cs.outline,
            size: 32,
          ),
          title: Text(
            a.title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: unlocked ? null : cs.onSurfaceVariant,
            ),
          ),
          subtitle: Text(a.description),
          trailing: unlocked
              ? const Icon(Icons.check_circle, color: Color(0xFF2E9B3E))
              : null,
        ),
      ),
    );
  }
}
