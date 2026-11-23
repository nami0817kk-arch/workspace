import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/analytics_engine.dart';
import '../logic/economy_scale.dart';
import '../state/game_state.dart';

/// U18/U21 と分析部門。
class YouthAnalyticsCard extends StatelessWidget {
  const YouthAnalyticsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final save = gs.save;
    if (save == null) return const SizedBox.shrink();
    final u21 = gs.u21Squad;
    final gems = gs.hiddenGems;
    final fee = gs.scaledMoney(AnalyticsEngine.annualFee);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Tr.pick('U18・U21', 'Under-18s and under-21s'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
                Tr.pick(
                    'U18 はアカデミーの有望株(${gs.u18Count}人)。先発に入っていない21歳以下の${u21.length}人は、毎節 U21 の試合に出て試合勘を保ち、少しずつ伸びます。',
                    'The under-18s are your academy prospects (${gs.u18Count}). ${u21.length == 1 ? 'The one player aged 21 or under outside the starting XI plays' : 'The ${u21.length} players aged 21 or under outside the starting XI play'} for the under-21s every matchday, keeping sharp and improving a little.'),
                style: const TextStyle(fontSize: 12)),
            if (u21.isNotEmpty)
              Text(u21.map((p) => Tr.pick('${p.name}(${p.age})', '${p.name} (${p.age})')).join(Tr.pick('、', ', ')),
                  style: const TextStyle(fontSize: 12)),
            const Divider(height: 20),
            Text(Tr.pick('分析部門', 'Analytics department'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(
                Tr.pick(
                    '年会費${formatMoney(fee)}。試合の結果に xG(期待得点)を出し、他のクラブの若手からデータで隠れた逸材を見つけます。',
                    '${formatMoney(fee)} a year. Adds expected goals (xG) to results and finds hidden gems among young players at other clubs.'),
                style: const TextStyle(fontSize: 12)),
            Align(
              alignment: Alignment.centerRight,
              child: save.hasAnalytics
                  ? TextButton(
                      onPressed: () => gs.setAnalytics(false),
                      child: Text(Tr.pick('分析部門をやめる', 'Shut it down')))
                  : FilledButton.tonal(
                      onPressed: save.budget >= fee
                          ? () => gs.setAnalytics(true)
                          : null,
                      child: Text(Tr.pick('分析部門を置く', 'Set it up'))),
            ),
            if (save.hasAnalytics) ...[
              Text(Tr.pick('隠れた逸材', 'Hidden gems'),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              if (gems.isEmpty)
                Text(Tr.pick('今は見つかっていません', 'None found right now'))
              else
                for (final g in gems)
                  Text(Tr.pick(
                      '${g.player.name}(${g.player.age}歳・${g.club})総合${g.player.overall} → 潜在${g.potential}',
                      '${g.player.name} (${g.player.age}, ${g.club}) overall ${g.player.overall}, potential ${g.potential}')),
            ],
          ],
        ),
      ),
    );
  }
}
