import 'package:flutter/material.dart';

import '../game/legacy.dart';
import 'controller.dart';

/// 殿堂(過去の選手)と実績の一覧。
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, required this.controller});
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Scaffold(
      appBar: AppBar(title: const Text('殿堂・実績')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('実績 ${c.unlocked.length}/${achievements.length}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        for (final a in achievements)
                          _AchievementRow(
                              achievement: a, got: c.unlocked.contains(a.id)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('育てた選手',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        if (c.history.isEmpty) const Text('まだいない。'),
                        for (final h in c.history) _HistoryRow(entry: h),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AchievementRow extends StatelessWidget {
  const _AchievementRow({required this.achievement, required this.got});
  final Achievement achievement;
  final bool got;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(got ? Icons.emoji_events : Icons.lock_outline,
              color: got ? cs.primary : cs.outline),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(got ? achievement.title : '???',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: got ? null : cs.outline)),
                Text(achievement.description,
                    style: TextStyle(fontSize: 12, color: cs.outline)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry});
  final HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final tags = [
      if (e.pro) 'プロ',
      if (e.abroad) '海外',
      if (e.titles > 0) '優勝${e.titles}回',
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (e.title.isNotEmpty)
            Text(e.title, style: const TextStyle(fontSize: 12)),
          Text('${e.name}  ${e.age}歳  ${e.position}  '
              '${e.heightCm.toStringAsFixed(1)}cm  総合${e.overall}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          Text('${e.reason}${tags.isEmpty ? '' : '  ${tags.join('・')}'}'
              '  平均${e.careerPpg.toStringAsFixed(1)}点'),
          if (e.rivalName.isNotEmpty && e.rivalWins + e.rivalLosses > 0)
            Text('宿敵 ${e.rivalName} ${e.rivalWins}勝${e.rivalLosses}敗'),
        ],
      ),
    );
  }
}
