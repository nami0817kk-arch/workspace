import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/calendar_engine.dart';
import '../screens/owner_work_screen.dart';
import '../services/feedback_service.dart';
import '../state/game_state.dart';
import '../theme/semantic_colors.dart';
import 'fm_panel.dart';

String _signed(int v) => v > 0 ? '+$v' : '$v';

/// サポーターの期待の、前の月の内訳(「2月の期待 +4(広報 +3、結果 -2)」)。
///
/// 増減を1か所に集めたので(2026-11-23)、何でいくつ動いたのかを月ごとに
/// 見せる。オーナーの手(広報・チケット・地域)がどれだけ効いたかが分かる。
class SupporterMonthCard extends StatelessWidget {
  const SupporterMonthCard({super.key});

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final save = gs.save;
    if (save == null || save.supporterLastMonthKey == 0) {
      return const SizedBox.shrink();
    }
    final month = GameStateSupporters.monthLabel(save.supporterLastMonthKey);
    final total = gs.lastMonthSupporterTotal;
    final parts = gs.lastMonthSupporterParts;
    final soFar = gs.thisMonthSupporterTotal;
    Color colorOf(int v) => v > 0
        ? SemanticColors.positive(context)
        : v < 0
            ? SemanticColors.negative(context)
            : SemanticColors.neutral(context);
    return FmPanel(
      key: const ValueKey('supporter-month-card'),
      title: Tr.pick('$monthのサポーターの期待', 'Supporter expectation in $month'),
      trailing: Text(
        _signed(total),
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: colorOf(total),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (parts.isEmpty)
            Text(
              Tr.pick('動きはありませんでした。', 'No change.'),
              style: const TextStyle(fontSize: 12),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final (reason, v) in parts)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: colorOf(v).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${reason.label} ${_signed(v)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: colorOf(v),
                      ),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 4),
          Text(
            Tr.pick(
              'いま${save.confidence}・今月これまで ${_signed(soFar)}',
              'Now ${save.confidence}, this month so far ${_signed(soFar)}',
            ),
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// サポーターの最後通告。期待が10を割ると出る、いちばん目立つ札。
/// 残りの日数・期限・月ごとの推移と、打てる手への行き先を出す。
class SupporterUltimatumCard extends StatelessWidget {
  const SupporterUltimatumCard({super.key});

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final save = gs.save;
    final days = gs.supporterUltimatumDaysLeft;
    final until = save?.supporterUltimatumUntil;
    if (save == null || days == null || until == null) {
      return const SizedBox.shrink();
    }
    final line = GameStateSupporters.ultimatumLine;
    final bad = SemanticColors.negative(context);
    final trail = gs.supporterMonthTrailLine;
    final last = gs.lastMonthSupporterLine;
    return Card(
      key: const ValueKey('supporter-ultimatum-card'),
      color: Color.alphaBlend(
        bad.withValues(alpha: 0.12),
        Theme.of(context).colorScheme.surface,
      ),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: bad, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.campaign, color: bad),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    Tr.pick(
                        'サポーターからの最後通告', 'Final warning from the supporters'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: bad,
                    ),
                  ),
                ),
                Text(
                  Tr.pick('残り$days日', '${Tr.plural(days, 'day')} left'),
                  key: const ValueKey('ultimatum-days-left'),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: bad,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              Tr.pick(
                'サポーターの期待が$lineを割りました(いま${save.confidence})。${CalendarEngine.formatDate(until)}までに$line以上へ戻せなければ、クラブを手放すことになります。',
                'Supporter expectation has fallen below $line (now ${save.confidence}). Get it back to $line or more by ${CalendarEngine.formatDate(until)}, or you will have to sell the club.',
              ),
            ),
            if (trail != null) ...[
              const SizedBox(height: 4),
              Text(
                trail,
                key: const ValueKey('ultimatum-trail'),
                style: const TextStyle(fontSize: 12),
              ),
            ],
            if (last != null) Text(last, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            Text(
              Tr.pick(
                '打てる手: 広報・ファンの手(月に1回)、チケットを安く、地域活動、主力を売らない。',
                'What you can do: a PR or fan move (once a month), cheaper tickets, community work, and keeping your stars.',
              ),
              style: const TextStyle(fontSize: 12),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: bad),
                onPressed: () {
                  FeedbackService.tap();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const OwnerWorkScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.volunteer_activism, size: 18),
                label: Text(Tr.pick('オーナーの仕事へ', "Open the owner's work")),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
