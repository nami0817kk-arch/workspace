import 'package:flutter/material.dart';
import '../theme/semantic_colors.dart';
import 'package:provider/provider.dart';

import '../state/game_state.dart';
import 'player_detail_screen.dart';
import '../l10n/tr.dart';

/// シーズンごとに確定した個人タイトル(得点王・年間MVP・ゴールデングラブ)の
/// 履歴。リーグの「個人成績」の中に出す(2026-11-25 に資料の「個人タイトル」
/// から移した。今季のランキングと同じ場所で見られるように)。
class AwardsHistory extends StatelessWidget {
  const AwardsHistory({super.key});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final awards = gameState.seasonAwards.reversed.toList();
    final clubName = gameState.userTeam.name;
    final userTeamId = gameState.save!.userTeamId;

    return awards.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.emoji_events_outlined,
                        size: 64,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        Tr.pick('まだ表彰記録がありません(シーズン終了時に確定します)',
                            'No awards yet. They are decided at the end of each season'),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: awards.length,
                itemBuilder: (context, i) {
                  final a = awards[i];
                  // teamIdを持たない旧セーブのレコードのみ、クラブ名の一致で代用する。
                  final scorerIsOwnClub = a.topScorerTeamId != null
                      ? a.topScorerTeamId == userTeamId
                      : a.topScorerTeamName == clubName;
                  final mvpIsOwnClub = a.mvpTeamId != null
                      ? a.mvpTeamId == userTeamId
                      : a.mvpTeamName == clubName;
                  final gloveIsOwnClub = a.goldenGloveTeamId == userTeamId;
                  // 他のクラブの選手も開ける(引退などで居なければ開かない)。
                  String? routablePlayerId(String? id) {
                    if (id == null) return null;
                    return gameState.anyPlayerById(id) == null ? null : id;
                  }

                  final scorerPlayerId = routablePlayerId(a.topScorerId);
                  final mvpPlayerId = routablePlayerId(a.mvpId);
                  final glovePlayerId = routablePlayerId(a.goldenGloveId);
                  void openPlayer(String id) => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PlayerDetailScreen(playerId: id),
                        ),
                      );
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            Tr.pick('シーズン${a.season}', 'Season ${a.season}'),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Divider(height: 20),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              Icons.sports_soccer,
                              color: SemanticColors.ink(context, Colors.green),
                            ),
                            title: Row(
                              children: [
                                // Row の中の Text は幅の制約を受けない。
                                // 英語の見出しは長く、狭い端末ではみ出す。
                                Flexible(
                                  child: Text(Tr.pick('得点王', 'Top scorer')),
                                ),
                                if (scorerIsOwnClub) ...[
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.shield,
                                    size: 14,
                                    color: SemanticColors.ink(context, Colors.blueAccent),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: a.topScorerName == null
                                ? Text(Tr.pick('該当者なし', 'Not awarded'))
                                : Text(
                                    Tr.pick(
                                        '${a.topScorerName}（${a.topScorerTeamName}） - ${a.topScorerGoals}得点',
                                        '${a.topScorerName} (${a.topScorerTeamName}) — ${Tr.plural(a.topScorerGoals, 'goal')}'),
                                  ),
                            onTap: scorerPlayerId == null
                                ? null
                                : () => openPlayer(scorerPlayerId),
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              Icons.emoji_events,
                              color: SemanticColors.ink(context, Colors.amber,
                                  min: 3),
                            ),
                            title: Row(
                              children: [
                                // Row の中の Text は幅の制約を受けない。
                                // 英語の見出しは長く、狭い端末ではみ出す。
                                Flexible(
                                  child: Text(
                                      Tr.pick('年間MVP', 'Player of the season')),
                                ),
                                if (mvpIsOwnClub) ...[
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.shield,
                                    size: 14,
                                    color: SemanticColors.ink(context, Colors.blueAccent),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: a.mvpName == null
                                ? Text(Tr.pick('該当者なし', 'Not awarded'))
                                : Text(Tr.pick('${a.mvpName}（${a.mvpTeamName}）',
                                    '${a.mvpName} (${a.mvpTeamName})')),
                            onTap: mvpPlayerId == null
                                ? null
                                : () => openPlayer(mvpPlayerId),
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              Icons.sports,
                              color: SemanticColors.ink(context, Colors.indigo),
                            ),
                            title: Row(
                              children: [
                                // Row の中の Text は幅の制約を受けない。
                                // 英語の見出しは長く、狭い端末ではみ出す。
                                Flexible(
                                  child:
                                      Text(Tr.pick('ゴールデングラブ', 'Golden Glove')),
                                ),
                                if (gloveIsOwnClub) ...[
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.shield,
                                    size: 14,
                                    color: SemanticColors.ink(context, Colors.blueAccent),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: a.goldenGloveName == null
                                ? Text(Tr.pick('該当者なし', 'Not awarded'))
                                : Text(
                                    Tr.pick(
                                        '${a.goldenGloveName}（${a.goldenGloveTeamName}） - 無失点${a.goldenGloveCleanSheets}試合',
                                        '${a.goldenGloveName} (${a.goldenGloveTeamName}) — ${a.goldenGloveCleanSheets} clean sheets'),
                                  ),
                            onTap: glovePlayerId == null
                                ? null
                                : () => openPlayer(glovePlayerId),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
  }
}
