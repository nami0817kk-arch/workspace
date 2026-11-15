import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/contract_board_engine.dart';
import '../logic/contract_engine.dart';
import '../models/player.dart';
import '../services/feedback_service.dart';
import '../state/game_state.dart';
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
    final room = ContractBoardEngine.registrationRoom(team, maxSquadSize);
    final byYears = ContractBoardEngine.byYearsRemaining(team);
    final expiring = ContractBoardEngine.expiring(team);
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Tr.pick('登録 ${team.players.length}/$maxSquadSize人',
                      'Registered ${team.players.length}/$maxSquadSize'),
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  room >= 0
                      ? Tr.pick('あと$room人まで登録できます。', '$room more can be registered.')
                      : Tr.pick('登録が${-room}人超えています。', '${-room} over the limit.'),
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Text(
                  Tr.pick('週給の合計 ${ContractBoardEngine.weeklyWages(team)}万円',
                      'Weekly wages ${ContractBoardEngine.weeklyWages(team)}'),
                ),
                const SizedBox(height: 8),
                Text(
                  Tr.pick(
                      '契約の残り: 0年${byYears[0]}人・1年${byYears[1]}人・2年${byYears[2]}人・3年以上${byYears[3]}人',
                      'Years left: 0y ${byYears[0]} • 1y ${byYears[1]} • 2y ${byYears[2]} • 3y+ ${byYears[3]}'),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text(Tr.pick('更新の時期の選手', 'Due for renewal'),
              style: theme.textTheme.titleSmall),
        ),
        if (expiring.isEmpty)
          Text(Tr.pick('いま更新が要る選手はいません。', 'No one needs renewing right now.'),
              style: theme.textTheme.bodySmall),
        for (final p in expiring)
          Card(
            child: ListTile(
              title: Text('${p.name}(${p.position.label}・${p.age}歳)'),
              subtitle: Text(Tr.pick(
                  '総合力 ${p.overall}・契約残り${p.contractYearsRemaining}年・週給 ${p.wage}万円',
                  'Overall ${p.overall} • ${p.contractYearsRemaining}y left • wage ${p.wage}')),
              trailing: FilledButton(
                onPressed: game.save!.budget >=
                        ContractEngine.renewalCost(p) +
                            ContractEngine.signingBonusFor(p)
                    ? () async {
                        FeedbackService.tap();
                        await context.read<GameState>().renewContract(p.id);
                      }
                    : null,
                child: Text(Tr.pick(
                    '更新 ${ContractEngine.renewalCost(p) + ContractEngine.signingBonusFor(p)}万円',
                    'Renew ${ContractEngine.renewalCost(p) + ContractEngine.signingBonusFor(p)}')),
              ),
            ),
          ),
      ],
    );
  }
}
