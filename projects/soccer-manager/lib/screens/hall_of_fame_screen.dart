import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/player.dart';
import '../state/game_state.dart';
import '../widgets/player_face_avatar.dart';
import '../widgets/quick_access_drawer.dart';
import '../widgets/responsive_body.dart';
import '../l10n/tr.dart';
import '../theme/semantic_colors.dart';

/// 高齢により正式に引退した選手(殿堂)の一覧画面。契約満了で単に自由契約に
/// なった選手とは異なり、再契約はできない。
class HallOfFameScreen extends StatelessWidget {
  const HallOfFameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final legends = [...gameState.save!.retiredLegends]
      ..sort((a, b) => b.careerGoals.compareTo(a.careerGoals));

    return Scaffold(
      appBar: AppBar(
        title: Text(Tr.pick('殿堂', 'Hall of fame')),
        leading: const BackButton(),
        actions: const [QuickAccessMenuButton()],
      ),
      drawer: const QuickAccessDrawer(),
      body: ResponsiveBody(
        child: legends.isEmpty && gameState.clubAppsLeaders().isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.stars, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(Tr.pick('まだ引退した選手はいません', 'Nobody has retired yet'),
                          textAlign: TextAlign.center),
                    ],
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const _ClubRecordsCard(),
                  for (final p in legends)
                    _LegendCard(
                      player: p,
                      retired: gameState.isNumberRetired(p.id),
                      onRetireNumber: () => gameState.retireNumber(p.id),
                    ),
                ],
              ),
      ),
    );
  }
}

class _LegendCard extends StatelessWidget {
  final Player player;
  final bool retired;
  final VoidCallback onRetireNumber;
  const _LegendCard({
    required this.player,
    required this.retired,
    required this.onRetireNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: PlayerFaceAvatar(
          playerId: player.id,
          position: player.position,
        ),
        title: Text(player.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              Tr.pick(
                  '${player.position.fullLabel} ・ 引退時${player.age}歳 ・ 総合${player.overall}',
                  '${player.position.fullLabel} • retired at ${player.age} • overall ${player.overall}'),
            ),
            if (retired)
              Text(Tr.pick('永久欠番', 'Number retired'),
                  style: const TextStyle(fontWeight: FontWeight.bold))
            else
              TextButton(
                onPressed: onRetireNumber,
                child: Text(Tr.pick('永久欠番にする', 'Retire his number')),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              Tr.pick('${player.careerAppearances}試合',
                  Tr.plural(player.careerAppearances, 'app')),
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              Tr.pick('${player.careerGoals}得点',
                  Tr.plural(player.careerGoals, 'goal')),
              style: TextStyle(
                  fontSize: 12, color: SemanticColors.subtleText(context)),
            ),
          ],
        ),
      ),
    );
  }
}

/// クラブの歴代記録(自クラブでの出場・得点の上位と、最大の勝ち試合)。
class _ClubRecordsCard extends StatelessWidget {
  const _ClubRecordsCard();

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final apps = gs.clubAppsLeaders();
    final goals = gs.clubGoalsLeaders();
    final win = gs.save?.biggestWin;
    if (apps.isEmpty && goals.isEmpty) return const SizedBox.shrink();
    Widget list(String title, List<ClubRecordRow> rows, String unitJa,
            String unitEn) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            for (var i = 0; i < rows.length; i++)
              Text(Tr.pick('${i + 1}. ${rows[i].name} ${rows[i].value}$unitJa',
                  '${i + 1}. ${rows[i].name} ${rows[i].value} $unitEn')),
          ],
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Tr.pick('クラブの記録', 'Club records'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            list(Tr.pick('出場数', 'Appearances'), apps, Tr.pick('試合', ''),
                Tr.pick('', 'apps')),
            const SizedBox(height: 8),
            if (goals.isNotEmpty)
              list(Tr.pick('得点', 'Goals'), goals, Tr.pick('点', ''),
                  Tr.pick('', 'goals')),
            if (win != null) ...[
              const SizedBox(height: 8),
              Text(Tr.pick('最大の勝ち試合', 'Biggest win'),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(win),
            ],
          ],
        ),
      ),
    );
  }
}
