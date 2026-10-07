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

    final scheme = Theme.of(context).colorScheme;
    final accent = action.urgent
        ? SemanticColors.negative(context)
        : scheme.primary;

    void go() {
      FeedbackService.tap();
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => _screenFor(action.target)),
      );
    }

    // **行全体を押せるようにする。** 以前は薄い箱に文とボタンが並ぶだけで、
    // 「次にやること」なのか単なるお知らせなのか見分けが付かなかった。
    // 左に色の柱を立て、右に矢印を置いて、押す物だと分かる形にする。
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Color.alphaBlend(
            accent.withValues(alpha: 0.07), scheme.surfaceContainerHigh),
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: go,
          child: Row(
            children: [
              // 左の柱。急ぎかどうかを色で出す。
              Container(width: 4, height: 62, color: accent),
              const SizedBox(width: 12),
              Icon(
                action.urgent ? Icons.priority_high : Icons.lightbulb_outline,
                size: 20,
                color: accent,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        action.message,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _labelFor(action.target),
                        style: TextStyle(
                          fontSize: 12,
                          color: accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}
