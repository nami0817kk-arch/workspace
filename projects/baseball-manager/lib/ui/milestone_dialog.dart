import 'package:flutter/material.dart';

import 'art/confetti.dart';
import 'controller.dart';

/// 人生の節目を大きく見せるダイアログ。ドラフトと優勝は紙吹雪つき。
class MilestoneDialog extends StatelessWidget {
  const MilestoneDialog({super.key, required this.milestone});
  final Milestone milestone;

  (IconData, Color) get _style => switch (milestone.kind) {
        MilestoneKind.draft => (Icons.star, const Color(0xFFFB8C00)),
        MilestoneKind.champion => (Icons.emoji_events, const Color(0xFFF9A825)),
        MilestoneKind.trait => (Icons.auto_awesome, const Color(0xFF7E57C2)),
        MilestoneKind.stage => (Icons.school, const Color(0xFF2E7D32)),
        MilestoneKind.title => (
            Icons.workspace_premium,
            const Color(0xFFD4AF37)
          ),
        MilestoneKind.achievement => (
            Icons.military_tech,
            const Color(0xFFE53935)
          ),
      };

  bool get _celebrate =>
      milestone.kind == MilestoneKind.draft ||
      milestone.kind == MilestoneKind.champion ||
      milestone.kind == MilestoneKind.title ||
      milestone.kind == MilestoneKind.achievement;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _style;
    final cs = Theme.of(context).colorScheme;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (_celebrate) const Positioned.fill(child: Confetti()),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.2, end: 1),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.elasticOut,
                  builder: (context, s, child) =>
                      Transform.scale(scale: s, child: child),
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: 0.15),
                      border: Border.all(color: color, width: 3),
                    ),
                    child: Icon(icon, size: 52, color: color),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  milestone.title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(milestone.body,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cs.onSurfaceVariant)),
                const SizedBox(height: 20),
                FilledButton(
                  key: const Key('milestone-ok'),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('つづける'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
