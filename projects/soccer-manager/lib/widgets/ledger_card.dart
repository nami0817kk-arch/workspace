import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/ledger_engine.dart';
import '../logic/money_calendar.dart';
import '../models/ledger.dart';
import '../state/game_state.dart';
import '../theme/semantic_colors.dart';
import '../logic/economy_scale.dart';

/// 今季の収支(損益計算書)と、人件費率・資金の見通し、過去の損益。
/// クラブ経営の画面に置く。
class LedgerCard extends StatelessWidget {
  const LedgerCard({super.key});

  static String _money(int v) => formatMoneySigned(v);

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final save = gameState.save;
    if (save == null) return const SizedBox.shrink();
    final ledger = gameState.currentLedger;
    final past = gameState.pastLedgers;
    final ratio = ledger.wageRatio;
    final level = LedgerEngine.wageRatioLevel(ratio);
    final runway = gameState.runwayWeeks;

    Color levelColor() => switch (level) {
          2 => SemanticColors.negative(context),
          1 => Colors.orange.shade700,
          _ => SemanticColors.positive(context),
        };

    List<Widget> rows(Iterable<LedgerCategory> cats) => [
          for (final c in cats)
            if (ledger.of(c) != 0)
              _Line(label: c.label, value: _money(ledger.of(c))),
        ];

    final incomeRows = rows(const [
      LedgerCategory.gate,
      LedgerCategory.sponsor,
      LedgerCategory.merchandise,
      LedgerCategory.broadcast,
      LedgerCategory.prize,
      LedgerCategory.playerSales,
    ]);
    final costRows = rows(const [
      LedgerCategory.playerWages,
      LedgerCategory.staffWages,
      LedgerCategory.appearanceFees,
      LedgerCategory.transfers,
      LedgerCategory.amortization,
      LedgerCategory.facilities,
      LedgerCategory.operations,
      LedgerCategory.infrastructure,
      LedgerCategory.interest,
      LedgerCategory.other,
    ]);
    // 移籍金の支払いは資産(損益には償却で入る)、融資・預金は元本の出入り。
    final otherRows = rows(const [
      LedgerCategory.transferFees,
      LedgerCategory.financing,
    ]);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              Tr.pick(
                  '今季の収支(第${save.league.season}季・${MoneyCalendar.fiscalYearLabel(save.league.season)}年度 7/1〜6/30)',
                  'This season (Season ${save.league.season}, FY ${MoneyCalendar.fiscalYearLabel(save.league.season)}, 1 Jul to 30 Jun)'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (incomeRows.isEmpty && costRows.isEmpty)
              Text(Tr.pick('まだ試合が行われていません。節が進むと内訳が出ます。',
                  'No matches yet. The breakdown appears as the season goes on.'))
            else ...[
              // 幅があれば、収入と支出を左右に並べる(FMの収支表)。
              LayoutBuilder(
                builder: (context, c) {
                  final incomeCol = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Heading(Tr.pick('収入', 'Income')),
                      ...incomeRows,
                    ],
                  );
                  final costCol = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Heading(Tr.pick('支出', 'Expenses')),
                      ...costRows,
                    ],
                  );
                  if (c.maxWidth < 520) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        incomeCol,
                        const SizedBox(height: 6),
                        costCol,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: incomeCol),
                      const SizedBox(width: 24),
                      Expanded(child: costCol),
                    ],
                  );
                },
              ),
              if (otherRows.isNotEmpty) ...[
                const SizedBox(height: 6),
                _Heading(Tr.pick('損益に含めないもの(資金だけが動く)', 'Not in profit (cash only)')),
                ...otherRows,
              ],
              const Divider(height: 20),
              _Line(
                label: Tr.pick('今季の損益', 'Profit this season'),
                value: _money(ledger.profit),
                bold: true,
                color: ledger.profit >= 0
                    ? SemanticColors.positive(context)
                    : SemanticColors.negative(context),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              Tr.pick(
                  '人件費率: ${(ratio * 100).round()}% ('
                      '${switch (level) { 2 => '危険', 1 => '注意', _ => '健全' }})',
                  'Wage ratio: ${(ratio * 100).round()}% ('
                      '${switch (level) { 2 => 'danger', 1 => 'caution', _ => 'healthy' }})'),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: levelColor(),
              ),
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: ratio.clamp(0.0, 1.0),
                minHeight: 6,
                color: levelColor(),
                // 暗い表示でほぼ白の帯が浮いていたので、テーマの色にする。
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              Tr.pick(
                  '営業収入(観客・スポンサー・グッズ・放映権・賞金)に対する、選手・スタッフの給与と出場手当の割合。${(LedgerEngine.wageRatioWarn * 100).round()}%を超えると注意です。',
                  'Wages and appearance fees as a share of operating income. Above ${(LedgerEngine.wageRatioWarn * 100).round()}% is a warning.'),
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            Text(
              runway == null
                  ? Tr.pick('資金の見通し: 今の収支なら資金は減りません。',
                      'Outlook: at the current rate your funds do not run out.')
                  : Tr.pick(
                      '資金の見通し: 今の収支のままだと約$runway節で資金が尽きます。',
                      'Outlook: at the current rate your funds run out in about ${Tr.plural(runway, 'matchday')}.'),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: runway == null
                    ? SemanticColors.positive(context)
                    : (runway <= 10
                        ? SemanticColors.negative(context)
                        : Colors.orange.shade700),
              ),
            ),
            if (past.isNotEmpty) ...[
              const Divider(height: 20),
              _Heading(Tr.pick('過去の損益', 'Past seasons')),
              // 季・営業収入・人件費・損益を1行の表で。
              Row(
                children: [
                  Expanded(
                      child: Text(Tr.pick('季', 'Season'),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                  _Cell(Tr.pick('営業収入', 'Income'), bold: true),
                  _Cell(Tr.pick('人件費', 'Wages'), bold: true),
                  _Cell(Tr.pick('損益', 'Profit'), bold: true),
                ],
              ),
              for (final l in past.reversed)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(
                          child: Text(
                              Tr.pick(
                                  '第${l.season}季(${MoneyCalendar.fiscalYearLabel(l.season)})',
                                  'S${l.season} (${MoneyCalendar.fiscalYearLabel(l.season)})'),
                              style: const TextStyle(fontSize: 12))),
                      _Cell(formatMoney(l.operatingIncome)),
                      _Cell(formatMoney(l.wageCost)),
                      _Cell(
                        formatMoneySigned(l.profit),
                        color: l.profit >= 0
                            ? SemanticColors.positive(context)
                            : SemanticColors.negative(context),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Text(text,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      );
}

class _Line extends StatelessWidget {
  const _Line({
    required this.label,
    required this.value,
    this.bold = false,
    this.color,
  });

  final String label;
  final String value;
  final bool bold;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.bold : null,
      color: color,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}

/// 表の1列(右寄せの数字)。
class _Cell extends StatelessWidget {
  const _Cell(this.text, {this.bold = false, this.color});

  final String text;
  final bool bold;
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 72,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Text(
            text,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: bold ? 11 : 12,
              fontWeight: bold ? FontWeight.bold : null,
              color: color,
            ),
          ),
        ),
      );
}
