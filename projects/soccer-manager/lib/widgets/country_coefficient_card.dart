import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../models/league_theme.dart';
import '../state/game_state.dart';
import 'help_button.dart';

/// 国の係数(大陸大会の5季の成績)と、自国から大陸大会に出られる数。
class CountryCoefficientCard extends StatelessWidget {
  const CountryCoefficientCard({super.key});

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    if (gs.save == null) return const SizedBox.shrink();
    final rows = gs.countryCoefficientRanking;
    final home = gs.currentLeagueTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 説明は「?」の中へ。いま何クラブ出られるかは見える所に残す。
            TitleWithHelp(
              title: Tr.pick('国の係数', 'Country coefficients'),
              help: Tr.pick(
                  '大陸大会での各国のクラブの成績(5季の合計)です。順位が上の国ほど、1部から大陸大会に出られるクラブが多くなります。',
                  'Each country\'s results in the continental cup over five seasons. Higher-ranked countries send more clubs.'),
            ),
            Text(
                Tr.pick('いま${home.label}は上位${gs.continentalSpots}クラブが大陸大会に出られます',
                    '${home.label} currently sends its top ${gs.continentalSpots}'),
                style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 6),
            for (var i = 0; i < rows.length; i++)
              Row(
                children: [
                  SizedBox(width: 28, child: Text('${i + 1}')),
                  Expanded(
                    child: Text(rows[i].$1.label,
                        style: TextStyle(
                            fontWeight: rows[i].$1 == home
                                ? FontWeight.bold
                                : FontWeight.normal)),
                  ),
                  Text(rows[i].$2.toStringAsFixed(1)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
