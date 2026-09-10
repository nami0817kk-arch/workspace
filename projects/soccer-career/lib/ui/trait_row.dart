import 'package:flutter/material.dart';

import '../models/traits.dart';

/// 特性1つを、名前・説明・効き方の札で見せる。
///
/// 選手タブと選手作成画面の両方から使う。**効き方の文は `Trait.effects`
/// から作る**ので、数字を変えれば両方の画面が同時に変わる
/// （画面ごとに書き写すと、片方が黙って古くなる）。
class TraitRow extends StatelessWidget {
  const TraitRow({super.key, required this.trait, this.hits});

  final Trait trait;

  /// 今季、局面の成功率を動かした回数。まだ始めていなければ null。
  final int? hits;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final accent =
        trait.flaw ? theme.colorScheme.error : theme.colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(trait.label,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 8),
            if (trait.flaw)
              Text('欠点',
                  style: theme.textTheme.labelSmall?.copyWith(color: accent)),
            if (trait.rare) ...[
              if (trait.flaw) const SizedBox(width: 6),
              Text('稀',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.tertiary)),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(trait.description, style: muted),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final effect in trait.effects)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(effect,
                    style: theme.textTheme.labelSmall?.copyWith(color: accent)),
              ),
          ],
        ),
        if (hits != null) ...[
          const SizedBox(height: 4),
          Text(
            trait.affectsPlay
                ? (hits! > 0
                    ? '今季 $hits回の局面で効いた'
                    : '今季はまだ効く局面が来ていない')
                : '試合の外で効く（回数は数えない）',
            style: muted,
          ),
        ],
      ],
    );
  }
}
