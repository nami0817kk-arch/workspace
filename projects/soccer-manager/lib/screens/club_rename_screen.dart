import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../models/team.dart';
import '../state/game_state.dart';
import '../theme/semantic_colors.dart';

/// クラブ名の書き換え(設定から開く。2026-11-22)。クラブ名は実在の今季の
/// 顔ぶれに寄せた名前で始まる。好きな名前に直せる(ユースのアプリと同じ)。
class ClubRenameScreen extends StatelessWidget {
  const ClubRenameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final groups = gs.renamableClubGroups;
    final userId = gs.save?.userTeamId;
    return Scaffold(
      appBar: AppBar(title: Text(Tr.pick('クラブ名の書き換え', 'Rename clubs'))),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text(
            Tr.pick('クラブを押すと名前を書き換えられます。書き換えた名前はこのセーブに残ります。',
                'Tap a club to rename it. New names are kept in this save.'),
            style: TextStyle(
                fontSize: 12, color: SemanticColors.subtleText(context)),
          ),
          for (final (title, teams) in groups) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 14, 4, 4),
              child: Text(title, style: Theme.of(context).textTheme.titleSmall),
            ),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final t in [
                    ...teams
                  ]..sort((a, b) => a.name.compareTo(b.name)))
                    ListTile(
                      dense: true,
                      title: Text(t.name,
                          style: TextStyle(
                              fontWeight:
                                  t.id == userId ? FontWeight.bold : null)),
                      trailing: const Icon(Icons.edit_outlined, size: 18),
                      onTap: () => _rename(context, t),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _rename(BuildContext context, Team team) async {
    final controller = TextEditingController(text: team.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(Tr.pick('クラブ名', 'Club name')),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          decoration: InputDecoration(hintText: Tr.pick('新しい名前', 'New name')),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(Tr.pick('やめる', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: Text(Tr.pick('決める', 'Save')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || !context.mounted) return;
    await context.read<GameState>().renameClub(team.id, name);
  }
}
