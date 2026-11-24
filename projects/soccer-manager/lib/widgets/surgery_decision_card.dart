import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/economy_scale.dart';
import '../logic/injury_care.dart';
import '../state/game_state.dart';
import 'decision_card.dart';

/// 大きな怪我をした選手の、手術か保存療法かの判断。
class SurgeryDecisionCard extends StatelessWidget {
  const SurgeryDecisionCard({super.key});

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final players = gs.playersAwaitingSurgeryDecision;
    if (players.isEmpty) return const SizedBox.shrink();
    // 選手ごとに1枚。題と答えだけを出し、説明は押すと開く(2026-11-25)。
    return Column(
      children: [
        for (final p in players)
          DecisionCard(
            key: ValueKey('surgery-${p.id}'),
            icon: Icons.healing,
            title: Tr.pick(
                '手術か保存療法か: ${p.name}(あと${p.injuryWeeks}週)',
                'Surgery or rest: ${p.name} (${Tr.plural(p.injuryWeeks, 'week')})'),
            // 医療スタッフのおすすめと締切。過ぎたらおすすめで片付く
            // (2026-11-23。決めないまま何節でも残っていた)。
            deadline: Tr.pick(
                '医療スタッフのおすすめ: ${gs.recommendsSurgery(p) ? '手術' : '保存療法'}。あと${gs.decisionMatchdaysLeft('surgery:${p.id}')}節決めないと、おすすめで決まります。',
                "Medical staff advise: ${gs.recommendsSurgery(p) ? 'surgery' : 'rest'}. Undecided after ${Tr.plural(gs.decisionMatchdaysLeft('surgery:${p.id}'), 'matchday')}, their advice is followed."),
            detail: Tr.pick(
                '${InjuryCare.describe(p)}。手術は${formatMoney(gs.surgeryCost)}かかり、離脱が${InjuryCare.surgeryExtraWeeks}週延びますが、再発しません。保存療法は離脱が${InjuryCare.restSavedWeeks}週縮みますが、治ったときに${(InjuryCare.setbackChance * 100).round()}%で再発し、${InjuryCare.setbackWeeks}週休みます。',
                '${InjuryCare.describe(p)}. Surgery costs ${formatMoney(gs.surgeryCost)} and adds ${InjuryCare.surgeryExtraWeeks} weeks, but there is no setback. Rest saves ${InjuryCare.restSavedWeeks} weeks, but there is a ${(InjuryCare.setbackChance * 100).round()}% chance of a ${InjuryCare.setbackWeeks}-week setback.'),
            choices: [
              DecisionChoice(Tr.pick('手術する', 'Operate'),
                  () => gs.decideSurgery(p.id, surgery: true)),
              DecisionChoice(Tr.pick('保存療法', 'Rest it'),
                  () => gs.decideSurgery(p.id, surgery: false),
                  primary: false),
            ],
          ),
      ],
    );
  }
}
