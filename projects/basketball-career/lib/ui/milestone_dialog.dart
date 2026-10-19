import 'package:flutter/material.dart';

enum MilestoneKind { champion, award, goal, stage, contract, abroad, rank, rival, skill }

/// 人生の節目。ダイアログで大きく見せる。
class Milestone {
  const Milestone(this.kind, this.title, this.body);
  final MilestoneKind kind;
  final String title;
  final String body;
}

IconData _icon(MilestoneKind k) => switch (k) {
      MilestoneKind.champion => Icons.emoji_events,
      MilestoneKind.award => Icons.military_tech,
      MilestoneKind.goal => Icons.flag,
      MilestoneKind.stage => Icons.school,
      MilestoneKind.contract => Icons.handshake,
      MilestoneKind.abroad => Icons.flight_takeoff,
      MilestoneKind.rank => Icons.trending_up,
      MilestoneKind.rival => Icons.local_fire_department,
      MilestoneKind.skill => Icons.auto_awesome,
    };

class MilestoneDialog extends StatelessWidget {
  const MilestoneDialog({super.key, required this.milestone});
  final Milestone milestone;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      icon: Icon(_icon(milestone.kind), size: 48, color: cs.primary),
      title: Text(milestone.title, textAlign: TextAlign.center),
      content: Text(milestone.body, textAlign: TextAlign.center),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('つぎへ'),
        ),
      ],
    );
  }
}
