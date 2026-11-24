import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/contract_engine.dart';
import '../logic/economy_scale.dart';
import '../logic/transfer_talk_engine.dart';
import '../logic/transfer_window.dart';
import '../models/player.dart';
import '../models/transfer_talk.dart';
import '../services/feedback_service.dart';
import '../state/game_state.dart';
import '../theme/semantic_colors.dart';
import '../widgets/disabled_reason.dart';
import 'contract_offer_screen.dart';
import 'player_compare_screen.dart';
import 'player_detail_screen.dart';
import 'transfer_actions.dart';

/// 選手1人への操作の一覧(FM の選手の「操作」ボタン)。
///
/// 選手の詳しい画面の上の「操作」と、スカッドの表の行の「…」から同じ
/// 一覧を開く(2026-11-25)。以前は詳しい画面の「契約」のタブに7つの
/// ボタンが縦に並び、スカッドからは更新しか押せなかった。
///
/// 押せない操作も並べ、下に理由を出す(何が足りないかが分かるように)。
Future<void> showPlayerActions(
  BuildContext context,
  Player p, {
  bool showOpenDetail = true,
  void Function(Player)? onAddToCompare,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 620),
    builder: (sheet) => _PlayerActionsSheet(
      player: p,
      hostContext: context,
      showOpenDetail: showOpenDetail,
      onAddToCompare: onAddToCompare,
    ),
  );
}

/// 選手の詳しい画面を開く(自クラブでも他クラブでも)。
Future<void> openPlayerDetail(BuildContext context, String playerId) =>
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => PlayerDetailScreen(playerId: playerId)));

/// 比べる相手を自クラブの選手から選んで、比較の画面を開く。
Future<void> pickAndCompare(BuildContext context, Player p) async {
  final game = context.read<GameState>();
  final others = [
    for (final q in game.userTeam.players)
      if (q.id != p.id) q
  ]..sort((a, b) {
      // 同じ大分類のポジションを先に、その中は総合力の高い順。
      final ga = a.position.group == p.position.group ? 0 : 1;
      final gb = b.position.group == p.position.group ? 0 : 1;
      if (ga != gb) return ga.compareTo(gb);
      return b.overall.compareTo(a.overall);
    });
  final picked = await showDialog<Player>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(Tr.pick('${p.name}と比べる選手', 'Compare ${p.name} with')),
      children: [
        SizedBox(
          width: 420,
          height: 300,
          child: ListView(
            children: [
              for (final q in others)
                ListTile(
                  dense: true,
                  title: Text(q.name, overflow: TextOverflow.ellipsis),
                  subtitle: Text(Tr.pick(
                      '${q.position.label}・${q.age}歳・総合${q.overall}',
                      '${q.position.label} • ${q.age} • OVR ${q.overall}')),
                  onTap: () => Navigator.pop(ctx, q),
                ),
            ],
          ),
        ),
      ],
    ),
  );
  if (picked == null || !context.mounted) return;
  await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) =>
          PlayerCompareScreen(playerAId: p.id, playerBId: picked.id)));
}

class _PlayerActionsSheet extends StatelessWidget {
  const _PlayerActionsSheet({
    required this.player,
    required this.hostContext,
    required this.showOpenDetail,
    required this.onAddToCompare,
  });

  final Player player;

  /// 一覧を開いた画面。一覧を閉じたあとの操作(画面を開く・確かめる)に使う。
  final BuildContext hostContext;
  final bool showOpenDetail;
  final void Function(Player)? onAddToCompare;

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final p = game.anyPlayerById(player.id) ?? player;
    final mine = game.isMyPlayer(p.id);
    final items = <Widget>[];

    void add({
      required IconData icon,
      required String label,
      String? note,
      String? blocked,
      Key? key,
      required VoidCallback onTap,
    }) {
      items.add(ListTile(
        key: key,
        dense: true,
        leading: Icon(icon),
        title: Text(label),
        subtitle: blocked != null
            ? DisabledReason(blocked, padding: EdgeInsets.zero)
            : (note == null
                ? null
                : Text(note,
                    style: TextStyle(
                        fontSize: 12,
                        color: SemanticColors.subtleText(context)))),
        enabled: blocked == null,
        onTap: blocked != null
            ? null
            : () {
                Navigator.pop(context);
                onTap();
              },
      ));
    }

    if (showOpenDetail) {
      add(
        icon: Icons.person_outline,
        label: Tr.pick('詳しく見る', 'View profile'),
        onTap: () => openPlayerDetail(hostContext, p.id),
      );
    }

    if (mine && p.isLoan) {
      final fee = p.loanBuyOptionFee;
      if (fee != null) {
        add(
          icon: Icons.shopping_cart_outlined,
          label: Tr.pick('買取オプションを行使する(${formatMoney(fee)})',
              'Trigger the buy option (${formatMoney(fee)})'),
          blocked: game.save!.budget < fee
              ? fundsShortReason(fee - game.save!.budget)
              : null,
          onTap: () => exerciseBuyOption(hostContext, p.id),
        );
      } else {
        add(
          icon: Icons.info_outline,
          label: Tr.pick('借りている選手です', 'On loan here'),
          blocked: Tr.pick('ローンで来ている選手は、更新・放出の対象外です(期間の終わりに戻ります)',
              'Players on loan here cannot be renewed or released; they go back when the loan ends'),
          onTap: () {},
        );
      }
    } else if (mine && p.isLoanedOut) {
      add(
        icon: Icons.flight_land,
        label: Tr.pick('冬の窓で呼び戻す', 'Recall him in the winter window'),
        note: p.loanedOutUntil == null
            ? null
            : Tr.pick(
                '${TransferWindowCalendar.formatMonthDay(p.loanedOutUntil!)}に戻ります',
                'Back on ${TransferWindowCalendar.formatMonthDay(p.loanedOutUntil!)}'),
        blocked: !p.loanRecallClause
            ? Tr.pick('呼び戻しの条項を付けずに貸しています',
                'He went out without a recall clause')
            : (game.canRecallLoanedOutPlayer(p)
                ? null
                : Tr.pick('冬の移籍の窓が開いているあいだだけ呼び戻せます',
                    'You can recall him only while the winter window is open')),
        onTap: () async {
          final ok = await game.recallLoanedOutPlayer(p.id);
          ok ? FeedbackService.success() : FeedbackService.error();
        },
      );
    } else if (mine) {
      final negotiation = game.pendingContractNegotiation;
      final talking = negotiation != null && negotiation.playerId == p.id;
      add(
        key: const ValueKey('action-renew'),
        icon: Icons.handshake_outlined,
        label: talking
            ? Tr.pick('契約の交渉を続ける', 'Keep negotiating')
            : Tr.pick('契約の更新を交渉する', 'Negotiate a new contract'),
        note: Tr.pick(
            'いまの契約: ${ContractEngine.contractLabel(p)}・年俸${formatMoney(annualFromWeekly(p.wage))}',
            'Now: ${ContractEngine.contractLabel(p)}, ${formatMoney(annualFromWeekly(p.wage))} a year'),
        blocked: talking ? null : game.renewalBlockReason(p),
        onTap: () =>
            openContractOffer(hostContext, player: p, kind: ContractKind.renewal),
      );
      if (p.contractOption) {
        add(
          icon: Icons.event_repeat,
          label: Tr.pick('延長オプションを行使する', 'Take up the 1-year option'),
          note: Tr.pick(
              '同じ年俸で${ContractEngine.untilLabel(p.contractEndYear + 1)}に延びます',
              'Extends him on the same salary ${ContractEngine.untilLabel(p.contractEndYear + 1)}'),
          blocked: game.canExerciseContractOption(p.id)
              ? null
              : (p.contractEndYear != Player.contractClockYear
                  ? Tr.pick(
                      '行使できるのは、契約が切れるシーズン(${ContractEngine.untilLabel(p.contractEndYear)})に入ってからです',
                      'You can take it up only in the season his deal ends (${ContractEngine.untilLabel(p.contractEndYear)})')
                  : Tr.pick('行使の期限を過ぎました',
                      'The deadline to take it up has passed')),
          onTap: () async {
            final ok = await game.exerciseContractOption(p.id);
            ok ? FeedbackService.success() : FeedbackService.error();
          },
        );
      }
      add(
        key: const ValueKey('action-transfer-list'),
        icon: Icons.sell_outlined,
        label: p.isTransferListed
            ? Tr.pick('移籍リストから外す', 'Take off the transfer list')
            : Tr.pick('移籍リストに載せる', 'Put on the transfer list'),
        note: p.isTransferListed
            ? Tr.pick('届いたオファーは、移籍の「オファー」で受けるか断るかを決めます',
                'Answer offers under "Offers" on the transfers screen')
            : Tr.pick(
                '相場${formatMoney(game.netReleaseValueFor(p.id))}。残りの年数が短いほど安くなります',
                'Worth about ${formatMoney(game.netReleaseValueFor(p.id))}; the less time left on his deal, the lower'),
        onTap: () {
          FeedbackService.tap();
          game.setTransferListed(p.id, !p.isTransferListed);
        },
      );
      final atMin = game.userTeam.players.length <= minSquadSize;
      add(
        icon: Icons.flight_takeoff,
        label: Tr.pick('ほかのクラブへ貸し出す', 'Loan him out'),
        blocked: atMin
            ? Tr.pick('スカッドが下限の$minSquadSize人なので、これ以上減らせません',
                'Your squad is at the minimum of $minSquadSize')
            : (!game.isTransferWindowOpen
                ? game.transferWindowStatusLabel
                : null),
        onTap: () => showLoanOutDialog(hostContext, p.id),
      );
      final cost = game.mutualTerminationCostFor(p.id);
      add(
        icon: Icons.assignment_return_outlined,
        label: Tr.pick('合意して契約を解除する(放出)', 'Release by mutual consent'),
        note: cost == null
            ? null
            : Tr.pick('残りの年俸のうち${formatMoney(cost)}を払い、自由契約にします',
                'Pay ${formatMoney(cost)} of what is left on his deal; he becomes a free agent'),
        blocked: atMin
            ? Tr.pick('スカッドが下限の$minSquadSize人なので、これ以上減らせません',
                'Your squad is at the minimum of $minSquadSize')
            : (cost == null
                ? Tr.pick('いまは解除できません', 'You cannot do that now')
                : null),
        onTap: () => confirmMutualTermination(hostContext, p.id),
      );
    }

    if (!mine) _otherClubActions(context, game, p, add);

    add(
      key: const ValueKey('action-compare'),
      icon: Icons.compare_arrows,
      label: onAddToCompare != null
          ? Tr.pick('比較に入れる', 'Add to comparison')
          : Tr.pick('ほかの選手と比べる', 'Compare with another player'),
      onTap: () => onAddToCompare != null
          ? onAddToCompare!(p)
          : pickAndCompare(hostContext, p),
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text(
                Tr.pick('${p.name}への操作', 'Actions for ${p.name}'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ...items,
          ],
        ),
      ),
    );
  }
}

/// 他のクラブ・所属なしの選手への操作(2026-11-25): 移籍金の提示・
/// ローン・注目・スカウトに見させる。移籍の一覧から詳しい画面を開き、
/// そのまま入札まで進めるように。
void _otherClubActions(
  BuildContext context,
  GameState game,
  Player p,
  void Function({
    required IconData icon,
    required String label,
    String? note,
    String? blocked,
    Key? key,
    required VoidCallback onTap,
  }) add,
) {
  final host = context;
  final squadFull = game.userTeam.players.length >= maxSquadSize;
  final full = squadFull
      ? Tr.pick('スカッドが上限($maxSquadSize人)です。誰かを手放すと獲得できます',
          'Your squad is full ($maxSquadSize). Move someone on first')
      : null;
  final isFree = game.freeAgents.any((q) => q.id == p.id);
  final talk = game.talkFor(p.id);
  if (isFree) {
    add(
      key: const ValueKey('action-free-terms'),
      icon: Icons.handshake_outlined,
      label: Tr.pick('条件を話す(所属なし・移籍金なし)', 'Talk terms (free agent, no fee)'),
      note: Tr.pick(
          '求める年俸 ${formatMoney(annualFromWeekly(p.wage))}。窓の外でも取れます',
          'Wants ${formatMoney(annualFromWeekly(p.wage))} a year. You can sign him outside the window'),
      blocked: full,
      onTap: () => openPersonalTerms(host, p),
    );
  } else if (game.sellingClubOf(p.id) != null ||
      game.transferMarket.any((q) => q.id == p.id)) {
    final approachable = game.transferTargets.any((q) => q.id == p.id);
    if (talk != null) {
      final (label, blocked, onTap) = switch (talk.stage) {
        TransferTalkStage.waiting => (
            Tr.pick('返事を待っている', 'Waiting for their reply'),
            Tr.pick('相手の返事を待っています(「交渉とオファー」に届きます)',
                'The reply will arrive under Talks & offers'),
            () {}
          ),
        TransferTalkStage.countered => (
            Tr.pick('対案に出し直す(${formatMoney(talk.fee)})',
                'Answer their terms (${formatMoney(talk.fee)})'),
            talk.round >= TransferTalkEngine.maxRounds
                ? Tr.pick('提示は使い切りました。「交渉とオファー」で対案をのむか取り下げます',
                    'No bids left. Accept or withdraw under Talks & offers')
                : null,
            () => openTransferBid(host, p, talk: talk)
          ),
        TransferTalkStage.agreed => (
            Tr.pick('選手と条件を話す(クラブと合意済み)', 'Agree personal terms (clubs agreed)'),
            full,
            () => openPersonalTerms(host, p)
          ),
        TransferTalkStage.collapsed => (
            Tr.pick('交渉は決裂しました', 'Talks broke down'),
            Tr.pick('この窓のあいだは申し込めません', 'No more bids this window'),
            () {}
          ),
      };
      add(
          key: const ValueKey('action-talk'),
          icon: Icons.forum_outlined,
          label: label,
          blocked: blocked,
          onTap: onTap);
    } else {
      add(
        key: const ValueKey('action-bid'),
        icon: Icons.gavel,
        label: Tr.pick('移籍金を提示する', 'Make a bid'),
        note: Tr.pick('相場 ${formatMoney(p.marketValue)}・分割・出来高・交換も組めます',
            'Worth ${formatMoney(p.marketValue)}. Instalments, add-ons and swaps available'),
        blocked: !approachable
            ? Tr.pick('いまは申し込めない選手です(相手の人数が足りない・ほかと仮契約済みなど)',
                'He cannot be approached right now (thin squad, pre-contract elsewhere and so on)')
            : !game.isTransferWindowOpen
                ? game.transferWindowStatusLabel
                : full,
        onTap: () => openTransferBid(host, p),
      );
      add(
        key: const ValueKey('action-loan'),
        icon: Icons.swap_horiz,
        label: Tr.pick('ローンで借りる', 'Take him on loan'),
        note: game.isLoanAvailable(p)
            ? Tr.pick('先発ではないので、貸し出しに出してもらいやすい選手です',
                'Not a starter, so his club may well let him go on loan')
            : null,
        blocked: !approachable
            ? Tr.pick('いまは申し込めない選手です', 'He cannot be approached right now')
            : full,
        onTap: () => showAcquireSheet(host, p),
      );
    }
  }
  final watched = game.isWatched(p.id);
  add(
    key: const ValueKey('action-watch'),
    icon: watched ? Icons.star : Icons.star_border,
    label: watched
        ? Tr.pick('注目から外す', 'Remove from shortlist')
        : Tr.pick('注目に入れる', 'Add to shortlist'),
    note: Tr.pick('注目の選手は、どこにいても毎週少しずつ見えてきます',
        'Shortlisted players become a little clearer every week'),
    onTap: () {
      FeedbackService.tap();
      game.toggleWatched(p.id);
    },
  );
  final scouting = game.isScoutingPlayer(p.id);
  final known = game.knowledgeOf(p);
  add(
    key: const ValueKey('action-scout'),
    icon: Icons.travel_explore,
    label: scouting
        ? Tr.pick('スカウトに見させるのをやめる', 'Stop scouting him')
        : Tr.pick('スカウトに見させる', 'Have him scouted'),
    note: Tr.pick(
        'いま$known%見えている。見させると毎週${game.scoutWeeklyGain}%ずつ見えてくる(個別は${GameStateTransfer.scoutPlayerSlots}人まで)',
        '$known% known. Scouting adds ${game.scoutWeeklyGain}% a week (${GameStateTransfer.scoutPlayerSlots} at a time)'),
    blocked: !scouting && known >= 100
        ? Tr.pick('もう全部見えています', 'You already know everything about him')
        : (!scouting && game.scoutedPlayers.length >= GameStateTransfer.scoutPlayerSlots
            ? Tr.pick('個別に見させる枠がいっぱいです(移籍の「スカウトの地域」で外せます)',
                'All scouting slots are in use (free one under Scouting regions)')
            : null),
    onTap: () async {
      final ok = await game.toggleScoutPlayer(p.id);
      ok ? FeedbackService.tap() : FeedbackService.error();
    },
  );
}


/// 合意解除の確認。払う額を見せてから決めさせる。
Future<void> confirmMutualTermination(
    BuildContext context, String playerId) async {
  final gameState = context.read<GameState>();
  final cost = gameState.mutualTerminationCostFor(playerId);
  if (cost == null) return;
  final p = gameState.userTeam.players.firstWhere((p) => p.id == playerId);
  final remaining = ContractEngine.remainingWages(p, gameState.today);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(Tr.pick('合意して契約を解除する', 'Terminate by mutual consent')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(Tr.pick(
              '${p.name}の契約(${ContractEngine.untilLabel(p.contractEndYear)})を解除します。残りの年俸${formatMoney(remaining)}のうち${formatMoney(cost)}を払い、${p.name}は自由契約になります。',
              "${p.name}'s contract (${ContractEngine.untilLabel(p.contractEndYear)}) will be cancelled. You pay ${formatMoney(cost)} of the ${formatMoney(remaining)} left on it, and he becomes a free agent.")),
          // 払えないときは「払って解除する」が灰色になる。足りない額を出す。
          if (gameState.save!.budget < cost)
            DisabledReason(fundsShortReason(cost - gameState.save!.budget),
                padding: const EdgeInsets.only(top: 8)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(Tr.pick('やめる', 'Cancel')),
        ),
        FilledButton(
          onPressed:
              gameState.save!.budget < cost ? null : () => Navigator.pop(ctx, true),
          child: Text(Tr.pick('${formatMoney(cost)}を払って解除する',
              'Pay ${formatMoney(cost)} and terminate')),
        ),
      ],
    ),
  );
  if (ok != true) return;
  final done = await gameState.terminateContractByMutualConsent(playerId);
  // 解除したあとも詳しい画面は開いたまま(所属なしの選手として見える)。
  done ? FeedbackService.success() : FeedbackService.error();
}

/// ローンで来ている選手の買取オプションを行使する。
Future<void> exerciseBuyOption(BuildContext context, String playerId) async {
  final gameState = context.read<GameState>();
  final ok = await gameState.exerciseLoanBuyOption(playerId);
  ok ? FeedbackService.success() : FeedbackService.error();
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? Tr.pick('買取オプションを行使し、完全移籍が成立しました',
                'You triggered the buy option and the permanent transfer went through')
            : Tr.pick(
                '買取オプションを行使できませんでした', 'Could not trigger the buy option')),
      ),
    );
  }
}

/// ほかのクラブへ貸し出す(期間・呼び戻しの条項・出場の約束を選ぶ)。
void showLoanOutDialog(BuildContext context, String playerId) {
  final gameState = context.read<GameState>();
  final theme = gameState.currentLeagueTheme;
  final today = gameState.today;
  final halfOk = TransferWindowCalendar.halfLoanAvailable(today, theme);
  LoanLength length = halfOk ? LoanLength.half : LoanLength.full;
  bool recallClause = false;
  bool guaranteePlayingTime = false;
  final loanPlayer =
      gameState.userTeam.players.where((p) => p.id == playerId).firstOrNull;
  showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(Tr.pick('ローン放出期間', 'Loan length')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(Tr.pick(
                  '${TransferWindowCalendar.formatMonthDay(TransferWindowCalendar.loanEndDate(today, theme, length))}まで他クラブへ貸し出します。期間中の給与は放出先が負担します。',
                  'He goes out on loan until ${TransferWindowCalendar.formatMonthDay(TransferWindowCalendar.loanEndDate(today, theme, length))}. The other club pays his wages while he is there.')),
              if (loanPlayer != null) ...[
                const SizedBox(height: 4),
                Builder(builder: (_) {
                  final fee = gameState.loanOutFeeFor(loanPlayer,
                      guaranteePlayingTime: guaranteePlayingTime);
                  return Text(
                    fee > 0
                        ? Tr.pick('レンタル料${formatMoney(fee)}を受け取ります。',
                            'You receive a loan fee of ${formatMoney(fee)}.')
                        : Tr.pick('レンタル料は受け取れません。', 'You receive no loan fee.'),
                    style: const TextStyle(fontSize: 12),
                  );
                }),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  if (halfOk)
                    ChoiceChip(
                      selected: length == LoanLength.half,
                      onSelected: (_) =>
                          setState(() => length = LoanLength.half),
                      label: Text(Tr.pick('半年(冬の窓まで)', 'Half season')),
                    ),
                  ChoiceChip(
                    selected: length == LoanLength.full,
                    onSelected: (_) => setState(() => length = LoanLength.full),
                    label: Text(Tr.pick('1年(シーズン末まで)', 'Full season')),
                  ),
                ],
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: recallClause,
                onChanged: (v) => setState(() => recallClause = v ?? false),
                title: Text(
                    Tr.pick('冬の窓で呼び戻せる条項を付ける', 'Add a winter recall clause')),
                subtitle: Text(
                  Tr.pick('冬の窓のあいだなら、期間の途中でも戻せる。',
                      'You can bring him back during the winter window, before the loan ends.'),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              // 育成型レンタル。ただ出すか、育てるために出すかの違い。
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: guaranteePlayingTime,
                onChanged: (v) =>
                    setState(() => guaranteePlayingTime = v ?? false),
                title:
                    Text(Tr.pick('出場機会を約束させる', 'Guarantee him playing time')),
                subtitle: Text(
                  Tr.pick('確実に試合に出るので大きく伸びる。代わりにレンタル料は受け取れない。',
                      'He is sure to play and comes on a lot. In return you get no loan fee.'),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(Tr.pick('キャンセル', 'Cancel')),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await gameState.loanOutPlayer(
                playerId,
                length: length,
                guaranteePlayingTime: guaranteePlayingTime,
                recallClause: recallClause,
              );
              ok ? FeedbackService.success() : FeedbackService.error();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(ok
                          ? Tr.pick('ローン放出しました', 'Loan agreed')
                          : Tr.pick('ローン放出できませんでした',
                              'Could not arrange the loan'))),
                );
              }
            },
            child: Text(Tr.pick('放出する', 'Release')),
          ),
        ],
      ),
    ),
  );
}
