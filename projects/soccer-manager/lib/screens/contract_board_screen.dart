import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/contract_board_engine.dart';
import '../logic/contract_engine.dart';
import '../logic/squad_registration_engine.dart';
import '../models/player.dart';
import '../models/team.dart';
import '../services/feedback_service.dart';
import '../state/game_state.dart';
import 'contract_offer_screen.dart';
import '../widgets/fm_panel.dart';
import '../widgets/responsive_body.dart';
import '../logic/economy_scale.dart';
import '../widgets/disabled_reason.dart';

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
    // 登録の決まりは国ごとに違う(2026-11-22)。
    final rules = game.registrationRules;
    final byYears = ContractBoardEngine.byYearsRemaining(team);
    final expiring = ContractBoardEngine.expiring(team);
    final theme = Theme.of(context);
    int cost(Player p) =>
        ContractEngine.renewalCost(p) + ContractEngine.signingBonusFor(p);
    const small = TextStyle(fontSize: 12);
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
                label: Tr.pick('登録の決まり', 'Rules'),
                value: Tr.pick('${rules.countryLabel}式', '${rules.countryLabel} rules'),
              ),
              if (rules.homegrownQuota > 0) ...[
                FmRow(
                  label: Tr.pick('うち国内育成', 'Homegrown'),
                  value: Tr.pick(
                      '$homegrown人(${rules.homegrownQuota}人を入れる)',
                      '$homegrown (quota ${rules.homegrownQuota})'),
                ),
                FmRow(
                  label: Tr.pick('うち国外育成', 'Trained abroad'),
                  value: '$nonHomegrown/${rules.nonHomegrownLimit}',
                  valueColor: nonHomegrown > rules.nonHomegrownLimit
                      ? theme.colorScheme.error
                      : null,
                ),
              ],
              if (rules.clubTrainedQuota > 0)
                FmRow(
                  label: Tr.pick('うちクラブ育成(ユース出身)', 'Club-trained'),
                  value: Tr.pick(
                      '${SquadRegistration.clubTrainedSeniorCount(team)}人(${rules.clubTrainedQuota}人を入れる)',
                      '${SquadRegistration.clubTrainedSeniorCount(team)} (quota ${rules.clubTrainedQuota})'),
                ),
              if (rules.nonEuLimit != null)
                FmRow(
                  label: Tr.pick('EU 外の国籍(年齢を問わない)', 'Non-EU players (any age)'),
                  value: '${game.nonEuPlayerCount}/${rules.nonEuLimit}',
                  valueColor: game.nonEuPlayerCount > rules.nonEuLimit!
                      ? theme.colorScheme.error
                      : null,
                ),
              if (rules.nonEuSigningsPerSeason != null)
                FmRow(
                  label: Tr.pick('今季、他国から取った EU 外の選手', 'Non-EU signings from abroad this season'),
                  value: '${game.nonEuSignedThisSeason}/${rules.nonEuSigningsPerSeason}',
                ),
              if (rules.minNationals != null)
                FmRow(
                  label: Tr.pick('${rules.countryLabel}国籍の選手', '${rules.countryLabel} nationals'),
                  value: Tr.pick(
                      '${game.nationalPlayerCount}人(${rules.minNationals}人以上)',
                      '${game.nationalPlayerCount} (at least ${rules.minNationals})'),
                  valueColor: game.nationalPlayerCount < rules.minNationals!
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
                              key: ValueKey('board-renew-${p.id}'),
                              onPressed: renewBlock(p) == null
                                  ? () {
                                      FeedbackService.tap();
                                      openContractOffer(context,
                                          player: p,
                                          kind: ContractKind.renewal);
                                    }
                                  : null,
                              child: Text(Tr.pick('更新 ${formatMoney(cost(p))}',
                                  'Renew ${formatMoney(cost(p))}')),
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
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}
