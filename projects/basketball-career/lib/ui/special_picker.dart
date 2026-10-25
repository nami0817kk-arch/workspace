import 'package:flutter/material.dart';

import '../game/special.dart';
import 'controller.dart';

/// 特殊能力の習得画面。ポイントを使って、好きな能力を好きな順で習得する(前提のある能力もある)。
/// 習得済みは色付き、習得できないものは理由(前提・ポイント不足)を出す。
Future<void> showSpecialPicker(BuildContext context, GameController c) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => ListenableBuilder(
      listenable: c,
      builder: (ctx, _) => _SpecialDialog(controller: c),
    ),
  );
}

class _SpecialDialog extends StatelessWidget {
  const _SpecialDialog({required this.controller});
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final g = controller.game;
    if (g == null) return const SizedBox.shrink();
    final have = g.player.specials;
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text('特殊能力 ${have.length}/${Special.values.length}'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                  'ポイント ${g.sp}\n年末にたまる(毎年1・目標達成+1・優勝+1)。好きな能力を選んで習得しよう。',
                  style: const TextStyle(fontSize: 12)),
            ),
            for (final cat in SpecialCategory.values) ...[
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 2),
                child: Text(
                    '${cat.label}  '
                    '(${Special.values.where((s) => s.category == cat && have.contains(s)).length}'
                    '/${Special.values.where((s) => s.category == cat).length})',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: cs.primary)),
              ),
              for (final s in Special.values.where((s) => s.category == cat))
                _Row(
                  special: s,
                  have: have.contains(s),
                  why: whyNot(have, g.sp, s),
                  onLearn: canLearn(have, g.sp, s)
                      ? () => controller.learnSpecial(s)
                      : null,
                  color: cs.primary,
                ),
            ],
          ],
        ),
      ),
      actions: [
        FilledButton(
            onPressed: () => Navigator.of(context).pop(), child: const Text('閉じる')),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.special,
    required this.have,
    required this.why,
    required this.onLearn,
    required this.color,
  });
  final Special special;
  final bool have;
  final String? why;
  final VoidCallback? onLearn;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final active = special.kind == SpecialKind.active;
    return Card(
      color: have ? color.withValues(alpha: 0.12) : null,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${special.label}${active ? '  [発動]' : ''}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(special.description, style: const TextStyle(fontSize: 12)),
                  if (!have)
                    Text('必要ポイント ${special.cost}'
                        '${why == null ? '' : '  ・  $why'}',
                        style: const TextStyle(fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (have)
              Icon(Icons.check_circle, color: color)
            else
              FilledButton.tonal(
                onPressed: onLearn,
                // アプリの標準の幅いっぱいのボタンを、横並びの中では使わない(幅が無限になる)。
                style: FilledButton.styleFrom(minimumSize: const Size(64, 40)),
                child: const Text('習得'),
              ),
          ],
        ),
      ),
    );
  }
}
