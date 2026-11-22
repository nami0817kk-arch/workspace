import 'package:flutter/material.dart';

import '../game/world.dart';
import '../l10n/lang.dart';
import '../models/acquaintance.dart';
import '../models/career.dart';

/// 関わった人の、いま（2026-11-22）。記録タブに置く。
///
/// 見出しは毎季2〜3本しか書かないので、**全員の今はここで見る**。
/// 競った相手が上のクラブで主力になっていたり、早くに消えていたりする。
class AcquaintanceCard extends StatelessWidget {
  const AcquaintanceCard({super.key, required this.state});

  final CareerState state;

  /// 一度に並べる人数。多すぎると記録タブが知り合いで埋まる。
  static const int shown = 12;

  @override
  Widget build(BuildContext context) {
    final people = state.acquaintances;
    if (people.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    // 現役を先に、総合力の高い順。引退した人は後ろにまとめる。
    final active = [
      for (final a in people)
        if (!a.retired) a,
    ]..sort((a, b) => b.overall.compareTo(a.overall));
    final retired = [
      for (final a in people)
        if (a.retired) a,
    ]..sort((a, b) => (b.retiredYear ?? 0).compareTo(a.retiredYear ?? 0));
    final rows = [...active, ...retired].take(shown).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('関わった人のいま', 'People you crossed paths with'),
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 2),
            Text(
              tr(
                '${people.length}人。競争相手・相方・得点王を争った相手の続き。',
                '${plural(people.length, 'person', 'people')}. Rivals, partners and scoring rivals, and where they went.',
              ),
              style: muted,
            ),
            const SizedBox(height: 10),
            for (final a in rows) ...[
              _Row(
                person: a,
                year: state.year,
                together: !a.retired && a.clubId == state.club.id,
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.person,
    required this.year,
    required this.together,
  });

  final Acquaintance person;
  final int year;

  /// 今も同じクラブに居るか。居れば「元」を付けない。
  final bool together;

  static final RegExp _id = RegExp(r'^(.+)-t(\d+)-c(\d+)$');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = person;
    final club = World.clubNameFor(a.clubId) ?? '';
    final m = _id.firstMatch(a.clubId);
    final where = m == null
        ? club
        : tr(
            '$club（${World.byId(m.group(1)!).name}・${m.group(2)}部）',
            '$club (${World.byId(m.group(1)!).name}, tier ${m.group(2)})',
          );
    final now = a.retired
        ? tr('${a.retiredYear}年に引退 ・ 最後は$club', 'Retired in ${a.retiredYear} - last at $club')
        : tr(
            '$where ・ ${a.ageIn(year)}歳',
            '$where - aged ${a.ageIn(year)}',
          );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                a.name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                tr(
                  '${a.bond.labelFor(together: together)} ・ ${a.position.label} ・ $now',
                  '${a.bond.labelFor(together: together)} - ${a.position.label} - $now',
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          a.retired ? '—' : '${a.overall}',
          style: theme.textTheme.titleMedium?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
            color: a.retired ? theme.colorScheme.onSurfaceVariant : null,
          ),
        ),
      ],
    );
  }
}
