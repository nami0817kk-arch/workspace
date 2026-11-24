import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/league_stats.dart';
import '../state/game_state.dart';
import '../theme/semantic_colors.dart';
import '../widgets/chip_switcher.dart';
import '../widgets/club_emblem.dart';
import 'awards_history.dart';
import 'club_detail_screen.dart';
import 'player_detail_screen.dart';

/// リーグの個人成績(FM の「Stats」)。今季のランキング(得点・アシスト・
/// 平均採点・無失点)と、歴代の個人タイトル。
///
/// 2026-11-25 に資料の「リーグランキング」「個人タイトル」から移して1つに
/// した(利用者「得点王などの情報もリーグで見られるように」)。選手の名前を
/// 押すと選手の詳細(他のクラブの選手も)、クラブを押すとクラブのページ。
class LeagueStatsScreen extends StatelessWidget {
  const LeagueStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChipSwitcher(items: [
      (Tr.pick('今季のランキング', 'This season'), (_) => const _Rankings()),
      (Tr.pick('個人タイトル(歴代)', 'Awards by season'),
          (_) => const AwardsHistory()),
    ]);
  }
}

class _Rankings extends StatelessWidget {
  const _Rankings();

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final league = gs.save?.league;
    if (league == null) return const SizedBox.shrink();
    final stats = LeagueStats.compute(league);
    final minApps = LeagueStats.minAppsForRating(league);
    final tables = [
      _RankingTable(
        key: const ValueKey('ranking-goals'),
        title: Tr.pick('得点', 'Goals'),
        lines: stats.top((l) => l.goals, limit: 10),
        value: (l) => '${l.goals}',
      ),
      _RankingTable(
        key: const ValueKey('ranking-assists'),
        title: Tr.pick('アシスト', 'Assists'),
        lines: stats.top((l) => l.assists, limit: 10),
        value: (l) => '${l.assists}',
      ),
      _RankingTable(
        key: const ValueKey('ranking-rating'),
        title: Tr.pick('平均採点($minApps試合以上)',
            'Average rating ($minApps+ apps)'),
        lines: stats.top((l) => l.avgRating, limit: 10, minApps: minApps),
        value: (l) => l.avgRating.toStringAsFixed(2),
      ),
      _RankingTable(
        key: const ValueKey('ranking-clean-sheets'),
        title: Tr.pick('無失点(GK)', 'Clean sheets (GK)'),
        lines: stats.top((l) => l.cleanSheets, limit: 10),
        value: (l) => '${l.cleanSheets}',
      ),
      _RankingTable(
        key: const ValueKey('ranking-motm'),
        title: Tr.pick('マン・オブ・ザ・マッチ', 'Player of the match'),
        lines: stats.top((l) => l.motm, limit: 10),
        value: (l) => '${l.motm}',
      ),
      _RankingTable(
        key: const ValueKey('ranking-cards'),
        title: Tr.pick('警告・退場', 'Bookings'),
        lines: stats.top((l) => l.yellows + l.reds * 3, limit: 10),
        value: (l) => l.reds > 0 ? '${l.yellows}/${l.reds}' : '${l.yellows}',
      ),
    ];
    return LayoutBuilder(builder: (context, c) {
      // 横画面の広さなら2列。表の幅が狭いとクラブ名が切れるので、1つの表が
      // 330 を下回るなら1列にする。
      final textScale = MediaQuery.textScalerOf(context).scale(1);
      final cols = c.maxWidth / textScale >= 700 ? 2 : 1;
      final w = (c.maxWidth - 24 - (cols - 1) * 12) / cols;
      return SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [for (final t in tables) SizedBox(width: w, child: t)],
        ),
      );
    });
  }
}

class _RankingTable extends StatelessWidget {
  const _RankingTable({
    super.key,
    required this.title,
    required this.lines,
    required this.value,
  });

  final String title;
  final List<PlayerSeasonLine> lines;
  final String Function(PlayerSeasonLine) value;

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final scheme = Theme.of(context).colorScheme;
    final subtle = SemanticColors.subtleText(context);
    final userTeamId = gs.userTeam.id;
    final teams = {for (final t in gs.save!.league.teams) t.id: t};
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
            child: Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                Text(Tr.pick('出場', 'Apps'),
                    style: TextStyle(fontSize: 11, color: subtle)),
                const SizedBox(width: 44),
              ],
            ),
          ),
          if (lines.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                Tr.pick('まだ記録がありません。節を進めると出ます。',
                    'Nothing recorded yet. Play a few matchdays.'),
                style: TextStyle(fontSize: 12, color: subtle),
              ),
            ),
          for (final (i, l) in lines.indexed)
            Container(
              height: 36,
              color: l.teamId == userTeamId
                  ? scheme.primaryContainer
                  : i.isOdd
                      ? scheme.surfaceContainerLow
                      : null,
              padding: const EdgeInsets.only(left: 10, right: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 22,
                    child: Text('${i + 1}',
                        style: small.copyWith(
                            fontWeight: FontWeight.bold,
                            color: i < 3
                                ? SemanticColors.ink(
                                    context, Colors.amber.shade700)
                                : subtle)),
                  ),
                  // 選手の名前(押すと選手の詳細)。
                  Expanded(
                    flex: 5,
                    child: InkWell(
                      key: ValueKey('ranking-player-${l.playerId}'),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) =>
                                PlayerDetailScreen(playerId: l.playerId)),
                      ),
                      child: SizedBox(
                        height: 36,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(l.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  small.copyWith(fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // クラブ(押すとクラブのページ)。名前は切らずに縮める
                  // (資料のリーグランキングでクラブ名が切れていた)。
                  Expanded(
                    flex: 4,
                    child: InkWell(
                      onTap: teams[l.teamId] == null
                          ? null
                          : () => openClubPage(context, teams[l.teamId]!),
                      child: SizedBox(
                        height: 36,
                        child: Row(
                          children: [
                            ClubEmblem(
                                teamId: l.teamId,
                                teamName: teams[l.teamId]?.name ?? '',
                                size: 16),
                            const SizedBox(width: 4),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(teams[l.teamId]?.name ?? '-',
                                    maxLines: 1,
                                    style:
                                        TextStyle(fontSize: 11, color: subtle)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 28,
                    child: Text('${l.apps}',
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: 11, color: subtle)),
                  ),
                  SizedBox(
                    width: 44,
                    child: Text(value(l),
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
