import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/awards_engine.dart';
import '../state/game_state.dart';
import '../widgets/quick_access_drawer.dart';
import '../widgets/responsive_body.dart';
import '../l10n/tr.dart';
import '../theme/semantic_colors.dart';

/// リーグの個人ランキング(得点・アシスト)画面。シーズン終了を待たず、
/// いつでも現時点の順位を確認できる(得点王・MVPの表彰自体は従来通り
/// シーズン終了時に確定する)。
///
/// 得点とアシストは左右に並べた表にした(2026-11-21)。1人ずつ大きな札で
/// タブを切り替えていたときは、20人で画面6つ分あり、両方を一度に
/// 見られなかった。
class LeagueRankingScreen extends StatelessWidget {
  const LeagueRankingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final league = gameState.save?.league;
    return Scaffold(
      appBar: AppBar(
        title: Text(Tr.pick('リーグランキング', 'League rankings')),
        leading: const BackButton(),
        actions: const [QuickAccessMenuButton()],
      ),
      drawer: const QuickAccessDrawer(),
      body: league == null
          ? const Center(child: CircularProgressIndicator())
          : ResponsiveBody(
              child: LayoutBuilder(builder: (context, c) {
                final goals = _RankingTable(
                  title: Tr.pick('得点', 'Goals'),
                  entries: AwardsEngine.goalRanking(league),
                  gameState: gameState,
                );
                final assists = _RankingTable(
                  title: Tr.pick('アシスト', 'Assists'),
                  entries: AwardsEngine.assistRanking(league),
                  gameState: gameState,
                );
                final wide = c.maxWidth >= 560;
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: goals),
                            const SizedBox(width: 12),
                            Expanded(child: assists),
                          ],
                        )
                      : Column(
                          children: [
                            goals,
                            const SizedBox(height: 12),
                            assists
                          ],
                        ),
                );
              }),
            ),
    );
  }
}

class _RankingTable extends StatelessWidget {
  final String title;
  final List<PlayerRankingEntry> entries;
  final GameState gameState;

  const _RankingTable({
    required this.title,
    required this.entries,
    required this.gameState,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subtle = SemanticColors.subtleText(context);
    final league = gameState.save!.league;
    final userTeamId = gameState.userTeam.id;
    final names = {for (final t in league.teams) t.id: t.name};
    const small = TextStyle(fontSize: 12);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: scheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(title,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                Tr.pick('まだ記録がありません。節を進めると出ます。',
                    'Nothing recorded yet. Play a few matchdays.'),
                style: TextStyle(fontSize: 12, color: subtle),
              ),
            ),
          for (final (i, e) in entries.indexed)
            Container(
              height: 32,
              color: e.teamId == userTeamId
                  ? scheme.primaryContainer
                  : i.isOdd
                      ? scheme.surfaceContainerLow
                      : null,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 26,
                    child: Text('${i + 1}',
                        style: small.copyWith(
                            fontWeight: FontWeight.bold,
                            color: i < 3
                                ? SemanticColors.ink(
                                    context, Colors.amber.shade700)
                                : subtle)),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(e.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: small.copyWith(fontWeight: FontWeight.w600)),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(names[e.teamId] ?? '---',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: subtle)),
                  ),
                  SizedBox(
                    width: 28,
                    child: Text('${e.count}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
