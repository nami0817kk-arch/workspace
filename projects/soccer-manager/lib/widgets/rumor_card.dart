import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../state/game_state.dart';

/// 移籍の噂と記者会見。答え方で選手の気持ちとサポーターの見方が変わる。
class RumorCard extends StatelessWidget {
  const RumorCard({super.key});

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final r = gs.save?.pendingRumor;
    if (r == null) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Tr.pick('記者会見: ${r[1]}の移籍の噂', 'Press conference: the ${r[1]} rumour'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(Tr.pick(
                '${r[2]}が${r[1]}に関心と報じられています。売らないと言えば本人は落ち着きますが、今季のうちに売るとサポーターが怒ります。条件しだいと話せば、${r[2]}から話が来ます。',
                '${r[2]} are said to want ${r[1]}. Saying he is not for sale settles him, but selling him this season would anger the fans. Saying the price is right brings an offer from ${r[2]}.'),
                style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final a in RumorAnswer.values)
                  OutlinedButton(
                    onPressed: () => gs.answerRumor(a),
                    child: Text(a.label),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
