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
import '../logic/todo_advisor.dart';
import '../widgets/shell_nav.dart';
import '../widgets/fm_panel.dart';
import '../widgets/responsive_body.dart';
import '../logic/economy_scale.dart';
import '../widgets/disabled_reason.dart';

/// オーナーの仕事。資金と2つの期待を動かす手を、分野ごとに並べる。
/// 広報・ファンの手は月に1回(どれか1つ)、ほかの手は1シーズンに1回。
/// 何かを得て何かを払う。
class OwnerWorkScreen extends StatefulWidget {
  const OwnerWorkScreen({super.key, this.initialCard});

  /// 最初に開く分野の札([TodoPlaces.cardFans] など)。単独で開くとき用。
  final String? initialCard;

  @override
  State<OwnerWorkScreen> createState() => _OwnerWorkScreenState();
}

/// 分野を1つずつ見せる。全部を1列に並べると縦に35画面分あり、目当ての手まで
/// 延々とスクロールしていた。0 は試合日のイベントと提携、1以降は分野。
class _OwnerWorkScreenState extends State<OwnerWorkScreen> {
  int _tab = 0;
  ShellNav? _nav;
  int _seenSerial = 0;

  @override
  void initState() {
    super.initState();
    final card = widget.initialCard;
    if (card != null) _tab = _tabFor(card, context.read<GameState>());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nav = ShellNav.maybeOf(context);
    if (nav != _nav) {
      _nav?.removeListener(_fromNav);
      _nav = nav?..addListener(_fromNav);
      _applyNav();
    }
  }

  @override
  void dispose() {
    _nav?.removeListener(_fromNav);
    super.dispose();
  }

  /// 「やること」の行から、分野の札を選ばれた。
  void _fromNav() {
    if (!mounted) return;
    final before = _tab;
    _applyNav();
    if (before != _tab) setState(() {});
  }

  void _applyNav() {
    final nav = _nav;
    if (nav == null || nav.cardSerial == _seenSerial) return;
    _seenSerial = nav.cardSerial;
    final card = nav.card;
    if (card == null || nav.menu != TodoMenu.ownerRoom) return;
    _tab = _tabFor(card, context.read<GameState>());
  }

  /// 札の名前から、分野の札の番号を引く(0 は試合日と提携)。
  static int _tabFor(String card, GameState game) {
    int of(OwnerWorkCategory c) => OwnerWorkCategory.values.indexOf(c) + 1;
    switch (card) {
      case TodoPlaces.cardFans:
        return of(OwnerWorkCategory.fans);
      case TodoPlaces.cardFinanceWorks:
        return of(OwnerWorkCategory.finance);
      case TodoPlaces.cardCommunityWorks:
        return of(OwnerWorkCategory.community);
      case TodoPlaces.cardWorks:
        // いま打てる手がある最初の分野(広報は月に1回で別扱い)。
        for (final c in OwnerWorkCategory.values) {
          if (c == OwnerWorkCategory.fans) continue;
          if (ownerWorks
              .any((w) => w.category == c && game.canDoOwnerWork(w))) {
            return of(c);
          }
        }
        return of(OwnerWorkCategory.sales);
      default:
        return 0;
    }
  }

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
                        '資金 ${formatMoney(save.budget)}。広報・ファンの手は月に1回(どれか1つ)、ほかの手は1シーズンに1回ずつ打てます。${game.fanWorkDoneThisMonth ? '今月の広報は済んでいます。' : '今月の広報はまだです。'}',
                        'Funds ${formatMoney(save.budget)}. One fans & PR move a month; every other move once per season. ${game.fanWorkDoneThisMonth ? 'This month\'s PR move is done.' : 'This month\'s PR move is still open.'}'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (var i = 0; i <= OwnerWorkCategory.values.length; i++)
                        ChoiceChip(
                          key: ValueKey('owner-work-chip-$i'),
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
    // 押せない理由。済み・赤字のときだけ、はボタンの字に出ているので、
    // 字が「実行」のまま灰色になる資金不足だけを下に出す。
    final short = game.scaledMoney(work.cost) - (game.save?.budget ?? 0);
    final String? blocked =
        !can && !done && !(work.onlyInRed && (game.save?.budget ?? 0) >= 0)
            ? (short > 0 ? fundsShortReason(short) : null)
            : null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
        Row(
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
              key: ValueKey('owner-work-do-${work.id}'),
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
                  ? (work.monthly
                      ? Tr.pick('今月済み', 'Done this month')
                      : Tr.pick('今季済み', 'Done'))
                  : work.onlyInRed && !can
                      ? Tr.pick('赤字のとき', 'When in the red')
                      : Tr.pick('実行', 'Do it')),
            ),
          ],
        ),
            DisabledReason(blocked, alignEnd: true),
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
      // クラブ > 施設の「系列クラブ」(選手の貸し借り)と紛れない名前に。
      title: Tr.pick('友好提携クラブ: 2つの期待が上がる', 'Friendship partner: lifts both expectations'),
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
                    // 資金が足りないときは、ボタンの下に足りない額を出す
                    // (ボタンの字は費用のままで、なぜ灰色かが分からなかった)。
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                    FilledButton(
                      key: ValueKey('promo-set-${p.id}'),
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
                        if (game.scaledMoney(p.cost) > budget)
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 200),
                            child: DisabledReason(
                                fundsShortReason(
                                    game.scaledMoney(p.cost) - budget),
                                alignEnd: true),
                          ),
                      ],
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
