import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/economy_scale.dart';
import '../logic/scout_knowledge.dart';
import '../models/player.dart';
import '../models/team.dart';
import '../state/game_state.dart';
import '../theme/semantic_colors.dart';
import '../widgets/club_emblem.dart';

/// 他のクラブのページ。順位・オーナー・今季の対戦・顔ぶれ(見立てつき)。
class ClubDetailScreen extends StatelessWidget {
  final String teamId;
  const ClubDetailScreen({super.key, required this.teamId});

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final save = gs.save!;
    final team = gs.worldTeamById(teamId);
    if (team == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
            child: Text(Tr.pick('このクラブは見つかりません。', 'This club cannot be found.'))),
      );
    }
    final small =
        TextStyle(fontSize: 12, color: SemanticColors.subtleText(context));
    final league = save.league;
    final inLeague = league.teams.any((t) => t.id == team.id);
    final standings = league.sortedStandings;
    final rankIndex = standings.indexWhere((r) => r.teamId == team.id);
    final row = rankIndex < 0 ? null : standings[rankIndex];
    final owner =
        gs.rivalOwners.where((r) => r.clubId == team.id).firstOrNull;
    final meetings = [
      for (final f in league.fixtures)
        if (f.result != null &&
            ((f.homeTeamId == team.id && f.awayTeamId == save.userTeamId) ||
                (f.awayTeamId == team.id && f.homeTeamId == save.userTeamId)))
          f,
    ];
    final same = gs.sameLeaguePlayerIds();
    final players = [...team.players]..sort((a, b) {
        final ea =
            ScoutKnowledge.center(gs.overallEstimate(a, sameLeagueIds: same));
        final eb =
            ScoutKnowledge.center(gs.overallEstimate(b, sameLeagueIds: same));
        return eb.compareTo(ea);
      });
    final userName = save.clubName;

    return Scaffold(
      appBar: AppBar(title: Text(team.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              ClubEmblem(teamId: team.id, teamName: team.name, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(team.name,
                        style: Theme.of(context).textTheme.titleLarge),
                    Text(
                      row == null
                          ? Tr.pick('戦力 ${team.overallRating}・${team.players.length}人',
                              'Squad rating ${team.overallRating}, ${team.players.length} players')
                          : Tr.pick(
                              '${rankIndex + 1}位(${row.points}点・${row.won}勝${row.draw}分${row.lost}敗)・戦力 ${team.overallRating}・${team.players.length}人',
                              '${rankIndex + 1} (${row.points} pts, W${row.won} D${row.draw} L${row.lost}), squad rating ${team.overallRating}, ${team.players.length} players'),
                      style: small,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (owner != null) ...[
            const SizedBox(height: 8),
            Text(Tr.pick(
                'オーナー: ${owner.name}(野心 ${owner.ambition}・今季の補強 ${owner.signingsThisSeason}人)',
                'Owner: ${owner.name} (ambition ${owner.ambition}, ${owner.signingsThisSeason} signings this season)')),
          ],
          if (inLeague) ...[
            const SizedBox(height: 12),
            Text(Tr.pick('今季の対戦', 'Meetings this season'),
                style: Theme.of(context).textTheme.titleSmall),
            if (meetings.isEmpty)
              Text(Tr.pick('まだ対戦していません。', 'You have not met yet.'),
                  style: small)
            else
              for (final f in meetings)
                Text(
                  Tr.pick(
                      '第${f.matchday}節 ${f.homeTeamId == save.userTeamId ? userName : team.name} ${f.result!.homeGoals}-${f.result!.awayGoals} ${f.awayTeamId == save.userTeamId ? userName : team.name}',
                      'Matchday ${f.matchday}: ${f.homeTeamId == save.userTeamId ? userName : team.name} ${f.result!.homeGoals}-${f.result!.awayGoals} ${f.awayTeamId == save.userTeamId ? userName : team.name}'),
                ),
          ],
          const SizedBox(height: 12),
          Text(Tr.pick('顔ぶれ(見立て)', 'Squad (as scouted)'),
              style: Theme.of(context).textTheme.titleSmall),
          Text(
              Tr.pick('総合力と伸びしろは、スカウトの見え方の幅で出します。星で注目リストに入れられます。',
                  'Overall and potential are shown as your scouts see them. Tap the star to watch a player.'),
              style: small),
          for (final p in players) _PlayerRow(player: p, same: same),
        ],
      ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  final Player player;
  final Set<String> same;
  const _PlayerRow({required this.player, required this.same});

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final p = player;
    final k = gs.knowledgeOf(p, sameLeagueIds: same);
    final ovr =
        ScoutKnowledge.label(gs.overallEstimate(p, sameLeagueIds: same));
    final pot =
        ScoutKnowledge.label(gs.potentialEstimate(p, sameLeagueIds: same));
    final watched = gs.isWatched(p.id);
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(Tr.pick('${p.name}(${p.position.label}・${p.age}歳)',
          '${p.name} (${p.position.label}, ${p.age})')),
      subtitle: Text(Tr.pick(
          '総合力 $ovr・伸びしろ $pot・市場価値 ${formatMoney(p.marketValue)}・見えている度合い $k%',
          'Overall $ovr, potential $pot, value ${formatMoney(p.marketValue)}, scouted $k%')),
      trailing: IconButton(
        tooltip: watched
            ? Tr.pick('注目から外す', 'Stop watching')
            : Tr.pick('注目に入れる', 'Watch'),
        icon: Icon(watched ? Icons.star : Icons.star_border),
        onPressed: () => gs.toggleWatched(p.id),
      ),
    );
  }
}

/// 順位表などから、クラブのページを開く。
void openClubPage(BuildContext context, Team team) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => ClubDetailScreen(teamId: team.id)),
  );
}
