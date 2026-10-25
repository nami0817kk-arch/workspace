import 'package:flutter/material.dart';

import '../game/build.dart';
import 'controller.dart';

/// 目指すプレースタイル(ビルド)の選択。おまかせ＋7つの型を並べ、選んだ型の説明を出す。
/// はじめの画面と、育成中の「型を選ぶ」ダイアログの両方で使う。
class StyleSelector extends StatelessWidget {
  const StyleSelector({super.key, required this.value, required this.onChanged});

  /// いま選んでいる型。null はおまかせ。
  final Build? value;
  final ValueChanged<Build?> onChanged;

  /// 選んだ型の説明(伸びる能力と、身長の条件)。
  static String describe(Build? b) {
    if (b == null) {
      return '能力のつき方から、型が自然に決まる。';
    }
    final keys = styleKeys(b);
    final grow = b == Build.allRound
        ? '全体が少し伸びやすい。'
        : '${keys.map((a) => a.label).join('・')}が伸びやすい。';
    final tall = b.minHeight > 0 ? '(身長${b.minHeight.round()}cm以上で名乗れる)' : '';
    return '${b.description}$grow$tall';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            ChoiceChip(
              label: const Text('おまかせ'),
              selected: value == null,
              onSelected: (_) => onChanged(null),
            ),
            for (final b in Build.values)
              ChoiceChip(
                label: Text(b.label),
                selected: value == b,
                onSelected: (_) => onChanged(b),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(describe(value), style: const TextStyle(fontSize: 12)),
        ),
      ],
    );
  }
}

/// 育成中にプレースタイルを選び直すダイアログ。決めると、その型に効く能力が伸びやすくなる。
Future<void> showStylePicker(BuildContext context, GameController c) async {
  final g = c.game;
  if (g == null) return;
  var picked = g.player.style;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('どんな選手を目指す?'),
        content: SingleChildScrollView(
          child: StyleSelector(
            value: picked,
            onChanged: (b) => setState(() => picked = b),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('やめる')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('これで行く')),
        ],
      ),
    ),
  );
  if (ok == true && picked != g.player.style) c.setStyle(picked);
}
