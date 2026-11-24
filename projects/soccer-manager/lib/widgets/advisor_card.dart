import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/advisor_engine.dart';
import '../state/game_state.dart';
import '../logic/economy_scale.dart';
import '../theme/semantic_colors.dart';
import 'help_button.dart';

/// 経営アドバイザー。レベルを上げるほど効果が大きく、毎季の報酬も増える。
///
/// 2026-11-25 の第7段: 以前は「未契約」としか出ず、雇う得が分からなかった
/// (利用者の指摘)。顧問ごとに Lv1〜3 の効き目と報酬を表で並べ、今の
/// レベルに色を付ける。財務顧問は、増える収入の見込みも年の額で出す
/// (報酬と比べて雇うかを決められる)。
class AdvisorCard extends StatelessWidget {
  const AdvisorCard({super.key});

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final save = gs.save;
    if (save == null) return const SizedBox.shrink();
    final total = gs.scaledMoney(AdvisorEngine.totalSalary(save.advisors));
    return Card(
      key: const ValueKey('advisor-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TitleWithHelp(
              title: Tr.pick('経営アドバイザー', 'Advisors'),
              help: Tr.pick(
                  '顧問はレベル1〜3で雇います。上げるほど効き目が大きく、報酬も上がります。報酬は季の終わりにまとめて払います。−で下げ、0にすると契約を切ります(違約金はありません)。',
                  'Hire each advisor at level 1 to 3. Higher levels work better and cost more. Fees are paid at the end of the season. Use − to step down; at 0 the contract ends (no fee).'),
            ),
            Text(
              Tr.pick('報酬の合計 ${formatMoney(total)}/季',
                  'Fees in total ${formatMoney(total)} a season'),
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 4),
            for (final a in Advisor.values)
              _AdvisorBlock(advisor: a, level: save.advisors[a.name] ?? 0),
          ],
        ),
      ),
    );
  }
}

class _AdvisorBlock extends StatelessWidget {
  const _AdvisorBlock({required this.advisor, required this.level});

  final Advisor advisor;
  final int level;

  @override
  Widget build(BuildContext context) {
    final gs = context.read<GameState>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final subtle = SemanticColors.subtleText(context);
    final a = advisor;
    const tap = Size(48, 48);
    return Padding(
      key: ValueKey('advisor-${a.name}'),
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(TextSpan(children: [
                      TextSpan(
                          text: a.label,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(
                        text: level == 0
                            ? Tr.pick('  未契約', '  not hired')
                            : '  Lv$level',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: level == 0 ? subtle : scheme.primary),
                      ),
                    ])),
                    Text(a.description,
                        style: TextStyle(fontSize: 11.5, color: subtle)),
                  ],
                ),
              ),
              IconButton(
                key: ValueKey('advisor-${a.name}-minus'),
                tooltip: level == 1
                    ? Tr.pick('${a.label}の契約を切る', 'Let the ${a.label} go')
                    : Tr.pick('${a.label}のレベルを下げる', 'Lower the ${a.label}'),
                style: IconButton.styleFrom(minimumSize: tap),
                icon: const Icon(Icons.remove_circle_outline),
                onPressed:
                    level > 0 ? () => gs.setAdvisorLevel(a, level - 1) : null,
              ),
              IconButton(
                key: ValueKey('advisor-${a.name}-plus'),
                tooltip: level == 0
                    ? Tr.pick('${a.label}を雇う', 'Hire the ${a.label}')
                    : Tr.pick('${a.label}のレベルを上げる', 'Raise the ${a.label}'),
                style: IconButton.styleFrom(minimumSize: tap),
                icon: const Icon(Icons.add_circle_outline),
                onPressed: level < AdvisorEngine.maxLevel
                    ? () => gs.setAdvisorLevel(a, level + 1)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Lv1〜3 の効き目と報酬。今のレベルに色を付ける。
          Row(
            children: [
              for (var l = 1; l <= AdvisorEngine.maxLevel; l++) ...[
                if (l > 1) const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    key: ValueKey('advisor-${a.name}-lv$l'),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: l == level
                          ? scheme.primaryContainer
                          : scheme.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(6),
                      border: l == level
                          ? Border.all(color: scheme.primary)
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Lv$l',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: l == level
                                    ? scheme.onPrimaryContainer
                                    : subtle)),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(a.shortEffect(l),
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: l == level
                                      ? scheme.onPrimaryContainer
                                      : null)),
                        ),
                        if (a == Advisor.finance)
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              Tr.pick(
                                  '年+${formatMoney(gs.advisorFinanceGain(l))}',
                                  '+${formatMoney(gs.advisorFinanceGain(l))}/yr'),
                              style: TextStyle(
                                  fontSize: 11.5,
                                  color: l == level
                                      ? scheme.onPrimaryContainer
                                      : SemanticColors.positive(context)),
                            ),
                          ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            Tr.pick('報酬 ${formatMoney(gs.advisorFee(l))}/季',
                                'Fee ${formatMoney(gs.advisorFee(l))}/season'),
                            style: TextStyle(
                                fontSize: 11.5,
                                color: l == level
                                    ? scheme.onPrimaryContainer
                                    : subtle),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
