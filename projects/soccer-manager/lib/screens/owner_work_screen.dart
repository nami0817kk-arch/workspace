import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/partner_club_engine.dart';
import '../models/matchday_promo.dart';
import '../models/owner_directive.dart';
import '../models/owner_work.dart';
import '../services/feedback_service.dart';
import '../state/game_state.dart';
import '../theme/semantic_colors.dart';
import '../widgets/responsive_body.dart';

/// オーナーの仕事。資金と2つの期待を動かす手を、分野ごとに並べる。
/// どの手も1シーズンに1回。何かを得て何かを払う。
class OwnerWorkScreen extends StatelessWidget {
  const OwnerWorkScreen({super.key});

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
                        '資金 ${save.budget}万円。どの手も1シーズンに1回だけ打てます。',
                        'Funds ${save.budget}. Each move can be made once per season.'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const _DirectiveCard(),
                  const _PromoCard(),
                  const _PartnerCard(),
                  for (final cat in OwnerWorkCategory.values) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 4),
                      child: Text(cat.label,
                          style: Theme.of(context).textTheme.titleSmall),
                    ),
                    for (final w in ownerWorks.where((w) => w.category == cat))
                      _WorkTile(work: w),
                  ],
                ],
              ),
            ),
    );
  }
}

class _WorkTile extends StatelessWidget {
  const _WorkTile({required this.work});

  final OwnerWork work;

  Widget _chip(BuildContext context, String label, int v) {
    if (v == 0) return const SizedBox.shrink();
    final color = v > 0
        ? SemanticColors.positive(context)
        : SemanticColors.negative(context);
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Text('$label ${v > 0 ? '+' : ''}$v',
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.bold, color: color)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final done = game.ownerWorkDoneThisSeason(work);
    final can = game.canDoOwnerWork(work);
    final funds = work.funds;
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
                    children: [
                      _chip(context, Tr.pick('資金', 'Funds'), funds),
                      _chip(context, Tr.pick('サポーター', 'Fans'),
                          work.supporters),
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
                      await context
                          .read<GameState>()
                          .doOwnerWork(work.id);
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
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Tr.pick('提携クラブ', 'Partner club'),
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              Tr.pick(
                  '毎季の提携費${PartnerClubEngine.seasonCost}万円で、サポーターと株主の期待が+${PartnerClubEngine.supportersBonus}ずつ上がる。資金が足りない季は解消される。',
                  'Pay ${PartnerClubEngine.seasonCost} per season for +${PartnerClubEngine.supportersBonus} to both expectations. It lapses if funds run short.'),
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
                    onPressed: () =>
                        context.read<GameState>().clearPartnerClub(),
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
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Tr.pick('試合日のイベント(次の節)', 'Matchday event (next game)'),
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
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
              for (final p in matchdayPromos)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(p.title),
                  subtitle: Text(
                    '${p.description}\n'
                    '${Tr.pick('費用 ${p.cost}万円', 'Cost ${p.cost}')} / '
                    '${Tr.pick('観客収入', 'Gate')} x${p.gateMultiplier.toStringAsFixed(2)} / '
                    '${Tr.pick('サポーター', 'Fans')} ${p.supporters >= 0 ? '+' : ''}${p.supporters}',
                  ),
                  isThreeLine: true,
                  trailing: FilledButton(
                    onPressed: p.cost > budget
                        ? null
                        : () => context.read<GameState>().setMatchdayPromo(p.id),
                    child: Text(Tr.pick('決める', 'Set')),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// 監督への一言の指示(次の節)。
class _DirectiveCard extends StatelessWidget {
  const _DirectiveCard();

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final current = game.ownerDirective;
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Tr.pick('監督への一言(次の節)', 'A word to the manager (next game)'),
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              current == null
                  ? Tr.pick('いまは監督に任せています。', 'Leaving it to the manager.')
                  : Tr.pick('指示中: ${current.label}', 'Ordered: ${current.label}'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                for (final d in OwnerDirective.values)
                  ChoiceChip(
                    label: Text(d.label),
                    selected: current == d,
                    onSelected: (_) =>
                        context.read<GameState>().setOwnerDirective(d),
                  ),
                if (current != null)
                  TextButton(
                    onPressed: () =>
                        context.read<GameState>().clearOwnerDirective(),
                    child: Text(Tr.pick('任せる', 'Leave it')),
                  ),
              ],
            ),
            if (current != null) ...[
              const SizedBox(height: 4),
              Text(current.description,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}
