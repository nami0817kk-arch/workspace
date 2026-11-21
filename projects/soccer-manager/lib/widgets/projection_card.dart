import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/economy_scale.dart';
import '../logic/projection_engine.dart';
import '../state/game_state.dart';
import '../theme/semantic_colors.dart';
import 'help_button.dart';

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
    // 数字が欄に収まらず「2,102/万」と2行に割れていたので、1行のまま
    // 縮めて収める(2026-11-21)。
    TableRow row(List<String> cells, {TextStyle? s, Color? last}) => TableRow(
          children: [
            for (var i = 0; i < cells.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 3),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment:
                      i == 0 ? Alignment.centerLeft : Alignment.centerRight,
                  child: Text(cells[i],
                      maxLines: 1,
                      softWrap: false,
                      style: i == cells.length - 1 && last != null
                          ? (s ?? style).copyWith(color: last)
                          : (s ?? style)),
                ),
              ),
          ],
        );
    // 「その他」がどの年も0なら列ごと外す。
    final showOther = rows.any((r) => r.otherCosts != 0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TitleWithHelp(
              title: Tr.pick('5年の収支の見込み', 'Five-year outlook'),
              help: Tr.pick(
                  '今の収入と顔ぶれの年俸が続いた場合の目安です。収入は年${ProjectionEngine.incomeGrowthPercent}%、人件費は年${ProjectionEngine.wageGrowthPercent}%伸びるとしています(順位・昇降格・移籍は入っていません)。',
                  'A rough guide if today\'s income and wage bill carry on. Income grows ${ProjectionEngine.incomeGrowthPercent}% a year and wages ${ProjectionEngine.wageGrowthPercent}% (results, promotion and transfers are not included).'),
            ),
            const SizedBox(height: 4),
            Table(
              columnWidths: const {0: FlexColumnWidth(0.8)},
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                row([
                  Tr.pick('年', 'Year'),
                  Tr.pick('収入', 'Income'),
                  Tr.pick('人件費', 'Wages'),
                  if (showOther) Tr.pick('その他', 'Other'),
                  Tr.pick('税', 'Tax'),
                  Tr.pick('損益', 'Result'),
                  Tr.pick('資金', 'Funds'),
                ], s: head),
                for (final r in rows)
                  row([
                    Tr.pick('${r.yearAhead}年後', '+${r.yearAhead}'),
                    formatMoney(r.income),
                    formatMoney(r.wages),
                    if (showOther) formatMoney(r.otherCosts),
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
