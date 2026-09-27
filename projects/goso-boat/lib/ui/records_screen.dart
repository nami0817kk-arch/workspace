import 'package:flutter/material.dart';

import '../app/achievements.dart';
import '../app/progress.dart';
import '../l10n/l10n_ext.dart';
import 'palette.dart';

/// 記録（回数）と実績。
class RecordsScreen extends StatelessWidget {
  const RecordsScreen({super.key, required this.progress});
  final Progress progress;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final rows = [
      (t.statClears, '${progress.clearedCount} / ${progress.levels.length}'),
      (t.statStars, '${progress.totalStars} / ${progress.maxStars}'),
      (t.statThree, '${progress.threeStarCount}'),
      (t.statEscapes, '${progress.stat('escapes')}'),
      (t.statTrips, '${progress.stat('trips')}'),
      (t.statStreak, '${progress.stat('maxStreak')}'),
    ];
    return Scaffold(
      backgroundColor: Palette.sky,
      appBar: AppBar(
        backgroundColor: Palette.sky,
        foregroundColor: Palette.ink,
        elevation: 0,
        title: Text(t.records, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _Box(children: [
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(children: [
                  Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, color: Palette.dim))),
                  Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Palette.ink, fontFeatures: [FontFeature.tabularFigures()])),
                ]),
              ),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
            child: Text(
              '${t.achievementsTitle}  ${Achievement.values.where((a) => progress.hasAchievement(a.name)).length} / ${Achievement.values.length}',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Palette.ink),
            ),
          ),
          _Box(children: [
            for (final a in Achievement.values)
              ListTile(
                leading: Icon(
                  progress.hasAchievement(a.name) ? Icons.emoji_events_rounded : Icons.lock_outline_rounded,
                  color: progress.hasAchievement(a.name) ? Palette.goldDeep : Palette.dim,
                ),
                title: Text(t.achName(a), style: TextStyle(fontWeight: FontWeight.w900, color: progress.hasAchievement(a.name) ? Palette.ink : Palette.dim)),
                subtitle: Text(t.achDesc(a)),
              ),
          ]),
        ],
      ),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: Palette.card,
          border: Border.all(color: Palette.ink, width: 2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(children: children),
      );
}
