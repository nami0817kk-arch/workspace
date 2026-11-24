import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/budget_engine.dart';
import '../logic/economy_scale.dart';
import '../models/budget_plan.dart';
import '../state/game_state.dart';

/// オーナーが年の予算を5つの配り先へ配るカード。
///
/// つまみ(Slider)をやめた(2026-11-24「操作しにくい」)。つまみでは
/// ①他の配り先が勝手に動く ②1%刻みで止めにくい ③縦のスクロールと
/// 横のつまみがぶつかる ④指を離した瞬間に確定して戻せない、の4つが起きていた。
///
/// - 配り先ごとに「−」「＋」で5%ずつ動かす。他の配り先は動かさない。
/// - 減らした分は「残り」になり、好きな配り先へ足す。
/// - 「決定」を押すまで保存しない。「元に戻す」で保存してある配分に戻る。
/// - 残りが0%のときだけ決定できる。
class BudgetPlanCard extends StatefulWidget {
  const BudgetPlanCard({super.key});

  /// 配り先ごとの色。帯と各行の頭の印で同じ色を使う。明るい箱(白)でも
  /// 暗い箱でも、地に対して 3:1 以上の差がある(テストで確かめている)。
  static Color colorFor(BudgetCategory c, Brightness brightness) {
    final light = brightness == Brightness.light;
    return switch (c) {
      BudgetCategory.signing =>
        light ? const Color(0xFF1D62C9) : const Color(0xFF5AADFF),
      BudgetCategory.youth =>
        light ? const Color(0xFF1B7A3A) : const Color(0xFF6CD48C),
      BudgetCategory.facilities =>
        light ? const Color(0xFF7A4FC2) : const Color(0xFFB79CFF),
      BudgetCategory.marketing =>
        light ? const Color(0xFFC2327E) : const Color(0xFFFF8FC4),
      BudgetCategory.dividend =>
        light ? const Color(0xFF9A6B00) : const Color(0xFFE0BC6A),
    };
  }

  /// 「−」「＋」の一辺。横画面は全体を 0.93 倍で描くので、52 で実寸 48pt を
  /// 超える(48 だと 44.6pt)。
  static const double stepButtonSize = 52;

  @override
  State<BudgetPlanCard> createState() => _BudgetPlanCardState();
}

class _BudgetPlanCardState extends State<BudgetPlanCard> {
  /// 配り直している途中の配分。null のときは保存してある配分を見せる。
  BudgetPlan? _draft;
  bool _saving = false;

  String _effect(BudgetCategory c, BudgetPlan plan) {
    String pct(double m) {
      final d = ((m - 1) * 100).round();
      return d >= 0 ? '+$d%' : '$d%';
    }

    switch (c) {
      case BudgetCategory.signing:
        return Tr.pick('給与の上限 ${pct(BudgetEngine.wageCapMultiplier(plan))}',
            'Wage cap ${pct(BudgetEngine.wageCapMultiplier(plan))}');
      case BudgetCategory.youth:
        // 育成の効き目はまだ数字で出せない。作りかけの字は出さない。
        return '';
      case BudgetCategory.facilities:
        final m = BudgetEngine.facilityCostMultiplier(plan);
        return Tr.pick('増築費 ${pct(m)}', 'Upgrade cost ${pct(m)}');
      case BudgetCategory.marketing:
        return Tr.pick('週収入 ${pct(BudgetEngine.incomeMultiplier(plan))}',
            'Weekly income ${pct(BudgetEngine.incomeMultiplier(plan))}');
      case BudgetCategory.dividend:
        final d = BudgetEngine.dividendExpectationDelta(plan);
        return Tr.pick('株主の期待 毎年 ${d >= 0 ? '+' : ''}$d',
            "Shareholder expectation ${d >= 0 ? '+' : ''}$d per year");
    }
  }

  void _setDraft(BudgetPlan next, BudgetPlan saved) =>
      setState(() => _draft = next.sameAs(saved) ? null : next);

  Future<void> _commit(GameState gameState) async {
    final draft = _draft;
    if (draft == null || !draft.isComplete || _saving) return;
    setState(() => _saving = true);
    try {
      await gameState.setBudgetPlan(draft);
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _draft = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final saved = gameState.budgetPlan;
    final plan = _draft ?? saved;
    final dirty = _draft != null;
    final pool = gameState.annualBudgetPool;
    final remaining = plan.remaining;
    // 配り切っているときは、端数を補強へ回して合計を総額に揃える(今まで
    // どおり)。途中のときは端数も「残り」に入れる。
    final amounts = plan.isComplete
        ? BudgetEngine.allocate(pool, plan)
        : {
            for (final c in BudgetCategory.values)
              c: BudgetEngine.amountFor(pool, plan, c),
          };
    final remainingAmount =
        pool - amounts.values.fold<int>(0, (t, v) => t + v);

    final presets = <(String, String, BudgetPlan)>[
      ('signing', Tr.pick('補強重視', 'Signings'), BudgetPlan.signingFocus()),
      ('youth', Tr.pick('育成重視', 'Youth'), BudgetPlan.youthFocus()),
      ('balanced', Tr.pick('バランス', 'Balanced'), BudgetPlan.balanced()),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Tr.pick('今年の予算の配り方', 'How to split this year\'s budget'),
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              Tr.pick('総額 ${formatMoney(pool)}。−と＋で5%ずつ動かし、「決定」で保存します。',
                  'Total ${formatMoney(pool)}. Move 5% at a time with − and +, then press Confirm.'),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(Tr.pick('おまかせ', 'Presets'),
                    style: theme.textTheme.bodySmall),
                for (final (id, label, preset) in presets)
                  OutlinedButton(
                    key: ValueKey('budget-preset-$id'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      visualDensity: VisualDensity.standard,
                    ),
                    onPressed: plan.sameAs(preset)
                        ? null
                        : () => _setDraft(preset, saved),
                    child: Text(label),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            _ShareBar(plan: plan),
            const SizedBox(height: 6),
            Row(
              children: [
                _Swatch(color: scheme.outlineVariant, border: scheme.outline),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    Tr.pick(
                        '残り $remaining%（${formatMoney(remainingAmount)}）',
                        'Left to assign $remaining% (${formatMoney(remainingAmount)})'),
                    key: const ValueKey('budget-remaining'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight:
                          remaining > 0 ? FontWeight.w700 : FontWeight.w400,
                      color: remaining > 0
                          ? scheme.onSurface
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            for (final c in BudgetCategory.values)
              _CategoryRow(
                category: c,
                share: plan.share(c),
                amount: formatMoney(amounts[c] ?? 0),
                effect: _effect(c, plan),
                onMinus: plan.share(c) > 0
                    ? () => _setDraft(plan.stepDown(c), saved)
                    : null,
                onPlus: remaining > 0 && plan.share(c) < 100
                    ? () => _setDraft(plan.stepUp(c), saved)
                    : null,
              ),
            const SizedBox(height: 8),
            if (remaining > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  Tr.pick('残り$remaining%を配ってください',
                      'Assign the remaining $remaining% first'),
                  key: const ValueKey('budget-reason'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey('budget-reset'),
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48)),
                    onPressed: dirty && !_saving
                        ? () => setState(() => _draft = null)
                        : null,
                    child: Text(Tr.pick('元に戻す', 'Undo')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    key: const ValueKey('budget-commit'),
                    style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48)),
                    onPressed: dirty && plan.isComplete && !_saving
                        ? () => _commit(gameState)
                        : null,
                    child: Text(Tr.pick('決定', 'Confirm')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 色の小さな四角。帯の色と各行を結び付ける印。
class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, this.border});

  final Color color;
  final Color? border;

  @override
  Widget build(BuildContext context) => Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
          border: border == null ? null : Border.all(color: border!),
        ),
      );
}

/// 5つの配分を1本の帯で見せる。まだ配っていない分は右端に灰色で残る。
class _ShareBar extends StatelessWidget {
  const _ShareBar({required this.plan});

  final BudgetPlan plan;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final parts = <(int, Color)>[
      for (final c in BudgetCategory.values)
        if (plan.share(c) > 0)
          (plan.share(c), BudgetPlanCard.colorFor(c, brightness)),
      if (plan.remaining > 0) (plan.remaining, scheme.outlineVariant),
    ];
    return Semantics(
      label: Tr.pick(
          '配分: ${[
            for (final c in BudgetCategory.values) '${c.label} ${plan.share(c)}%'
          ].join('、')}',
          'Split: ${[
            for (final c in BudgetCategory.values) '${c.label} ${plan.share(c)}%'
          ].join(', ')}'),
      child: Container(
        key: const ValueKey('budget-bar'),
        height: 16,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: scheme.outline),
        ),
        child: Row(
          children: [
            for (var i = 0; i < parts.length; i++)
              Expanded(
                flex: parts[i].$1,
                child: Container(
                  // 隣り合う色の間に、箱の地の色の細い切れ目を入れる(色の差
                  // だけに頼らない)。
                  margin: EdgeInsets.only(left: i == 0 ? 0 : 2),
                  color: parts[i].$2,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 配り先1つの行。上の段に 色の印・名前・金額、下の段に 効き目 と
/// 「− N% ＋」。
class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.share,
    required this.amount,
    required this.effect,
    required this.onMinus,
    required this.onPlus,
  });

  final BudgetCategory category;
  final int share;
  final String amount;
  final String effect;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = BudgetPlanCard.colorFor(category, theme.brightness);
    const size = BudgetPlanCard.stepButtonSize;
    final buttonStyle = IconButton.styleFrom(
      minimumSize: const Size(size, size),
      fixedSize: const Size(size, size),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
    final name = category.label;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    _Swatch(color: color),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 18),
                  child: Text(
                    [amount, if (effect.isNotEmpty) effect]
                        .join(Tr.pick('・', ' • ')),
                    key: ValueKey('budget-detail-${category.name}'),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          IconButton.filledTonal(
            key: ValueKey('budget-minus-${category.name}'),
            style: buttonStyle,
            tooltip: Tr.pick('$nameを減らす', 'Less for $name'),
            onPressed: onMinus,
            icon: const Icon(Icons.remove),
          ),
          SizedBox(
            width: 48,
            child: Text(
              '$share%',
              key: ValueKey('budget-share-${category.name}'),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          IconButton.filledTonal(
            key: ValueKey('budget-plus-${category.name}'),
            style: buttonStyle,
            tooltip: Tr.pick('$nameを増やす', 'More for $name'),
            onPressed: onPlus,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
