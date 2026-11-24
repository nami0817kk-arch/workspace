import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../state/game_state.dart';
import 'decision_card.dart';

/// 移籍の噂と記者会見。答え方で選手の気持ちとサポーターの見方が変わる。
class RumorCard extends StatelessWidget {
  const RumorCard({super.key});

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final r = gs.save?.pendingRumor;
    if (r == null) return const SizedBox.shrink();
    // 題と答えだけ。説明は押すと開く(2026-11-25)。締切はいつも出す。
    return DecisionCard(
      icon: Icons.mic_none,
      title: Tr.pick('記者会見: ${r[1]}の移籍の噂',
          'Press conference: the ${r[1]} rumour'),
      detail: Tr.pick(
          '${r[2]}が${r[1]}に関心と報じられています。売らないと言えば本人は落ち着きますが、今季のうちに売るとサポーターが怒ります。条件しだいと話せば、${r[2]}から話が来ます。',
          '${r[2]} are said to want ${r[1]}. Saying he is not for sale settles him, but selling him this season would anger the fans. Saying the price is right brings an offer from ${r[2]}.'),
      // 締切。過ぎたら「コメントしない」で片付く(2026-11-23)。
      deadline: Tr.pick(
          'あと${gs.decisionMatchdaysLeft('rumor')}節答えないと「コメントしない」になります。',
          'Unanswered after ${Tr.plural(gs.decisionMatchdaysLeft('rumor'), 'matchday')}, the club gives no comment.'),
      choices: [
        for (final a in RumorAnswer.values)
          DecisionChoice(a.label, () => gs.answerRumor(a)),
      ],
    );
  }
}
