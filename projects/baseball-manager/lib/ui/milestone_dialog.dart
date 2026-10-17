import 'package:flutter/material.dart';

import 'controller.dart';

/// 人生の節目を大きく見せるダイアログ。
class MilestoneDialog extends StatelessWidget {
  const MilestoneDialog({super.key, required this.milestone});
  final Milestone milestone;

  (IconData, Color) get _style => switch (milestone.kind) {
        MilestoneKind.draft => (Icons.star, const Color(0xFFFB8C00)),
        MilestoneKind.champion => (Icons.emoji_events, const Color(0xFFFDD835)),
        MilestoneKind.trait => (Icons.auto_awesome, const Color(0xFF7E57C2)),
        MilestoneKind.stage => (Icons.school, const Color(0xFF2E7D32)),
      };

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _style;
    return AlertDialog(
      icon: Icon(icon, size: 56, color: color),
      title: Text(milestone.title, textAlign: TextAlign.center),
      content: Text(milestone.body, textAlign: TextAlign.center),
      actions: [
        FilledButton(
          key: const Key('milestone-ok'),
          onPressed: () => Navigator.pop(context),
          child: const Text('つづける'),
        ),
      ],
      actionsAlignment: MainAxisAlignment.center,
    );
  }
}
