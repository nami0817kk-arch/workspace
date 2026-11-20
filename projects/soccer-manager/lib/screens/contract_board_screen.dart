import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/contract_board_engine.dart';
import '../logic/contract_engine.dart';
import '../logic/pre_contract_engine.dart';
import '../logic/squad_registration_engine.dart';
import '../models/player.dart';
import '../models/team.dart';
import '../services/feedback_service.dart';
import '../state/game_state.dart';
import '../widgets/fm_panel.dart';
import '../widgets/responsive_body.dart';
import '../logic/economy_scale.dart';

/// 登録と契約。登録人数・週給の合計・契約の残り年数と、更新の時期の選手。
/// 契約が切れた選手は無償で去るので、主力は早めに更新する。
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

  Widget _body(BuildContext context, GameState game) {
    final team = game.userTeam;
    final room =
        SquadRegistration.seniorLimit - SquadRegistration.seniorCount(team);
    final homegrown = SquadRegistration.homegrownSeniorCount(team);
    final nonHomegrown = SquadRegistration.nonHomegrownSeniorCount(team);
    final byYears = ContractBoardEngine.byYearsRemaining(team);
    final expiring = ContractBoardEngine.expiring(team);
    final theme = Theme.of(context);
    int cost(Player p) =>
        ContractEngine.renewalCost(p) + ContractEngine.signingBonusFor(p);
    const small = TextStyle(fontSize: 12);
    return ListView(
      padding: const EdgeInsets.all(10),
      children: [
        FmPanel(
          title: Tr.pick('登録と契約', 'Registration & contracts'),
          child: Column(
            children: [
              FmRow(
                label: Tr.pick('22歳以上の登録', 'Senior squad'),
                value:
                    '${SquadRegistration.seniorCount(team)}/${SquadRegistration.seniorLimit}',
                valueColor: room < 0 ? theme.colorScheme.error : null,
              ),
              FmRow(
                label: Tr.pick('うち国内育成', 'Homegrown'),
                value: Tr.pick(
                    '$homegrown人(${SquadRegistration.homegrownQuota}人を入れる)',
                    '$homegrown (quota ${SquadRegistration.homegrownQuota})'),
              ),
              FmRow(
                label: Tr.pick('うち国外育成', 'Trained abroad'),
                value: '$nonHomegrown/${SquadRegistration.nonHomegrownLimit}',
                valueColor: nonHomegrown > SquadRegistration.nonHomegrownLimit
                    ? theme.colorScheme.error
                    : null,
              ),
              FmRow(
                label: Tr.pick('在籍の総数(21歳以下を含む)', 'Whole squad (incl. U21)'),
                value: '${team.players.length}/$maxSquadSize',
              ),
              FmRow(
                label: Tr.pick('登録の余裕', 'Room'),
                value: room >= 0
                    ? Tr.pick('あと$room人', '$room more')
                    : Tr.pick('${-room}人超過', '${-room} over'),
              ),
              FmRow(
                label: Tr.pick('年俸の合計', 'Total salaries'),
                value: formatMoney(
                    annualFromWeekly(ContractBoardEngine.weeklyWages(team))),
              ),
              const Divider(),
              FmRow(
                  label: ContractEngine.untilLabel(Player.contractClockYear),
                  value: '${byYears[1]}'),
              FmRow(
                  label:
                      ContractEngine.untilLabel(Player.contractClockYear + 1),
                  value: '${byYears[2]}'),
              FmRow(
                  label: Tr.pick('${Player.contractClockYear + 2}年6月以降',
                      'Jun ${Player.contractClockYear + 2} or later'),
                  value: '${byYears[3]}'),
            ],
          ),
        ),
        _preContractPanel(context, game),
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
                        child: Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Text(
                                Tr.pick(
                                    '${p.name}(${p.position.label}・${p.age}歳)',
                                    '${p.name} (${p.position.label}, ${p.age})'),
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                  Tr.pick(
                                      '総合 ${p.overall}', 'OVR ${p.overall}'),
                                  style: small),
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
                                child: Text(Tr.pick('オプション行使', 'Take option')),
                              ),
                              const SizedBox(width: 4),
                            ],
                            FilledButton(
                              onPressed: game.save!.budget >= cost(p) &&
                                      game.renewalBlockReason(p) == null
                                  ? () async {
                                      FeedbackService.tap();
                                      await context
                                          .read<GameState>()
                                          .renewContract(p.id);
                                    }
                                  : null,
                              child: Text(Tr.pick('更新 ${formatMoney(cost(p))}',
                                  'Renew ${formatMoney(cost(p))}')),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ],
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
            for (final c in others.take(30))
              line(Tr.pick(
                  '${c.playerName}: ${c.fromClubName} → ${c.toClubName}',
                  '${c.playerName}: ${c.fromClubName} to ${c.toClubName}')),
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
            for (final t in targets)
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
                    OutlinedButton(
                      onPressed: () => _showSignDialog(context, t.player),
                      child: Text(Tr.pick('仮契約', 'Pre-sign')),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  /// 仮契約の条件(年数・延長オプション)を決めて結ぶ。年俸はその場の要求額。
  Future<void> _showSignDialog(BuildContext context, Player p) async {
    final game = context.read<GameState>();
    final choices = PreContractEngine.endYearChoices(p);
    if (choices.isEmpty) return;
    var endYear = PreContractEngine.defaultEndYear(p);
    var option = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final canOption = ContractEngine.canAttachOption(endYear, p.age,
              nextSeasonStart: true);
          if (!canOption) option = false;
          final wage = PreContractEngine.wageDemand(p, option: option);
          return AlertDialog(
            title:
                Text(Tr.pick('${p.name}と仮契約', 'Pre-contract with ${p.name}')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(Tr.pick(
                    '移籍金なし・7月1日に加入。求める年俸: ${formatMoney(annualFromWeekly(wage))}',
                    'No fee, joins on 1 Jul. Salary he wants: ${formatMoney(annualFromWeekly(wage))}')),
                DropdownButton<int>(
                  value: endYear,
                  isExpanded: true,
                  items: [
                    for (final y in choices)
                      DropdownMenuItem(
                          value: y, child: Text(ContractEngine.untilLabel(y))),
                  ],
                  onChanged: (y) => setState(() => endYear = y ?? endYear),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: option,
                  onChanged: canOption
                      ? (v) => setState(() => option = v ?? false)
                      : null,
                  title: Text(Tr.pick('クラブ側の1年延長オプションを付ける(年俸+5%)',
                      'Add a 1-year club option (salary +5%)')),
                  subtitle: canOption
                      ? null
                      : Text(Tr.pick('最長の契約年数なので付けられません。年数を1年短くすると付けられます。',
                          'Not possible at the longest contract length. Shorten it by a year to add one.')),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(Tr.pick('やめる', 'Cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(Tr.pick('仮契約を結ぶ', 'Agree terms')),
              ),
            ],
          );
        },
      ),
    );
    if (ok != true) return;
    final done =
        await game.signPreContract(p.id, endYear: endYear, option: option);
    done ? FeedbackService.success() : FeedbackService.error();
    if (!done && context.mounted && game.lastSigningBlockReason != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(game.lastSigningBlockReason!)));
    }
  }
}
