import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/economy_scale.dart';
import '../logic/projection_engine.dart';
import '../state/game_state.dart';
import '../theme/semantic_colors.dart';

/// 5年の収支の見込み(今の収入と人件費が続いた場合)。
class ProjectionCard extends StatelessWidget {
  const ProjectionCard({super.key});

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final rows = gs.fiveYearProjection;
    if (rows.isEmpty) return const SizedBox.shrink();
    final firstRed = rows.where((r) => r.budget < 0).firstOrNull;
    final style = const TextStyle(fontSize: 12);
    final head = TextStyle(
        fontSize: 11, color: SemanticColors.subtleText(context));
    TableRow row(List<String> cells, {TextStyle? s, Color? last}) => TableRow(
          children: [
            for (var i = 0; i < cells.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                child: Text(cells[i],
                    textAlign: i == 0 ? TextAlign.left : TextAlign.right,
                    style: i == cells.length - 1 && last != null
                        ? (s ?? style).copyWith(color: last)
                        : (s ?? style)),
              ),
          ],
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Tr.pick('5年の収支の見込み', 'Five-year outlook'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              Tr.pick(
                  '今の収入と顔ぶれの年俸が続いた場合の目安です。収入は年${ProjectionEngine.incomeGrowthPercent}%、人件費は年${ProjectionEngine.wageGrowthPercent}%伸びるとしています(順位・昇降格・移籍は入っていません)。',
                  'A rough guide if today\'s income and wage bill carry on. Income grows ${ProjectionEngine.incomeGrowthPercent}% a year and wages ${ProjectionEngine.wageGrowthPercent}% (results, promotion and transfers are not included).'),
              style: head,
            ),
            const SizedBox(height: 8),
            Table(
              columnWidths: const {0: FlexColumnWidth(0.8)},
              children: [
                row([
                  Tr.pick('年', 'Year'),
                  Tr.pick('収入', 'Income'),
                  Tr.pick('人件費', 'Wages'),
                  Tr.pick('その他', 'Other'),
                  Tr.pick('税', 'Tax'),
                  Tr.pick('損益', 'Result'),
                  Tr.pick('資金', 'Funds'),
                ], s: head),
                for (final r in rows)
                  row([
                    Tr.pick('${r.yearAhead}年後', '+${r.yearAhead}'),
                    formatMoney(r.income),
                    formatMoney(r.wages),
                    formatMoney(r.otherCosts),
                    formatMoney(r.tax),
                    formatMoneySigned(r.profit),
                    formatMoney(r.budget),
                  ],
                      last: r.budget < 0
                          ? SemanticColors.negative(context)
                          : null),
              ],
            ),
            if (firstRed != null) ...[
              const SizedBox(height: 6),
              Text(
                Tr.pick('このままだと${firstRed.yearAhead}年後に資金がマイナスになります。',
                    'At this rate your funds go negative in ${firstRed.yearAhead} year(s).'),
                style: TextStyle(
                    fontSize: 12, color: SemanticColors.negative(context)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
