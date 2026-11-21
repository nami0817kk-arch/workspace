import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/partner_club_engine.dart';
import '../models/matchday_promo.dart';
import '../models/owner_work.dart';
import '../services/feedback_service.dart';
import '../state/game_state.dart';
import '../theme/semantic_colors.dart';
import '../widgets/undoable.dart';
import '../widgets/fm_panel.dart';
import '../widgets/responsive_body.dart';
import '../logic/economy_scale.dart';

/// オーナーの仕事。資金と2つの期待を動かす手を、分野ごとに並べる。
/// どの手も1シーズンに1回。何かを得て何かを払う。
class OwnerWorkScreen extends StatefulWidget {
  const OwnerWorkScreen({super.key});

  @override
  State<OwnerWorkScreen> createState() => _OwnerWorkScreenState();
}

/// 分野を1つずつ見せる。全部を1列に並べると縦に35画面分あり、目当ての手まで
/// 延々とスクロールしていた。0 は試合日のイベントと提携、1以降は分野。
class _OwnerWorkScreenState extends State<OwnerWorkScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final save = game.save;
    return Scaffold(
      appBar: AppBar(title: Text(Tr.pick('オーナーの仕事', 'Owner\'s work'))),
      body: save == null
          ? const SizedBox.shrink()
          : ResponsiveBody(
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  Text(
                    Tr.pick(
                        '資金 ${formatMoney(save.budget)}。どの手も1シーズンに1回だけ打てます。',
                        'Funds ${formatMoney(save.budget)}. Each move can be made once per season.'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (var i = 0; i <= OwnerWorkCategory.values.length; i++)
                        ChoiceChip(
                          label: Text(i == 0
                              ? Tr.pick('試合日と提携', 'Matchdays & partners')
                              : OwnerWorkCategory.values[i - 1].label),
                          selected: _tab == i,
                          onSelected: (_) => setState(() => _tab = i),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_tab == 0) ...[
                    const _PromoCard(),
                    const _PartnerCard(),
                  ] else
                    for (final w in ownerWorks.where((w) =>
                        w.category == OwnerWorkCategory.values[_tab - 1]))
                      _WorkTile(work: w),
                ],
              ),
            ),
    );
  }
}

class _WorkTile extends StatelessWidget {
  const _WorkTile({required this.work});

  final OwnerWork work;

  Widget _chip(BuildContext context, String label, int v,
      {bool money = false}) {
    if (v == 0) return const SizedBox.shrink();
    return _EffectPill(
        text:
            '$label ${money ? formatMoneySigned(v) : '${v > 0 ? '+' : ''}$v'}',
        good: v > 0);
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final done = game.ownerWorkDoneThisSeason(work);
    final can = game.canDoOwnerWork(work);
    // 額は5部の規模で書いてあり、今の部の規模に直して見せる(実際に動く額)。
    final funds = game.scaledMoney(work.funds);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(work.title,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(work.description,
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _chip(context, Tr.pick('資金', 'Funds'), funds,
                          money: true),
                      _chip(context, Tr.pick('サポーター', 'Fans'), work.supporters),
                      _chip(context, Tr.pick('株主', 'Shareholders'),
                          work.shareholders),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: can
                  ? () async {
                      FeedbackService.tap();
                      await runUndoable(
                        context,
                        action: () =>
                            context.read<GameState>().doOwnerWork(work.id),
                        done: Tr.pick(
                            '「${work.title}」を実行しました', 'Done: ${work.title}'),
                      );
                    }
                  : null,
              child: Text(done
                  ? Tr.pick('今季済み', 'Done')
                  : work.onlyInRed && !can
                      ? Tr.pick('赤字のとき', 'When in red')
                      : Tr.pick('実行', 'Do it')),
            ),
          ],
        ),
      ),
    );
  }
}

/// 提携クラブ。毎季の提携費を払う代わりに、2つの期待が少し上がる。
class _PartnerCard extends StatelessWidget {
  const _PartnerCard();

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final partner = game.partnerClub;
    return FmPanel(
      title: Tr.pick('提携クラブ', 'Partner club'),
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            Tr.pick(
                '毎季の提携費${formatMoney(game.partnerSeasonCost)}で、サポーターと株主の期待が+${PartnerClubEngine.supportersBonus}ずつ上がる。資金が足りない季は解消される。',
                'Pay ${formatMoney(game.partnerSeasonCost)} per season for +${PartnerClubEngine.supportersBonus} to both expectations. It lapses if funds run short.'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  partner == null
                      ? Tr.pick('提携なし', 'No partner')
                      : Tr.pick('提携中: ${partner.name}',
                          'Partnered with ${partner.name}'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              if (partner != null)
                TextButton(
                  onPressed: () => context.read<GameState>().clearPartnerClub(),
                  child: Text(Tr.pick('解消', 'End')),
                ),
              FilledButton(
                onPressed: () async {
                  final id = await showDialog<String>(
                    context: context,
                    builder: (ctx) => SimpleDialog(
                      title: Text(Tr.pick('提携するクラブ', 'Choose a partner')),
                      children: [
                        for (final t in game.partnerCandidates)
                          SimpleDialogOption(
                            onPressed: () => Navigator.pop(ctx, t.id),
                            child: Text(t.name),
                          ),
                      ],
                    ),
                  );
                  if (id != null && context.mounted) {
                    await context.read<GameState>().setPartnerClub(id);
                  }
                },
                child: Text(partner == null
                    ? Tr.pick('提携する', 'Partner')
                    : Tr.pick('変える', 'Change')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 試合日のイベント。次の節の観客収入とサポーターの期待を動かす。
class _PromoCard extends StatelessWidget {
  const _PromoCard();

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final active = game.activeMatchdayPromo;
    final budget = game.save?.budget ?? 0;
    return FmPanel(
      title: Tr.pick('試合日のイベント(次の節)', 'Matchday event (next game)'),
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (active != null) ...[
            Text(Tr.pick('決定済み: ${active.title}', 'Set: ${active.title}'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () =>
                    context.read<GameState>().cancelMatchdayPromo(),
                child: Text(Tr.pick('取り消す(費用は戻る)', 'Cancel (refund)')),
              ),
            ),
          ] else
            // 効き目は式(観客収入 x1.10)ではなく、色の付いた札で
            // (+10% は緑、-10% は赤)。費用はボタンに入れる(2026-11-21)。
            for (final p in matchdayPromos)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.title,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          Text(p.description,
                              style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (_gatePct(p) != 0)
                                _EffectPill(
                                    text: Tr.pick(
                                        '観客収入 ${_gatePct(p) > 0 ? '+' : ''}${_gatePct(p)}%',
                                        'Gate ${_gatePct(p) > 0 ? '+' : ''}${_gatePct(p)}%'),
                                    good: _gatePct(p) > 0),
                              if (p.supporters != 0)
                                _EffectPill(
                                    text: Tr.pick(
                                        'サポーター ${p.supporters > 0 ? '+' : ''}${p.supporters}',
                                        'Fans ${p.supporters > 0 ? '+' : ''}${p.supporters}'),
                                    good: p.supporters > 0),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: game.scaledMoney(p.cost) > budget
                          ? null
                          : () => runUndoable(
                                context,
                                action: () async {
                                  context
                                      .read<GameState>()
                                      .setMatchdayPromo(p.id);
                                  return true;
                                },
                                done: Tr.pick('次の節は「${p.title}」にしました',
                                    'Next matchday: ${p.title}'),
                              ),
                      child: Text(p.cost == 0
                          ? Tr.pick('決める(無料)', 'Set (free)')
                          : Tr.pick(
                              '決める(${formatMoney(game.scaledMoney(p.cost))})',
                              'Set (${formatMoney(game.scaledMoney(p.cost))})')),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

/// 観客収入の倍率を%にする(1.10 → 10)。
int _gatePct(MatchdayPromo p) => ((p.gateMultiplier - 1) * 100).round();

/// 効き目の小さな札。良いものは緑、悪いものは赤。
class _EffectPill extends StatelessWidget {
  const _EffectPill({required this.text, required this.good});
  final String text;
  final bool good;

  @override
  Widget build(BuildContext context) {
    final color = good
        ? SemanticColors.positive(context)
        : SemanticColors.negative(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.bold, color: color)),
    );
  }
}
