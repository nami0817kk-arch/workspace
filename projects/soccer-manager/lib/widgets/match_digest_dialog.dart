import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../models/match_result.dart';
import '../models/team.dart';
import '../screens/player_detail_screen.dart';
import '../services/feedback_service.dart';
import '../state/game_state.dart';
import '../theme/semantic_colors.dart';
import 'match_widgets.dart';

/// 試合のあとに出す、結果のダイジェスト(スコア・2つの期待の動き・得点者・
/// マン・オブ・ザ・マッチ・数字・賞金)。
///
/// **どの大会の試合でも、これ1つを出す**(2026-11-24)。以前はリーグ戦だけ
/// がこのダイアログで、カップ戦は試合経過の画面、スーパーカップは状況の札
/// から試合経過の画面と、大会ごとに見せ方が違った。試合経過の画面は
/// 利用者と決めて外した(2026-11-25「試合経過の画面は不要」)。
///
/// [competition] は見出しに出す大会の名前(「リーグ戦 第8節」「国内カップ
/// 3回戦」「親善試合」など)。[prizeNote] は勝ち上がりの賞金の知らせ。
Future<void> showMatchDigestDialog(
  BuildContext context, {
  required MatchResult result,
  required String userTeamId,
  required List<Team> teams,
  required String competition,
  int supportDelta = 0,
  int shareDelta = 0,
  String? prizeNote,
  String? penaltyNote,
}) async {
  final isHome = result.homeTeamId == userTeamId;
  final userGoals = isHome ? result.homeGoals : result.awayGoals;
  final oppGoals = isHome ? result.awayGoals : result.homeGoals;
  final resultLabel = userGoals > oppGoals
      ? Tr.pick('勝利', 'Win')
      : userGoals < oppGoals
          ? Tr.pick('敗北', 'Defeat')
          : Tr.pick('引き分け', 'Draw');
  String teamNameOf(String teamId) {
    for (final t in teams) {
      if (t.id == teamId) return t.name;
    }
    return '-';
  }

  final userTeamName = teamNameOf(userTeamId);
  final opponentName =
      teamNameOf(isHome ? result.awayTeamId : result.homeTeamId);
  String? scorerNameOf(String? playerId) {
    if (playerId == null) return null;
    for (final t in teams) {
      for (final p in t.players) {
        if (p.id == playerId) return p.name;
      }
    }
    return null;
  }

  /// 自クラブの選手がまだ在籍している場合のみ、選手詳細へ遷移可能なIDを返す。
  String? ownPlayerIdOf(String? playerId) {
    if (playerId == null) return null;
    for (final t in teams) {
      if (t.id != userTeamId) continue;
      for (final p in t.players) {
        if (p.id == playerId) return p.id;
      }
    }
    return null;
  }

  final goals = result.events
      .where((e) => e.type == MatchEventType.goal)
      .toList()
    ..sort((a, b) => a.minute.compareTo(b.minute));
  final motmName = scorerNameOf(result.manOfTheMatchId);
  final motmOwnPlayerId = ownPlayerIdOf(result.manOfTheMatchId);
  final xg = context.read<GameState>().xgOf(result);

  // 終わりの笛と、勝敗に合わせた歓声。
  FeedbackService.matchResult(
      won: userGoals > oppGoals, drew: userGoals == oppGoals);
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final resultColor = userGoals > oppGoals
          ? SemanticColors.positive(dialogContext)
          : userGoals < oppGoals
              ? SemanticColors.negative(dialogContext)
              : SemanticColors.neutral(dialogContext);
      void openPlayer(String id) {
        Navigator.pop(dialogContext);
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PlayerDetailScreen(playerId: id)),
        );
      }

      final head = <Widget>[
        Text(
          '$userTeamName $userGoals - $oppGoals $opponentName',
          key: const ValueKey('match-digest-score'),
          style: Theme.of(dialogContext).textTheme.titleMedium?.copyWith(
                color: resultColor,
                fontWeight: FontWeight.bold,
              ),
        ),
        if (penaltyNote != null)
          Text(penaltyNote,
              style: const TextStyle(fontWeight: FontWeight.w600)),
        // 分析部門があれば、xG(期待得点)も出す。
        if (xg != null)
          Text(Tr.pick(
              'xG ${xg.$1.toStringAsFixed(1)} - ${xg.$2.toStringAsFixed(1)}',
              'xG ${xg.$1.toStringAsFixed(1)} - ${xg.$2.toStringAsFixed(1)}')),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _MeterDelta(
                  label: Tr.pick('サポーター', 'Fans'), delta: supportDelta),
            ),
            Expanded(
              child: _MeterDelta(
                  label: Tr.pick('株主', 'Shareholders'), delta: shareDelta),
            ),
          ],
        ),
        // 勝ち上がりの賞金(以前は画面の下に一瞬出る帯だった)。
        if (prizeNote != null) ...[
          const SizedBox(height: 8),
          Row(
            key: const ValueKey('match-digest-prize'),
            children: [
              Icon(Icons.payments_outlined,
                  size: 18, color: SemanticColors.positive(dialogContext)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(prizeNote,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ];
      final scorers = <Widget>[
        if (goals.isEmpty)
          Text(
            Tr.pick('得点者はいませんでした', 'Nobody scored'),
            style: TextStyle(color: SemanticColors.subtleText(dialogContext)),
          )
        else ...[
          Text(
            Tr.pick('得点者', 'Scorers'),
            style: Theme.of(dialogContext).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          for (final g in goals)
            InkWell(
              onTap: ownPlayerIdOf(g.scorerId) == null
                  ? null
                  : () => openPlayer(ownPlayerIdOf(g.scorerId)!),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  Tr.pick(
                      '${g.minute}\' ${g.scorerName ?? '不明'}${g.assistName != null ? '（アシスト: ${g.assistName}）' : ''}（${teamNameOf(g.teamId)}）',
                      "${g.minute}' ${g.scorerName ?? 'Unknown'}${g.assistName != null ? ' (assist: ${g.assistName})' : ''} (${teamNameOf(g.teamId)})"),
                ),
              ),
            ),
        ],
        if (motmName != null) ...[
          const SizedBox(height: 8),
          InkWell(
            onTap: motmOwnPlayerId == null
                ? null
                : () => openPlayer(motmOwnPlayerId),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Row(
                children: [
                  Icon(Icons.star,
                      color: SemanticColors.ink(dialogContext, Colors.amber,
                          min: 3),
                      size: 18),
                  const SizedBox(width: 4),
                  Expanded(
                      child: Text(Tr.pick('マン・オブ・ザ・マッチ: $motmName',
                          'Man of the match: $motmName'))),
                ],
              ),
            ),
          ),
        ],
      ];
      final stats = MatchStatsBar(
        result: result,
        homeTeamName: teamNameOf(result.homeTeamId),
        awayTeamName: teamNameOf(result.awayTeamId),
      );
      final size = MediaQuery.sizeOf(dialogContext);
      // 横画面は縦が短い。得点者は左、数字は右の2列にし、それでも
      // 収まらなければ中でスクロールする(下が切れて「閉じる」が隠れていた)。
      final wide = size.width > size.height;
      return AlertDialog(
        key: const ValueKey('match-digest'),
        insetPadding: wide
            ? const EdgeInsets.symmetric(horizontal: 32, vertical: 12)
            : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 大会の名前(どの試合の結果か)。
            Text(
              competition,
              key: const ValueKey('match-digest-competition'),
              style: Theme.of(dialogContext).textTheme.labelLarge?.copyWith(
                    color: SemanticColors.subtleText(dialogContext),
                  ),
            ),
            Text(Tr.pick('結果: $resultLabel', 'Result: $resultLabel')),
          ],
        ),
        content: SizedBox(
          width: wide ? 680 : double.maxFinite,
          child: SingleChildScrollView(
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ...head,
                            const SizedBox(height: 8),
                            ...scorers
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(child: stats),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...head,
                      const SizedBox(height: 12),
                      ...scorers,
                      const SizedBox(height: 8),
                      stats,
                    ],
                  ),
          ),
        ),
        actions: [
          FilledButton(
            key: const ValueKey('match-digest-close'),
            style: FilledButton.styleFrom(minimumSize: const Size(120, 48)),
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(Tr.pick('閉じる', 'Close')),
          ),
        ],
      );
    },
  );
}

/// 試合で、期待のメーターがどれだけ動いたか。
class _MeterDelta extends StatelessWidget {
  const _MeterDelta({required this.label, required this.delta});

  final String label;
  final int delta;

  @override
  Widget build(BuildContext context) {
    final color = delta > 0
        ? SemanticColors.positive(context)
        : delta < 0
            ? SemanticColors.negative(context)
            : SemanticColors.neutral(context);
    final text = delta > 0 ? '+$delta' : '$delta';
    return Row(
      children: [
        Text('$label ', style: const TextStyle(fontSize: 13)),
        Text(text,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
