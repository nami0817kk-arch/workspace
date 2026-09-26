import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/next_action_advisor.dart';
import '../screens/finance_screen.dart';
import '../screens/lineup_screen.dart';
import '../screens/squad_screen.dart';
import '../screens/training_screen.dart';
import '../screens/transfer_screen.dart';
import '../screens/youth_screen.dart';
import '../services/feedback_service.dart';
import '../state/game_state.dart';
import '../theme/semantic_colors.dart';
import '../l10n/tr.dart';

/// いま手を付けるべきこと1件を、行き先付きで出す。
///
/// 画面は30以上あり、何から見ればよいのかが分からない。複数を並べると
/// 結局どれからか分からなくなるため、出すのは常に1件だけにしてある。
class NextActionCard extends StatelessWidget {
  const NextActionCard({super.key});

  static Widget _screenFor(NextActionTarget target) => switch (target) {
        NextActionTarget.lineup => const LineupScreen(),
        NextActionTarget.training => const TrainingScreen(),
        NextActionTarget.squad => const SquadScreen(),
        NextActionTarget.youth => const YouthScreen(),
        NextActionTarget.finance => const FinanceScreen(),
        NextActionTarget.transfer => const TransferScreen(),
      };

  static String _labelFor(NextActionTarget target) => switch (target) {
        NextActionTarget.lineup => Tr.pick('スタメンへ', 'Open the XI'),
        NextActionTarget.training => Tr.pick('トレーニングへ', 'Open training'),
        NextActionTarget.squad => Tr.pick('スカッドへ', 'Open the squad'),
        NextActionTarget.youth => Tr.pick('ユースへ', 'Open the academy'),
        NextActionTarget.finance => Tr.pick('財務へ', 'Open finances'),
        NextActionTarget.transfer => Tr.pick('移籍市場へ', 'Open transfers'),
      };

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final save = gameState.save;
    if (save == null) return const SizedBox.shrink();

    final action = NextActionAdvisor.top(
      save,
      gameState.userTeam,
      transferDeadlineMatchdaysLeft: gameState.isTransferWindowOpen
          ? gameState.transferWindowMatchdaysLeft
          : null,
    );
    if (action == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              action.urgent ? Icons.priority_high : Icons.lightbulb_outline,
              size: 20,
              color: action.urgent
                  ? SemanticColors.negative(context)
                  : SemanticColors.neutral(context),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(action.message)),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                FeedbackService.tap();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _screenFor(action.target),
                  ),
                );
              },
              child: Text(_labelFor(action.target)),
            ),
          ],
        ),
      ),
    );
  }
}
