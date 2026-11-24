import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/proposal_engine.dart';
import '../l10n/tr.dart';
import '../logic/contract_board_engine.dart';
import '../logic/contract_engine.dart';
import '../logic/squad_registration_engine.dart';
import '../models/player.dart';
import '../models/team.dart';
import '../services/feedback_service.dart';
import '../state/game_state.dart';
import '../theme/semantic_colors.dart';
import 'contract_offer_screen.dart';
import 'player_actions.dart';
import '../widgets/fm_panel.dart';
import '../widgets/responsive_body.dart';
import '../logic/economy_scale.dart';
import '../widgets/disabled_reason.dart';

/// 登録と契約。年俸の合計と給与の枠・更新の時期の選手・全員の契約の一覧
/// (残りの短い順)・仮契約。
///
/// 2026-11-25 に FM の「契約」の画面に寄せた: 全員の契約を残りの短い順に
/// 並べ、条項(延長オプション・リリース条項・出来高・昇給・降格/昇格)と
/// 状態(延長しない・出ていく)を1行に出し、行から更新・操作を押せる。
/// 国の登録の決まりは「登録ルール」のタブへ移した。
class ContractBoardScreen extends StatelessWidget {
  const ContractBoardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final save = game.save;
    return Scaffold(
      appBar: AppBar(title: Text(Tr.pick('登録と契約', 'Registration & contracts'))),
      body: save == null
          ? const SizedBox.shrink()
          : ResponsiveBody(child: _body(context, game)),
    );
  }

  /// 契約の条項を短く並べた字(無ければ空)。
  static String clauseSummary(GameState game, Player p) {
    final parts = <String>[
      if (p.contractOption) Tr.pick('延長OP', '+1yr option'),
      if (game.releaseClauseOf(p) != null)
        Tr.pick('条項${formatMoney(game.releaseClauseOf(p)!)}',
            'RC ${formatMoney(game.releaseClauseOf(p)!)}'),
      if (p.goalBonus > 0)
        Tr.pick('出来高${formatMoney(p.goalBonus)}/点',
            'Goal bonus ${formatMoney(p.goalBonus)}'),
      if (p.raisePct > 0)
        Tr.pick('毎年+${p.raisePct}%', '+${p.raisePct}%/yr'),
      if (p.relegationCutPct != null)
        Tr.pick('降格-${p.relegationCutPct}%', 'Releg. -${p.relegationCutPct}%'),
      if (p.promotionRisePct > 0)
        Tr.pick('昇格+${p.promotionRisePct}%', 'Prom. +${p.promotionRisePct}%'),
    ];
    return parts.join(Tr.pick('・', ', '));
  }

  Widget _body(BuildContext context, GameState game) {
    final team = game.userTeam;
    final expiring = ContractBoardEngine.expiring(team);
    final theme = Theme.of(context);
    int cost(Player p) =>
        ContractEngine.renewalCost(p) + ContractEngine.signingBonusFor(p);
    const small = TextStyle(fontSize: 12);
    final subtle = SemanticColors.subtleText(context);
    bool proposed(Player p) => game.save!.proposals
        .any((x) => x.kind == ProposalKind.renew && x.playerId == p.id);
    // 更新が押せない理由(押せるなら null)。ボタンの有効・無効もこれで決める
    // (条件を2か所に持たない)。
    String? renewBlock(Player p) {
      final block = game.renewalBlockReason(p);
      if (block != null) return block;
      final short = cost(p) - game.save!.budget;
      return short > 0 ? fundsShortReason(short) : null;
    }

    return ListView(
      padding: const EdgeInsets.all(10),
      children: [
        _summary(context, game, team),
        // 更新の時期の選手を先頭に(2026-11-24)。「やること」の行やタブの印から
        // 来たとき、開いてすぐ見えるように。
        FmPanel(
          title: Tr.pick('更新の時期の選手(${expiring.length})',
              'Due for renewal (${expiring.length})'),
          padding: EdgeInsets.zero,
          child: expiring.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                      Tr.pick('いま更新が要る選手はいません。',
                          'No one needs renewing right now.'),
                      style: theme.textTheme.bodySmall),
                )
              : Column(
                  children: [
                    for (final p in expiring)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                                color: theme.colorScheme.outlineVariant),
                          ),
                        ),
                        // 更新が押せない行だけ、行の下に理由を出す(応じない
                        // 選手・資金不足)。理由は選手ごとに違うので行ごと。
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: Text(
                                      // 経営の概要の「監督からの提案」に同じ
                                      // 選手が出ているときは、ここにもそう書く。
                                      Tr.pick(
                                          '${p.name}(${p.position.label}・${p.age}歳・総合${p.overall})${proposed(p) ? '・監督が更新を提案中' : ''}',
                                          '${p.name} (${p.position.label}, ${p.age}, OVR ${p.overall})${proposed(p) ? ' • manager proposes renewal' : ''}'),
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(ContractEngine.contractLabel(p),
                                      style: small),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                      Tr.pick(
                                          '年俸 ${formatMoney(annualFromWeekly(p.wage))}',
                                          'Salary ${formatMoney(annualFromWeekly(p.wage))}'),
                                      style: small),
                                ),
                                if (game.canExerciseContractOption(p.id)) ...[
                                  OutlinedButton(
                                    onPressed: () async {
                                      FeedbackService.tap();
                                      await context
                                          .read<GameState>()
                                          .exerciseContractOption(p.id);
                                    },
                                    child:
                                        Text(Tr.pick('オプション行使', 'Take option')),
                                  ),
                                  const SizedBox(width: 4),
                                ],
                                FilledButton(
                                  key: ValueKey('board-renew-${p.id}'),
                                  onPressed: renewBlock(p) == null
                                      ? () {
                                          FeedbackService.tap();
                                          openContractOffer(context,
                                              player: p,
                                              kind: ContractKind.renewal);
                                        }
                                      : null,
                                  child: Text(Tr.pick(
                                      '交渉する(${formatMoney(cost(p))}〜)',
                                      'Negotiate (${formatMoney(cost(p))}+)')),
                                ),
                              ],
                            ),
                            DisabledReason(renewBlock(p),
                                alignEnd: true,
                                padding: const EdgeInsets.only(bottom: 2)),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        _allContracts(context, game, team,
            skip: {for (final p in expiring) p.id}),
        _preContractPanel(context, game),
        Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 8),
          child: Text(
            Tr.pick('国の登録の決まり(何人まで登録できるか)は「登録ルール」のタブにあります。',
                'How many players you may register is on the "Rules" tab.'),
            style: TextStyle(fontSize: 11, color: subtle),
          ),
        ),
      ],
    );
  }

  /// 年俸の合計と給与の枠、契約の残りごとの人数。
  Widget _summary(BuildContext context, GameState game, Team team) {
    final theme = Theme.of(context);
    final players = ContractBoardEngine.weeklyWages(team);
    final bill = game.weeklyWageBill;
    final cap = game.wageBudgetCap;
    final room = cap - bill;
    final byYears = ContractBoardEngine.byYearsRemaining(team);
    final clauses = team.players
        .where((p) => !p.isLoan && game.releaseClauseOf(p) != null)
        .length;
    Widget tile(String label, String value, {Color? color, Key? key}) =>
        Container(
          key: key,
          constraints: const BoxConstraints(minWidth: 104),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      color: SemanticColors.subtleText(context))),
              Text(value,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: color ?? theme.colorScheme.onSurface)),
            ],
          ),
        );
    return FmPanel(
      title: Tr.pick('契約のまとめ', 'Contracts at a glance'),
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          tile(Tr.pick('選手の年俸の合計', 'Player salaries'),
              formatMoney(annualFromWeekly(players))),
          tile(Tr.pick('スタッフを含む合計', 'Incl. staff'),
              formatMoney(annualFromWeekly(bill))),
          tile(
            Tr.pick('理事会の給与の枠', 'Board wage cap'),
            cap > 0 ? formatMoney(annualFromWeekly(cap)) : '—',
          ),
          tile(
            Tr.pick('枠の残り', 'Left under the cap'),
            cap > 0
                ? (room >= 0
                    ? formatMoney(annualFromWeekly(room))
                    : Tr.pick('${formatMoney(annualFromWeekly(-room))}超過',
                        '${formatMoney(annualFromWeekly(-room))} over'))
                : '—',
            key: const ValueKey('board-cap-room'),
            color: cap > 0 && room < 0
                ? theme.colorScheme.error
                : SemanticColors.positive(context),
          ),
          tile(Tr.pick('今季で切れる', 'End this season'),
              Tr.pick('${byYears[0]! + byYears[1]!}人', '${byYears[0]! + byYears[1]!}'),
              color: byYears[1]! > 0
                  ? SemanticColors.ink(context, Colors.orange)
                  : null),
          tile(Tr.pick('来季で切れる', 'End next season'),
              Tr.pick('${byYears[2]}人', '${byYears[2]}')),
          tile(Tr.pick('3年以上', '3+ years'),
              Tr.pick('${byYears[3]}人', '${byYears[3]}')),
          tile(Tr.pick('リリース条項付き', 'With a release clause'),
              Tr.pick('$clauses人', '$clauses')),
          tile(
              Tr.pick('22歳以上の登録', 'Registered 22+'),
              '${SquadRegistration.seniorCount(team)}/${SquadRegistration.seniorLimit}'),
        ],
      ),
    );
  }

  /// ほかの選手の契約を、残りの短い順に(更新の時期の選手は上の札に出して
  /// いるので除く)。行を押すと選手の詳しい画面、「…」で操作。
  Widget _allContracts(BuildContext context, GameState game, Team team,
      {Set<String> skip = const {}}) {
    final theme = Theme.of(context);
    final subtle = SemanticColors.subtleText(context);
    final size = MediaQuery.sizeOf(context);
    // 横画面は行を少し低く(全員を並べても縦に長くなりすぎないように)。
    final wide = size.width > size.height;
    final rowHeight = wide ? 34.0 : 48.0;
    final list = [
      for (final p in team.players)
        if (!skip.contains(p.id)) p
    ]..sort((a, b) {
        // 借りている選手は契約がこちらに無いので最後に回す。
        if (a.isLoan != b.isLoan) return a.isLoan ? 1 : -1;
        final c = a.contractEndYear.compareTo(b.contractEndYear);
        return c != 0 ? c : b.overall.compareTo(a.overall);
      });
    final head =
        TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: subtle);
    const cell = TextStyle(fontSize: 12);
    String status(Player p) {
      if (p.isLoan) return Tr.pick('借りている', 'On loan here');
      if (game.outgoingPreContracts.any((c) => c.playerId == p.id)) {
        return Tr.pick('仮契約で出ていく', 'Leaving on a pre-contract');
      }
      if (p.refusesRenewal) return Tr.pick('延長しない', 'Will not renew');
      if (p.isTransferListed) return Tr.pick('移籍リスト', 'Transfer listed');
      if (p.isLoanedOut) return Tr.pick('貸し出し中', 'Out on loan');
      if (p.wantsTransfer) return Tr.pick('移籍を希望', 'Wants to leave');
      return '';
    }

    return FmPanel(
      title: Tr.pick('そのほかの契約(残りの短い順)', 'Other contracts (soonest first)'),
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Container(
            color: theme.colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Row(children: [
              Expanded(flex: 5, child: Text(Tr.pick('名前', 'Name'), style: head)),
              SizedBox(
                  width: 64,
                  child: Text(Tr.pick('年俸', 'Salary'),
                      textAlign: TextAlign.right, style: head)),
              const SizedBox(width: 8),
              SizedBox(
                  width: 44,
                  child: Text(Tr.pick('満了', 'Ends'),
                      textAlign: TextAlign.center, style: head)),
              Expanded(
                  flex: 5,
                  child: Text(Tr.pick('条項', 'Clauses'), style: head)),
              Expanded(
                  flex: 3,
                  child: Text(Tr.pick('状態', 'Status'), style: head)),
              const SizedBox(width: 48),
            ]),
          ),
          for (final p in list)
            InkWell(
              key: ValueKey('board-row-${p.id}'),
              onTap: () => openPlayerDetail(context, p.id),
              child: Container(
                // 押せる行は指の大きさにそろえる。
                constraints: BoxConstraints(minHeight: rowHeight),
                padding: const EdgeInsets.only(left: 10),
                decoration: BoxDecoration(
                  border: Border(
                      bottom:
                          BorderSide(color: theme.colorScheme.outlineVariant)),
                ),
                child: Row(children: [
                  Expanded(
                    flex: 5,
                    child: Text(
                      Tr.pick(
                          '${p.name}(${p.position.label}・${p.age})',
                          '${p.name} (${p.position.label}, ${p.age})'),
                      style: cell.copyWith(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(
                    width: 64,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(formatMoney(annualFromWeekly(p.wage)),
                          style: cell),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 44,
                    child: Text(
                      p.isLoan
                          ? Tr.pick('借', 'Loan')
                          : ContractEngine.untilTinyLabel(p.contractEndYear),
                      textAlign: TextAlign.center,
                      style: cell.copyWith(
                          color: !p.isLoan && p.contractYearsRemaining <= 1
                              ? SemanticColors.ink(context, Colors.orange)
                              : null),
                    ),
                  ),
                  Expanded(
                    flex: 5,
                    child: Text(clauseSummary(game, p),
                        style: TextStyle(fontSize: 11, color: subtle),
                        maxLines: wide ? 1 : 2,
                        overflow: TextOverflow.ellipsis),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(status(p),
                        style: TextStyle(
                            fontSize: 11,
                            color: p.refusesRenewal || p.wantsTransfer
                                ? theme.colorScheme.error
                                : subtle),
                        overflow: TextOverflow.ellipsis),
                  ),
                  SizedBox(
                    width: 48,
                    child: IconButton(
                      key: ValueKey('board-menu-${p.id}'),
                      visualDensity:
                          wide ? VisualDensity.compact : VisualDensity.standard,
                      iconSize: 18,
                      tooltip: Tr.pick('操作', 'Actions'),
                      icon: const Icon(Icons.more_horiz),
                      onPressed: () => showPlayerActions(context, p),
                    ),
                  ),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  /// 仮契約(ボスマン)。結んだもの(加入・退団・他のクラブ同士)と、
  /// 1月1日〜6月30日に結べる相手。
  Widget _preContractPanel(BuildContext context, GameState game) {
    final theme = Theme.of(context);
    const small = TextStyle(fontSize: 12);
    final incoming = game.incomingPreContracts;
    final outgoing = game.outgoingPreContracts;
    final userId = game.save!.userTeamId;
    final others = [
      for (final c in game.preContracts)
        if (c.toClubId != userId && c.fromClubId != userId) c,
    ];
    final open = game.preContractWindowOpen;
    final targets = open
        ? game.preContractTargets()
        : const <({Player player, Team team})>[];
    Widget line(String text, {Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          child: Text(text, style: small.copyWith(color: color)),
        );
    return FmPanel(
      title:
          Tr.pick('仮契約(7月1日に移籍金なしで移る)', 'Pre-contracts (free moves on 1 Jul)'),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          line(Tr.pick(
              '契約が今シーズン末(${Player.contractClockYear}年6月30日)で切れる選手とは、1月1日から仮契約を結べます。他のクラブも同じことをします。',
              'From 1 Jan you can agree terms with players whose deals end on 30 Jun ${Player.contractClockYear}. Other clubs do the same.')),
          if (incoming.isNotEmpty) ...[
            line(Tr.pick('加入する選手', 'Joining'),
                color: theme.colorScheme.primary),
            for (final c in incoming)
              line(Tr.pick(
                  '${c.playerName}(${c.fromClubName}から)・年俸${formatMoney(annualFromWeekly(c.wage))}・${ContractEngine.untilLabel(c.endYear)}${c.option ? '・延長オプション付き' : ''}',
                  '${c.playerName} (from ${c.fromClubName}), salary ${formatMoney(annualFromWeekly(c.wage))}, ${ContractEngine.untilLabel(c.endYear)}${c.option ? ', 1-year option' : ''}')),
          ],
          if (outgoing.isNotEmpty) ...[
            line(Tr.pick('出ていく選手', 'Leaving'), color: theme.colorScheme.error),
            for (final c in outgoing)
              line(Tr.pick(
                  '${c.playerName} → ${c.toClubName}(7月1日。それまでに売れば移籍金が入る)',
                  '${c.playerName} to ${c.toClubName} (1 Jul; sell before then for a fee)')),
          ],
          if (others.isNotEmpty) ...[
            line(Tr.pick('他のクラブ同士', 'Between other clubs'),
                color: theme.colorScheme.secondary),
            // 他のクラブ同士は参考なので10件まで(縦に長くしない)。
            for (final c in others.take(10))
              line(Tr.pick(
                  '${c.playerName}: ${c.fromClubName} → ${c.toClubName}',
                  '${c.playerName}: ${c.fromClubName} to ${c.toClubName}')),
            if (others.length > 10)
              line(Tr.pick('ほか${others.length - 10}件',
                  '${others.length - 10} more')),
          ],
          if (!open)
            line(Tr.pick('いまは仮契約を結べる時期ではありません(1月1日〜6月30日)。',
                'Pre-contracts can only be agreed from 1 Jan to 30 Jun.'))
          else ...[
            line(
                Tr.pick('結べる選手(${targets.length})',
                    'Available (${targets.length})'),
                color: theme.colorScheme.primary),
            if (targets.isEmpty)
              line(Tr.pick('いま結べる選手はいません。', 'No one is available right now.')),
            // 結べる相手は12人まで(総合力の高い順に並んでいる)。
            for (final t in targets.take(12))
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        Tr.pick(
                            '${t.player.name}(${t.team.name}・${t.player.position.label}・${t.player.age}歳・総合${t.player.overall})',
                            '${t.player.name} (${t.team.name}, ${t.player.position.label}, ${t.player.age}, OVR ${t.player.overall})'),
                        style: small,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      tooltip: Tr.pick('詳しく見る', 'View profile'),
                      icon: const Icon(Icons.person_outline, size: 18),
                      onPressed: () => openPlayerDetail(context, t.player.id),
                    ),
                    OutlinedButton(
                      onPressed: () => openContractOffer(context,
                          player: t.player,
                          kind: ContractKind.preContract,
                          fromClubName: t.team.name),
                      child: Text(Tr.pick('仮契約', 'Pre-sign')),
                    ),
                  ],
                ),
              ),
          ],
          if (open && targets.length > 12)
            line(Tr.pick('ほか${targets.length - 12}人(総合力の高い順に12人まで)',
                '${targets.length - 12} more (top 12 by overall shown)')),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}
