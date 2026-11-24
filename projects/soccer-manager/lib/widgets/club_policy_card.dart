import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/policy_engine.dart';
import '../state/game_state.dart';
import 'offseason_lock_note.dart';

/// オーナーが選ぶクラブの方針。オフシーズン(季の終わり〜開幕前)にだけ
/// 変えられる。シーズン中は操作を出さず、今季の方針を1行で見せる。
///
/// 季の終わりに選んだ方針は来季の方針になる(今季の方針は季末に採点される)。
class ClubPolicyCard extends StatelessWidget {
  const ClubPolicyCard({super.key, this.embedded = false});

  /// 別の札の中に入れるとき(オーナー室の「文化と方針」)。枠を描かない。
  final bool embedded;

  Widget _frame(Widget child) => embedded
      ? Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: child)
      : Card(child: Padding(padding: const EdgeInsets.all(16), child: child));

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    if (gameState.save == null) return const SizedBox.shrink();
    final current = gameState.clubPolicy;
    final next = gameState.nextClubPolicy;
    final canChange = gameState.canChangeClubPolicy;
    final title = Text(Tr.pick('クラブの方針', 'Club policy'),
        style: Theme.of(context).textTheme.titleMedium);
    if (!canChange) {
      return _frame(Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          const SizedBox(height: 6),
          OffseasonLockNote(current.label),
        ],
      ));
    }
    final postSeason = !gameState.isPreseason;

    return _frame(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            title,
            const SizedBox(height: 4),
            Text(
              postSeason
                  ? Tr.pick(
                      '来季の方針を選べます(今季の「${current.label}」はこのあと採点されます)。',
                      'Choose next season\'s policy (this season\'s "${current.label}" is scored shortly).')
                  : Tr.pick('オフシーズン(季の終わり〜開幕前)だけ変えられます。シーズン末に採点されます。',
                      'You can change this only in the off-season (end of season to kick-off). It is scored at the end.'),
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final p in ClubPolicy.values)
                  ChoiceChip(
                    label: Text(p.label),
                    selected: p == next,
                    onSelected: p != next
                        ? (_) => context.read<GameState>().setClubPolicy(p)
                        : null,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(next.summary, style: const TextStyle(fontSize: 13)),
          ],
        ),
    );
  }
}
