import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/project_engine.dart';
import '../state/game_state.dart';
import '../logic/economy_scale.dart';
import '../theme/semantic_colors.dart';
import 'disabled_reason.dart';
import 'help_button.dart';

/// クラブの事業(ファンアプリ・公式ショップ・博物館)。
///
/// 2026-11-25 の第7段で「投資案件」から改めた(利用者「投資案件が投資
/// 案件ではない」)。事業ごとに 始める費用・毎月の収入・元が取れるまで・
/// 状態 を並べる。お金を預けて増やす本当の投資(定期預金)は、同じタブの
/// 「投資」の札にある。
class BusinessCard extends StatelessWidget {
  const BusinessCard({super.key});

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final save = gs.save;
    if (save == null) return const SizedBox.shrink();
    return Card(
      key: const ValueKey('business-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TitleWithHelp(
              title: Tr.pick('事業', 'Businesses'),
              help: Tr.pick(
                  '始める費用を一度払うと、開業(1〜2季の終わり)から毎月の収入が増えます。「元が取れるまで」は、費用を毎月の収入で割った目安です。収入の額は今の部・評判・商業施設で変わります。',
                  'Pay once to start; from opening (after one or two season ends) monthly income rises. "Pays back in" is the cost divided by the monthly income. The income depends on your division, reputation and commercial facilities.'),
            ),
            for (final p in ClubProject.values) _BusinessRow(project: p),
          ],
        ),
      ),
    );
  }
}

class _BusinessRow extends StatelessWidget {
  const _BusinessRow({required this.project});
  final ClubProject project;

  @override
  Widget build(BuildContext context) {
    final gs = context.read<GameState>();
    final save = gs.save!;
    final p = project;
    final subtle = SemanticColors.subtleText(context);
    final cost = gs.businessCost(p);
    final monthly = gs.businessMonthlyIncome(p);
    final payback = ProjectEngine.paybackMonths(cost, monthly);
    final left = ProjectEngine.seasonsLeft(save.projects, p);

    Widget stat(String head, String value, {Color? color}) => Padding(
          padding: const EdgeInsets.only(right: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(head, style: TextStyle(fontSize: 11, color: subtle)),
              Text(value,
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        );

    final status = switch (left) {
      null => Tr.pick('未着手(開業まで${p.buildSeasons}季)',
          'Not started (opens after ${Tr.plural(p.buildSeasons, 'season')})'),
      0 => Tr.pick('営業中', 'Open'),
      _ => Tr.pick('建設中(あと$left季)', 'Building (${Tr.plural(left, 'season')} left)'),
    };
    final short = left == null && cost > save.budget;

    return Padding(
      key: ValueKey('business-${p.name}'),
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(p.label,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              Text(status,
                  key: ValueKey('business-${p.name}-status'),
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: left == 0
                          ? SemanticColors.positive(context)
                          : subtle)),
            ],
          ),
          Text(p.summary, style: TextStyle(fontSize: 12, color: subtle)),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Wrap(
            runSpacing: 2,
            children: [
              stat(Tr.pick('始める費用', 'Cost to start'), formatMoney(cost)),
              stat(
                  Tr.pick('毎月の収入', 'Income a month'),
                  p.earns ? '+${formatMoney(monthly)}' : '—',
                  color: p.earns ? SemanticColors.positive(context) : null),
              stat(
                  Tr.pick('元が取れるまで', 'Pays back in'),
                  payback == null
                      ? '—'
                      : Tr.pick('約$paybackか月',
                          'about ${Tr.plural(payback, 'month')}')),
            ],
                ),
              ),
              if (left == null)
                FilledButton.tonal(
                  key: ValueKey('business-${p.name}-start'),
                  onPressed: short ? null : () => gs.startProject(p),
                  child: Text(Tr.pick('始める', 'Start')),
                ),
            ],
          ),
          if (short)
            Align(
              alignment: Alignment.centerRight,
              child: DisabledReason(
                Tr.pick('資金があと${formatMoney(cost - save.budget)}足りません',
                    'You need ${formatMoney(cost - save.budget)} more'),
                padding: EdgeInsets.zero,
              ),
            ),
        ],
      ),
    );
  }
}
