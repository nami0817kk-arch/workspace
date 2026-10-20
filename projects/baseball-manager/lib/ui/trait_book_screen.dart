import 'package:flutter/material.dart';

import '../game/traits.dart';
import 'controller.dart';
import 'labels.dart';

/// 特性図鑑。これまでに持った特性が説明つきで載る。まだのものは「???」のまま。
/// 全部そろえるのがやり込みの目標(レア特性は生まれつき4%か、タイトル・優勝の節目の覚醒だけ)。
class TraitBookScreen extends StatelessWidget {
  const TraitBookScreen({super.key, required this.controller});
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final seen = controller.seenTraits;
        final all = Trait.values;
        final n = all.where((t) => seen.contains(t.name)).length;
        final groups = <(String, List<Trait>)>[
          ('レア特性', [for (final t in all) if (t.rare) t]),
          ('良い特性', [for (final t in all) if (!t.rare && t.positive) t]),
          ('代償のある特性', [for (final t in all) if (!t.rare && !t.positive) t]),
        ];
        return Scaffold(
          appBar: AppBar(title: const Text('特性図鑑')),
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
                            Text('発見した特性 $n / ${all.length}',
                                key: const Key('trait-book-count'),
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: n / all.length,
                              minHeight: 10,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                                '一度でも持った特性が載ります。レア特性は、生まれつき4%、'
                                'またはプロでタイトルや優勝をしたときの「覚醒」でだけ手に入ります。'),
                          ]),
                    ),
                  ),
                  for (final g in groups) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
                      child: Text(
                          '${g.$1} (${g.$2.where((t) => seen.contains(t.name)).length} / ${g.$2.length})',
                          style: Theme.of(context).textTheme.titleSmall),
                    ),
                    for (final t in g.$2) _Entry(trait: t, found: seen.contains(t.name)),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry({required this.trait, required this.found});
  final Trait trait;
  final bool found;

  @override
  Widget build(BuildContext context) {
    final role = switch (trait.forRole) {
      TraitFor.batter => '打者',
      TraitFor.pitcher => '投手',
      TraitFor.any => '',
    };
    return Card(
      key: Key('book-${trait.name}'),
      color: found ? traitChipColor(trait) : null,
      child: ListTile(
        dense: true,
        leading: Icon(
          found
              ? (trait.rare ? Icons.stars : Icons.auto_awesome)
              : Icons.help_outline,
          color: found ? traitIconColor(trait) : Colors.grey,
        ),
        title: Text(found ? trait.label : '???',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: found ? const Color(0xFF263238) : Colors.grey)),
        subtitle: Text(
            found
                ? '${role.isEmpty ? '' : '[$role向け] '}${trait.description}'
                : (trait.rare ? 'レア特性。まだ出会っていない。' : 'まだ持ったことがない。'),
            style: TextStyle(
                color: found ? const Color(0xFF37474F) : Colors.grey)),
      ),
    );
  }
}
