import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/contract_board_engine.dart';
import '../logic/contract_engine.dart';
import '../logic/squad_registration_engine.dart';
import '../models/player.dart';
import '../services/feedback_service.dart';
import '../state/game_state.dart';
import '../widgets/fm_panel.dart';
import '../widgets/responsive_body.dart';

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
    final room = SquadRegistration.seniorLimit -
        SquadRegistration.seniorCount(team);
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
                label: Tr.pick('週給の合計', 'Weekly wages'),
                value: Tr.pick('${ContractBoardEngine.weeklyWages(team)}万円',
                    '${ContractBoardEngine.weeklyWages(team)}'),
              ),
              const Divider(),
              FmRow(
                  label: Tr.pick('契約残り 0年', 'Years left: 0'),
                  value: '${byYears[0]}'),
              FmRow(
                  label: Tr.pick('契約残り 1年', 'Years left: 1'),
                  value: '${byYears[1]}'),
              FmRow(
                  label: Tr.pick('契約残り 2年', 'Years left: 2'),
                  value: '${byYears[2]}'),
              FmRow(
                  label: Tr.pick('契約残り 3年以上', 'Years left: 3+'),
                  value: '${byYears[3]}'),
            ],
          ),
        ),
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
                                  Tr.pick('総合 ${p.overall}', 'OVR ${p.overall}'),
                                  style: small),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                  Tr.pick('残り${p.contractYearsRemaining}年',
                                      '${p.contractYearsRemaining}y left'),
                                  style: small),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                  Tr.pick('週給 ${p.wage}', 'Wage ${p.wage}'),
                                  style: small),
                            ),
                            FilledButton(
                              onPressed: game.save!.budget >= cost(p)
                                  ? () async {
                                      FeedbackService.tap();
                                      await context
                                          .read<GameState>()
                                          .renewContract(p.id);
                                    }
                                  : null,
                              child: Text(Tr.pick(
                                  '更新 ${cost(p)}万円', 'Renew ${cost(p)}')),
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
}
