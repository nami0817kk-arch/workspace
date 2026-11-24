import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/economy_scale.dart';
import '../models/community_activity.dart';
import '../state/game_state.dart';
import '../theme/semantic_colors.dart';
import 'disabled_reason.dart';
import 'fm_panel.dart';

/// 地域貢献の活動(2026-11-25 の第6段)。
///
/// 以前は「地域貢献 Lv1〜5」を上げる札だった。地域の取り組みは毎年の
/// 活動なので、季ごとに活動を選ぶ表にした(活動・費用・効き目・選ぶ/
/// やめる)。選んだ活動は次の季も続け、季の切り替えで次の季の費用を払う。
/// 下に前の季の結果を出す。
class CommunityCard extends StatelessWidget {
  const CommunityCard({super.key});

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final save = gs.save;
    if (save == null) return const SizedBox.shrink();
    final subtle = SemanticColors.subtleText(context);
    final scheme = Theme.of(context).colorScheme;
    final head = TextStyle(
        fontSize: 11, fontWeight: FontWeight.bold, color: scheme.onSurfaceVariant);
    final report = save.lastCommunityReport;
    return FmPanel(
      key: const ValueKey('community-activities'),
      title: Tr.pick('地域貢献(今季の活動)', 'Community work this season'),
      trailing: Text(
        Tr.pick('今季 ${formatMoney(save.communitySeasonSpent)}',
            'Spent ${formatMoney(save.communitySeasonSpent)}'),
        style: TextStyle(fontSize: 12, color: subtle),
      ),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
            child: Text(
              Tr.pick(
                  '季ごとに選ぶ活動です。選ぶとその季の費用を払い、次の季も続けます(季の切り替えで費用を払います。資金が足りなければ止まります)。',
                  'Pick the work you do each season. You pay for the season when you start it, and it carries on next season (paid at the changeover; it stops if funds run short).'),
              style: TextStyle(fontSize: 11.5, color: subtle),
            ),
          ),
          Container(
            color: scheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Row(
              children: [
                Expanded(flex: 4, child: Text(Tr.pick('活動', 'Activity'), style: head)),
                SizedBox(
                    width: 72,
                    child: Text(Tr.pick('1季の費用', 'Per season'), style: head)),
                Expanded(flex: 4, child: Text(Tr.pick('効き目', 'Effect'), style: head)),
                const SizedBox(width: 84),
              ],
            ),
          ),
          for (final a in CommunityActivity.values) _ActivityRow(activity: a),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
            child: Text(
              report == null
                  ? Tr.pick('前の季の結果: まだありません', 'Last season: nothing yet')
                  : Tr.pick(
                      '前の季の結果: ${report.activities.isEmpty ? '活動なし' : report.activities.map((a) => a.label).join('・')}。費用${formatMoney(report.spent)}・サポーターの期待+${report.supporterGain}${report.backing > 0 ? '・地元の協賛${formatMoney(report.backing)}' : ''}',
                      'Last season: ${report.activities.isEmpty ? 'no community work' : report.activities.map((a) => a.label).join(', ')}. Cost ${formatMoney(report.spent)}, supporter expectation +${report.supporterGain}${report.backing > 0 ? ', local backing ${formatMoney(report.backing)}' : ''}'),
              key: const ValueKey('community-last-season'),
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.activity});
  final CommunityActivity activity;

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final save = gs.save!;
    final active = gs.isCommunityActive(activity);
    final cost = gs.communityCostOf(activity);
    final canAfford = save.budget >= cost;
    const small = TextStyle(fontSize: 12);
    return Container(
      key: ValueKey('community-${activity.name}'),
      decoration: BoxDecoration(
        color: active
            ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35)
            : null,
        border: Border(
            top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
      ),
      padding: const EdgeInsets.fromLTRB(10, 2, 6, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                flex: 4,
                child: Row(
                  children: [
                    Icon(active ? Icons.check_circle : Icons.circle_outlined,
                        size: 16,
                        color: active
                            ? SemanticColors.positive(context)
                            : SemanticColors.subtleText(context)),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(activity.label,
                          style: small.copyWith(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 72, child: Text(formatMoney(cost), style: small)),
              Expanded(flex: 4, child: Text(activity.effectLabel, style: small)),
              SizedBox(
                width: 84,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: active
                      ? TextButton(
                          key: ValueKey('community-stop-${activity.name}'),
                          onPressed: () => gs.stopCommunityActivity(activity),
                          child: Text(Tr.pick('やめる', 'Stop')))
                      : FilledButton.tonal(
                          key: ValueKey('community-start-${activity.name}'),
                          style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10)),
                          onPressed: canAfford
                              ? () => gs.startCommunityActivity(activity)
                              : null,
                          child: Text(Tr.pick('始める', 'Start'))),
                ),
              ),
            ],
          ),
          if (!active && !canAfford)
            Align(
              alignment: Alignment.centerRight,
              child: DisabledReason(fundsShortReason(cost - save.budget),
                  alignEnd: true),
            ),
        ],
      ),
    );
  }
}
