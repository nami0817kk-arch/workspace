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

/// オーナーの仕事。資金と2つの期待を動かす手を、**いま打てるものから**並べる。
/// 広報・ファンの手は月に1回(どれか1つ)、ほかの手は1シーズンに1回。
/// 何かを得て何かを払う。
///
/// 2026-11-25 に作り直した。以前は分野ごとの札(6つ)に33件の手と試合日の
/// イベント8つがあり、「オーナーの仕事が多くて分かりにくい」と言われた。
/// 手を12件に減らし、札をやめて1本の一覧に。試合日のイベントは節ごとに
/// 選ぶのをやめ、「続ける」の設定1つにした。
class OwnerWorkScreen extends StatefulWidget {
  const OwnerWorkScreen({super.key, this.initialCard});

  /// 最初に見せる札([TodoPlaces.cardMatchday] など)。単独で開くとき用。
  final String? initialCard;

  @override
  State<OwnerWorkScreen> createState() => _OwnerWorkScreenState();
}

class _OwnerWorkScreenState extends State<OwnerWorkScreen> {
  ShellNav? _nav;
  int _seenSerial = 0;

  /// 「やること」の行・ほかの画面の入口から来たときに見せる場所。分野ごとに、
  /// その分野の最初の手の札に付ける。
  final _categoryKeys = {
    for (final c in OwnerWorkCategory.values) c: GlobalKey(),
  };
  final _matchdayKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final card = widget.initialCard;
    if (card != null) _reveal(card);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nav = ShellNav.maybeOf(context);
    if (nav != _nav) {
      _nav?.removeListener(_fromNav);
      _nav = nav?..addListener(_fromNav);
      _fromNav();
    }
  }

  @override
  void dispose() {
    _nav?.removeListener(_fromNav);
    super.dispose();
  }

  /// 「やること」の行から、札を選ばれた。
  void _fromNav() {
    final nav = _nav;
    if (!mounted || nav == null || nav.cardSerial == _seenSerial) return;
    _seenSerial = nav.cardSerial;
    final card = nav.card;
    if (card == null || nav.menu != TodoMenu.ownerRoom) return;
    _reveal(card);
  }

  /// 札の名前に合う場所まで送る(試合日のイベント・分野の手)。「打てる手」は
  /// 先頭の「いま打てる手」のままでよい。
  void _reveal(String card) {
    final key = switch (card) {
      TodoPlaces.cardMatchday => _matchdayKey,
      TodoPlaces.cardFans => _categoryKeys[OwnerWorkCategory.fans],
      TodoPlaces.cardFinanceWorks => _categoryKeys[OwnerWorkCategory.finance],
      TodoPlaces.cardCommunityWorks =>
        _categoryKeys[OwnerWorkCategory.community],
      _ => null,
    };
    if (key == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = key.currentContext;
      if (c != null && c.mounted) {
        Scrollable.ensureVisible(c, alignment: 0.05);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final save = game.save;
    // 資金がマイナスでないときは、危機の手は出さない(押せない札が並ぶだけ)。
    final inRed = (save?.budget ?? 0) < 0;
    final works = [
      // 月に1回の広報を先に(いちばん回数の多い手)。
      ...ownerWorks.where((w) => w.monthly),
      ...ownerWorks.where((w) => !w.monthly && (!w.onlyInRed || inRed)),
    ];
    final open = [for (final w in works) if (game.canDoOwnerWork(w)) w];
    final rest = [for (final w in works) if (!game.canDoOwnerWork(w)) w];
    // 分野ごとの最初の1枚(入口から来たときに、そこまで送る)。
    final firstOf = <OwnerWork, GlobalKey>{};
    for (final w in [...open, ...rest]) {
      if (firstOf.keys.every((f) => f.category != w.category)) {
        firstOf[w] = _categoryKeys[w.category]!;
      }
    }
    Widget tile(OwnerWork w) =>
        _WorkTile(key: firstOf[w] ?? ValueKey('owner-work-${w.id}'), work: w);
    return Scaffold(
      appBar: AppBar(title: Text(Tr.pick('オーナーの仕事', 'Owner\'s work'))),
      body: save == null
          ? const SizedBox.shrink()
          : ResponsiveBody(
              // 札の数は少ないので、全部を作っておく(入口から来たときに、
              // まだ作られていない札へは送れない)。
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    Tr.pick(
                        '資金 ${formatMoney(save.budget)}。広報・ファンの手は月に1回(どれか1つ)、ほかの手は1シーズンに1回ずつ打てます。',
                        'Funds ${formatMoney(save.budget)}. One fans & PR move a month; every other move once per season.'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 6),
                  _SectionTitle(
                    key: const ValueKey('owner-work-open'),
                    text: Tr.pick('いま打てる手 ${open.length}件',
                        'Moves you can make now: ${open.length}'),
                  ),
                  if (open.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        Tr.pick('いま打てる手はありません。来月・来季にまた打てます。',
                            'Nothing to do right now. More moves open next month and next season.'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  for (final w in open) tile(w),
                  _PromoCard(key: _matchdayKey),
                  if (rest.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _SectionTitle(
                      key: const ValueKey('owner-work-rest'),
                      text: Tr.pick('済み・まだ打てない手 ${rest.length}件',
                          'Done or not yet possible: ${rest.length}'),
                    ),
                    for (final w in rest) tile(w),
                  ],
                  // 友好提携は 2026-11-25 に新しくは結べなくした(提携クラブは
                  // クラブ > 施設の「系列クラブ」1つに)。結んでいる古いセーブ
                  // だけ、解消できるように残す。
                  if (game.partnerClub != null) const _LegacyPartnerCard(),
                ],
              ),
              ),
            ),
    );
  }
}

/// 一覧の中の小見出し。
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 6, 2, 4),
        child: Text(
          text,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      );
}

class _WorkTile extends StatelessWidget {
  const _WorkTile({super.key, required this.work});

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
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
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
                  // 説明は1行に(札を低くして、打てる手を1画面に多く並べる)。
                  Text(work.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

/// 友好提携(古いセーブだけ)。毎季の提携費を払う代わりに、2つの期待が
/// 少し上がる。新しくは結べない(提携クラブは系列クラブ1つにした)。
class _LegacyPartnerCard extends StatelessWidget {
  const _LegacyPartnerCard();

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final partner = game.partnerClub;
    if (partner == null) return const SizedBox.shrink();
    return FmPanel(
      title: Tr.pick('友好提携(以前の契約)', 'Friendship partner (old deal)'),
      margin: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              Tr.pick(
                  '${partner.name}と提携中。毎季${formatMoney(game.partnerSeasonCost)}で、2つの期待が+${PartnerClubEngine.supportersBonus}ずつ。新しい提携は「クラブ > 施設」の系列クラブで結びます。',
                  'Partnered with ${partner.name}: ${formatMoney(game.partnerSeasonCost)} a season for +${PartnerClubEngine.supportersBonus} to both expectations. New partnerships are made as a feeder club under Club > Facilities.'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          TextButton(
            onPressed: () => context.read<GameState>().clearPartnerClub(),
            child: Text(Tr.pick('解消', 'End')),
          ),
        ],
      ),
    );
  }
}

/// 試合日のイベント。毎節の観客収入とサポーターの期待を動かす。
///
/// 一度「続ける」に決めると、毎節そのイベントを打つ(2026-11-25)。以前は
/// 節ごとに8つから選び直す手間があり、オーナーの仕事を増やしていた。
class _PromoCard extends StatelessWidget {
  const _PromoCard({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final active = game.activeMatchdayPromo;
    final keep = game.matchdayPromoKeep;
    final budget = game.save?.budget ?? 0;
    return FmPanel(
      title: Tr.pick('試合日のイベント(毎節続ける)', 'Matchday event (every game)'),
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  keep != null
                      ? Tr.pick(
                          '「${keep.title}」を毎節続けています。${active == null ? '次の節は資金が足りず、打ちません。' : ''}',
                          'Running "${keep.title}" every game.${active == null ? ' Not enough funds for the next one.' : ''}')
                      : active != null
                          ? Tr.pick('次の節だけ「${active.title}」に決めてあります。',
                              'Next game only: ${active.title}.')
                          : Tr.pick('決めていません。選ぶと毎節続けます(費用は節ごと)。',
                              'None set. Pick one and it runs every game (paid per game).'),
                  key: const ValueKey('promo-status'),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              if (keep != null)
                TextButton(
                  key: const ValueKey('promo-stop'),
                  onPressed: () =>
                      context.read<GameState>().setMatchdayPromoKeep(null),
                  child: Text(Tr.pick('やめる', 'Stop')),
                )
              else if (active != null)
                TextButton(
                  onPressed: () =>
                      context.read<GameState>().cancelMatchdayPromo(),
                  child: Text(Tr.pick('取り消す(費用は戻る)', 'Cancel (refund)')),
                ),
            ],
          ),
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
                          const SizedBox(height: 2),
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
                      onPressed: keep?.id == p.id ||
                              game.scaledMoney(p.cost) > budget
                          ? null
                          : () => runUndoable(
                                context,
                                action: () => context
                                    .read<GameState>()
                                    .setMatchdayPromoKeep(p.id),
                                done: Tr.pick('試合日は毎節「${p.title}」にします',
                                    'Every matchday: ${p.title}'),
                              ),
                      child: Text(keep?.id == p.id
                          ? Tr.pick('続けています', 'Running')
                          : p.cost == 0
                              ? Tr.pick('続ける(無料)', 'Run it (free)')
                              : Tr.pick(
                                  '続ける(1節${formatMoney(game.scaledMoney(p.cost))})',
                                  'Run it (${formatMoney(game.scaledMoney(p.cost))}/game)')),
                    ),
                        if (keep?.id != p.id &&
                            game.scaledMoney(p.cost) > budget)
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
