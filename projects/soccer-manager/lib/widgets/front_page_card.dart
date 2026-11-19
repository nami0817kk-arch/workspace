import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../state/game_state.dart';
import '../theme/semantic_colors.dart';

/// 新聞の一面(最新の見出し)と、監督の試合後の一言。
class FrontPageCard extends StatelessWidget {
  const FrontPageCard({super.key});

  @override
  Widget build(BuildContext context) {
    final save = context.watch<GameState>().save;
    final headline = save?.frontPageHeadline;
    if (headline == null) return const SizedBox.shrink();
    final quote = save!.frontPageQuote;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.newspaper, size: 18),
                const SizedBox(width: 6),
                Text(Tr.pick('今日の一面', 'Today\'s front page'),
                    style: TextStyle(
                        fontSize: 11,
                        color: SemanticColors.subtleText(context))),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              headline,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            if (quote != null) ...[
              const SizedBox(height: 4),
              Text(Tr.pick('監督 $quote', 'Manager: $quote'),
                  style: const TextStyle(
                      fontSize: 13, fontStyle: FontStyle.italic)),
            ],
          ],
        ),
      ),
    );
  }
}
