import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/ledger_engine.dart';
import '../models/ledger.dart';
import '../state/game_state.dart';
import '../theme/semantic_colors.dart';

/// 今季の収支(損益計算書)と、人件費率・資金の見通し、過去の損益。
/// クラブ経営の画面に置く。
class LedgerCard extends StatelessWidget {
  const LedgerCard({super.key});

  static String _money(int v) =>
      Tr.pick('${v >= 0 ? '+' : ''}$v万円', '${v >= 0 ? '+' : ''}$v');

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
      LedgerCategory.prize,
      LedgerCategory.playerSales,
    ]);
    final costRows = rows(const [
      LedgerCategory.playerWages,
      LedgerCategory.staffWages,
      LedgerCategory.appearanceFees,
      LedgerCategory.transfers,
      LedgerCategory.facilities,
    ]);
    final otherRows = rows(const [
      LedgerCategory.financing,
      LedgerCategory.other,
    ]);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              Tr.pick('今季の収支(第${save.league.season}季)',
                  'This season (Season ${save.league.season})'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (incomeRows.isEmpty && costRows.isEmpty)
              Text(Tr.pick('まだ試合が行われていません。節が進むと内訳が出ます。',
                  'No matches yet. The breakdown appears as the season goes on.'))
            else ...[
              _Heading(Tr.pick('収入', 'Income')),
              ...incomeRows,
              const SizedBox(height: 6),
              _Heading(Tr.pick('支出', 'Expenses')),
              ...costRows,
              if (otherRows.isNotEmpty) ...[
                const SizedBox(height: 6),
                _Heading(Tr.pick('損益に含めないもの・その他', 'Not in profit / other')),
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
                backgroundColor: Colors.grey.shade300,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              Tr.pick(
                  '営業収入(観客・スポンサー・グッズ・賞金)に対する、選手・スタッフの給与と出場手当の割合。${(LedgerEngine.wageRatioWarn * 100).round()}%を超えると注意です。',
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
                      'Outlook: at the current rate your funds run out in about $runway matchdays.'),
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
              for (final l in past.reversed)
                _Line(
                  label: Tr.pick('第${l.season}季', 'Season ${l.season}'),
                  value: _money(l.profit),
                  color: l.profit >= 0
                      ? SemanticColors.positive(context)
                      : SemanticColors.negative(context),
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
