import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/season_review_engine.dart';
import '../services/feedback_service.dart';
import '../state/game_state.dart';
import '../theme/semantic_colors.dart';
import '../l10n/tr.dart';

/// シーズンが終わった直後に、その1年を振り返るカード。
///
/// 成績はシーズン成績の画面に積まれていくが、終わった瞬間に「今年はどうだった
/// か」を突きつける場所が無かった。次の年が始まると順位表は白紙に戻り、前の年の
/// 手応えはどこにも残らない。閉じると、そのシーズンについては二度と出さない。
class SeasonReviewCard extends StatelessWidget {
  const SeasonReviewCard({super.key});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final save = gameState.save;
    if (save == null || save.seasonHistory.isEmpty) {
      return const SizedBox.shrink();
    }
    // 見せ終えたシーズンより新しい記録があるときだけ出す。
    final latest = save.seasonHistory.last.season;
    if (save.lastReviewedSeason >= latest) return const SizedBox.shrink();

    final review = SeasonReviewEngine.buildFor(save);
    if (review == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    review.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (review.headline != null)
                  Chip(
                    label: Text(review.headline!,
                        style: const TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            for (final line in review.lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Text(line),
              ),
            const SizedBox(height: 8),
            Text(
              review.verdict,
              style: TextStyle(
                fontSize: 13,
                color: SemanticColors.subtleText(context),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  FeedbackService.tap();
                  context.read<GameState>().markSeasonReviewSeen();
                },
                child: Text(Tr.pick('閉じる', 'Close')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
