import 'package:flutter/material.dart';

import '../game/build.dart';
import '../game/collection.dart';
import '../game/honors.dart';
import '../game/legacy.dart';
import '../game/skills.dart';
import '../game/traits.dart';
import 'art/title_art.dart';
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
                const ArtBanner('assets/art/hall.jpg'),
                const SizedBox(height: 12),
                _ZukanCard(collection: c.collection),
                const SizedBox(height: 12),
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
            Text(
                '${e.title}${e.number > 0 ? '  背番号${e.number}${e.retiredNumber ? '(永久欠番)' : ''}' : ''}',
                style: const TextStyle(fontSize: 12)),
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

/// 図鑑: 何人の人生をまたいで集めた個人タイトル・ビルド・特性・得意技。取れていないものも名前を出して、目標にする。
class _ZukanCard extends StatelessWidget {
  const _ZukanCard({required this.collection});
  final Collection collection;

  @override
  Widget build(BuildContext context) {
    final c = collection;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('図鑑 ${c.collected}/${c.total}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 2),
            const Text('引退した選手が集めたものが、ここに残る。',
                style: TextStyle(fontSize: 12)),
            _section('個人タイトル ${c.honors.length}/${Collection.honorTotal}', [
              for (final h in Honor.all)
                _ZukanChip(
                    label: h,
                    got: c.honors.contains(h),
                    tip: Honor.descriptions[h] ?? ''),
            ]),
            _section('ビルド ${c.builds.length}/${Collection.buildTotal}', [
              for (final b in Build.values)
                _ZukanChip(
                    label: c.builds.containsKey(b.name)
                        ? '${b.label}(${tierLabels[c.builds[b.name]!]})'
                        : b.label,
                    got: c.builds.containsKey(b.name),
                    tip: b.description),
            ]),
            _section('特性 ${c.traits.length}/${Collection.traitTotal}', [
              for (final t in Trait.values)
                _ZukanChip(
                    label: t.label, got: c.traits.contains(t.name), tip: t.description),
            ]),
            _section('得意技 ${c.skills.length}/${Collection.skillTotal}', [
              for (final k in Skill.values)
                _ZukanChip(
                    label: k.label, got: c.skills.contains(k.name), tip: k.description),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> chips) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 4, children: chips),
          ],
        ),
      );
}

class _ZukanChip extends StatelessWidget {
  const _ZukanChip({required this.label, required this.got, required this.tip});
  final String label;
  final bool got;
  final String tip;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tip,
        child: Chip(
          avatar: got ? const Icon(Icons.check_circle, size: 16) : null,
          label: Text(label),
          visualDensity: VisualDensity.compact,
          // 明るい地に濃い字(ダークテーマでも読める)。取れていないものは灰色。
          labelStyle: TextStyle(color: got ? Colors.black87 : Colors.black45),
          backgroundColor: got ? Colors.amber.shade200 : Colors.grey.shade300,
        ),
      );
}
