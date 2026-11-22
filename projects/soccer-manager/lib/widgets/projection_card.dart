import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
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
    // 単位は表に1つだけ出し、欄には数だけを置く(2026-11-23)。以前は欄ごとに
    // 「2,102万」「1.2億」と単位が混ざり、収まらない欄だけ縮めていたので
    // 字の大きさがばらばらだった。数だけなら縮めずに収まる。
    final unit = _ProjectionUnit.of([
      for (final r in rows) ...[r.income, r.wages, r.otherCosts, r.tax, r.profit, r.budget],
    ]);
    TableRow row(List<String> cells, {TextStyle? s, Color? last}) => TableRow(
          children: [
            for (var i = 0; i < cells.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 3),
                child: Text(cells[i],
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    textAlign: i == 0 ? TextAlign.left : TextAlign.right,
                    style: i == cells.length - 1 && last != null
                        ? (s ?? style).copyWith(color: last)
                        : (s ?? style)),
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
            Text(
              Tr.pick('単位: ${unit.label}', 'Figures in ${unit.label}'),
              key: const ValueKey('projection-unit'),
              style: head,
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
                    unit.format(r.income),
                    unit.format(r.wages),
                    if (showOther) unit.format(r.otherCosts),
                    unit.format(r.tax),
                    unit.format(r.profit, signed: true),
                    unit.format(r.budget),
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
                    'At this rate your funds go negative in ${Tr.plural(firstRed.yearAhead, 'year')}.'),
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

/// 表の単位。いちばん大きい額に合わせて1つ選ぶ(万円の値を受け取る)。
class _ProjectionUnit {
  const _ProjectionUnit(this.label, this.divisor, this.decimals);

  final String label;

  /// 万円の値をこの数で割ると、単位あたりの数になる。
  final int divisor;

  /// 小数の桁(0 か 1)。
  final int decimals;

  static _ProjectionUnit of(List<int> values) {
    final top = values.fold<int>(0, (m, v) => v.abs() > m ? v.abs() : m);
    if (Tr.isEnglish) {
      // 1万円 = 0.01m yen。100億円 = 10bn yen。10bn 未満は m yen の整数で
      // 出す(bn の小数1桁では差が見えない)。
      if (top >= 1000000) return const _ProjectionUnit('bn yen', 100000, 1);
      return _ProjectionUnit('m yen', 100, top < 10000 ? 1 : 0);
    }
    return top >= 10000
        ? _ProjectionUnit(Tr.pick('億円', 'hundred million yen'), 10000, 1)
        : _ProjectionUnit(Tr.pick('万円', 'ten thousand yen'), 1, 0);
  }

  /// 単位を付けない数。0 は「—」。
  String format(int man, {bool signed = false}) {
    if (man == 0) return '—';
    final sign = man < 0 ? '-' : (signed ? '+' : '');
    final v = man.abs();
    if (decimals == 0) return '$sign${_grouped((v / divisor).round())}';
    final x = (v * 10 / divisor).round();
    return '$sign${_grouped(x ~/ 10)}.${x % 10}';
  }

  static String _grouped(int v) {
    final s = v.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
