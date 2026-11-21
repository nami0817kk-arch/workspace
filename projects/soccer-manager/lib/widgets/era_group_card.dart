import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/economy_scale.dart';
import '../logic/era_engine.dart';
import '../state/game_state.dart';
import 'help_button.dart';

/// 時代の変化と、持っているほかのクラブ。
class EraGroupCard extends StatelessWidget {
  const EraGroupCard({super.key});

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    if (gs.save == null) return const SizedBox.shrink();
    final era = gs.currentEra;
    final owned = gs.groupClubsOwned;
    final candidates = gs.groupClubCandidates;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Tr.pick('時代: ${era.label}', 'Era: ${era.label}'),
                style: Theme.of(context).textTheme.titleMedium),
            Text(
                Tr.pick('${era.summary}時代は${EraEngine.length}季ごとに変わります。',
                    '${era.summary} Eras change every ${EraEngine.length} seasons.'),
                style: const TextStyle(fontSize: 12)),
            const Divider(height: 20),
            TitleWithHelp(
              title: Tr.pick('持っているほかのクラブ', 'Your other clubs'),
              style: const TextStyle(fontWeight: FontWeight.bold),
              help: Tr.pick(
                  'オーナーの私財(いま${formatMoney(gs.ownerWealth)})で他国の1部のクラブを買えます。采配はしませんが、順位に応じて毎季の損益が私財に入り、そのクラブの選手は半額で取れます。',
                  'Use your own money (${formatMoney(gs.ownerWealth)} now) to buy a top-flight club abroad. You do not run it, but its league position earns or costs you money each season, and its players come at half price.'),
            ),
            Text(
                Tr.pick('いまの私財 ${formatMoney(gs.ownerWealth)}',
                    'Your own money: ${formatMoney(gs.ownerWealth)}'),
                style: const TextStyle(fontSize: 12)),
            for (final (t, paid, worth) in owned)
              Row(
                children: [
                  Expanded(
                      child: Text(Tr.pick(
                          '${t.name}(買値${formatMoney(paid)}・今売ると${formatMoney(worth)})',
                          '${t.name} (paid ${formatMoney(paid)}, worth ${formatMoney(worth)})'))),
                  TextButton(
                    onPressed: () => gs.sellGroupClub(t.id),
                    child: Text(Tr.pick('売る', 'Sell')),
                  ),
                ],
              ),
            const SizedBox(height: 6),
            for (final (t, price) in candidates.take(4))
              Row(
                children: [
                  Expanded(
                      child: Text(Tr.pick('${t.name}(${formatMoney(price)})',
                          '${t.name} (${formatMoney(price)})'))),
                  OutlinedButton(
                    onPressed: gs.ownerWealth >= price
                        ? () => gs.buyGroupClub(t.id)
                        : null,
                    child: Text(Tr.pick('買う', 'Buy')),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
