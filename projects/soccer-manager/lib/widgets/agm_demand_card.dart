import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/agm_engine.dart';
import '../logic/economy_scale.dart';
import '../state/game_state.dart';
import 'decision_card.dart';

/// 株主総会で出された要求。受けるか断るかを選ぶ。
class AgmDemandCard extends StatelessWidget {
  const AgmDemandCard({super.key});

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final d = gs.agmDemand;
    if (d == null) return const SizedBox.shrink();
    final save = gs.save!;
    final detail = switch (d) {
      AgmDemand.wageCut => Tr.pick(
          '人件費率が${(save.agmWageRatio * 100).round()}%です。受けると、来季の総会までに${((save.agmWageRatio - AgmEngine.wageCutPoints) * 100).round()}%以下に下げる約束になります(守れなければ期待-10)。',
          'Your wage ratio is ${(save.agmWageRatio * 100).round()}%. Accept and you must bring it to ${((save.agmWageRatio - AgmEngine.wageCutPoints) * 100).round()}% by next year\'s meeting (or shareholder expectation drops 10).'),
      AgmDemand.payout => Tr.pick('上乗せの配当は${formatMoney(save.agmPayout)}です。',
          'The extra dividend comes to ${formatMoney(save.agmPayout)}.'),
      AgmDemand.manager => Tr.pick(
          '監督の立場は${save.managerStanding}です。受けると、すぐに解任します(違約金は残りの契約の全額)。',
          'The manager\'s standing is ${save.managerStanding}. Accept and he is sacked at once (the rest of his contract is paid in full).'),
    };
    // 題と答えだけ。説明と効き目は押すと開く(2026-11-25)。
    return DecisionCard(
      icon: Icons.groups_2_outlined,
      title: d.title,
      detail: detail,
      choices: [
        DecisionChoice(
          d.acceptLabel,
          () => gs.answerAgmDemand(accept: true),
          effect: Tr.pick('株主の期待+${d.acceptDelta}',
              'Shareholder expectation +${d.acceptDelta}'),
        ),
        DecisionChoice(
          d.rejectLabel,
          () => gs.answerAgmDemand(accept: false),
          effect: Tr.pick('株主の期待${d.rejectDelta}',
              'Shareholder expectation ${d.rejectDelta}'),
          primary: false,
        ),
      ],
    );
  }
}
