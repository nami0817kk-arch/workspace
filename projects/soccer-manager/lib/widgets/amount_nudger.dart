import 'package:flutter/material.dart';

import '../l10n/tr.dart';

/// 金額の欄の下に置く、増やす・減らすの札。
///
/// 横画面では文字を打つとキーボードが画面の半分以上を覆い、上の条件が
/// 見えなくなっていた。よく使う動かし方を札にして、キーボードを出さずに
/// 決められるようにする。打ち込むこともできる(欄はそのまま)。
class AmountNudger extends StatelessWidget {
  const AmountNudger({
    super.key,
    required this.controller,
    this.target,
    this.targetLabel,
    this.onChanged,
  });

  final TextEditingController controller;

  /// 「希望どおり」にする額(相手の求める額など)。null なら出さない。
  final int? target;

  /// [target] の札の名前。省くと「希望どおり」。
  final String? targetLabel;

  final ValueChanged<int>? onChanged;

  void _set(int v) {
    final x = v < 0 ? 0 : v;
    controller.text = '$x';
    onChanged?.call(x);
  }

  @override
  Widget build(BuildContext context) {
    int current() => int.tryParse(controller.text) ?? (target ?? 0);
    Widget chip(String label, VoidCallback onTap) =>
        ActionChip(label: Text(label), onPressed: onTap);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          chip('-10%', () => _set((current() * 0.9).round())),
          chip('-5%', () => _set((current() * 0.95).round())),
          chip('+5%', () => _set((current() * 1.05).round())),
          chip('+10%', () => _set((current() * 1.1).round())),
          if (target != null)
            chip(targetLabel ?? Tr.pick('希望どおり', 'What they want'),
                () => _set(target!)),
        ],
      ),
    );
  }
}
