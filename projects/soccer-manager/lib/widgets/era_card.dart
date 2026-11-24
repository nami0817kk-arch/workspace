import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/era_engine.dart';
import '../state/game_state.dart';

/// 時代の変化(5季ごとに、放映権と移籍金の水準が変わる)。
///
/// 以前は「持っているほかのクラブ」(私財で他国のクラブを買う・売る)も
/// この札にあった。機能ごと外した(2026-11-25)。
class EraCard extends StatelessWidget {
  const EraCard({super.key});

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    if (gs.save == null) return const SizedBox.shrink();
    final era = gs.currentEra;
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
          ],
        ),
      ),
    );
  }
}
