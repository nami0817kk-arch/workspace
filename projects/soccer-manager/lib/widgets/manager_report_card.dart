import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/club_health_engine.dart';
import '../logic/manager_report_engine.dart';
import '../state/game_state.dart';
import '../theme/semantic_colors.dart';
import 'fm_panel.dart';

/// 2つの期待(サポーター・株主)のメーター。0〜100 のバーと数字。
class ExpectationMeters extends StatelessWidget {
  const ExpectationMeters({super.key, this.compact = false});

  /// 上バー用の小さい作り。
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final save = context.watch<GameState>().save;
    if (save == null) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Meter(
            label: Tr.pick('サポーター', 'Fans'),
            value: save.confidence,
            compact: compact),
        SizedBox(height: compact ? 2 : 6),
        _Meter(
            label: Tr.pick('株主', 'Shareholders'),
            value: save.shareholderExpectation,
            compact: compact),
      ],
    );
  }
}

class _Meter extends StatelessWidget {
  const _Meter(
      {required this.label, required this.value, required this.compact});

  final String label;
  final int value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0, 100);
    final color = v <= ManagerReportEngine.dangerLine
        ? SemanticColors.negative(context)
        : v >= ManagerReportEngine.goodLine
            ? SemanticColors.positive(context)
            : Theme.of(context).colorScheme.primary;
    final size = compact ? 11.0 : 13.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: compact ? 62 : 80,
          // 英語(Shareholders)や大きい文字でも折り返さず、縮めて1行に収める。
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(label, maxLines: 1, style: TextStyle(fontSize: size)),
          ),
        ),
        // 見出しとバーの間。英語の「Shareholders」は欄いっぱいに縮むので、
        // バーにくっついていた(2026-11-23)。
        SizedBox(width: compact ? 4 : 8),
        SizedBox(
          width: compact ? 70 : 140,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: v / 100,
              minHeight: compact ? 6 : 8,
              color: color,
              backgroundColor: color.withValues(alpha: 0.15),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text('$v',
            style: TextStyle(
                fontSize: size, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

/// 監督からの週次報告。状況ページの先頭に置く。
class ManagerReportCard extends StatelessWidget {
  const ManagerReportCard({super.key, required this.weeklyNet});

  /// 週の収支(万円)。ホームが計算した値を受け取る。
  final int weeklyNet;

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final save = game.save;
    if (save == null) return const SizedBox.shrink();
    final league = save.league;
    final standings = league.sortedStandings;
    final rank = standings.indexWhere((r) => r.teamId == save.userTeamId) + 1;

    String? lastResult;
    for (final f in league.fixtures.reversed) {
      final r = f.result;
      if (r == null) continue;
      if (f.homeTeamId != save.userTeamId && f.awayTeamId != save.userTeamId) {
        continue;
      }
      final home = f.homeTeamId == save.userTeamId;
      final mine = home ? r.homeGoals : r.awayGoals;
      final theirs = home ? r.awayGoals : r.homeGoals;
      final word = mine > theirs
          ? Tr.pick('勝ち', 'Win')
          : mine < theirs
              ? Tr.pick('負け', 'Loss')
              : Tr.pick('引き分け', 'Draw');
      lastResult = '$word $mine-$theirs';
      break;
    }

    final report = ManagerReportEngine.build(
      rank: rank,
      teamCount: standings.length,
      tier: save.currentDivisionTier,
      supporter: save.confidence,
      shareholder: save.shareholderExpectation,
      budget: save.budget,
      weeklyNet: weeklyNet,
      lastResult: lastResult,
    );
    final health = ClubHealthEngine.assess(
      supporter: save.confidence,
      shareholder: save.shareholderExpectation,
      wageRatio:
          league.fixtures.isEmpty ? 0 : save.ledgerFor(league.season).wageRatio,
      budget: save.budget,
    );
    return FmPanel(
      title: Tr.pick('監督からの報告', 'Report from the manager'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ひとことと経営診断だけ。順位・直近・収支・2つの期待は、帯・上バー・
          // 右の箱に出ているので、ここでは繰り返さない(2026-11-21)。
          Text(report.headline,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          _HealthLine(health: health),
        ],
      ),
    );
  }
}

/// 経営診断の1行。点数とA〜Eの評価。
class _HealthLine extends StatelessWidget {
  const _HealthLine({required this.health});

  final ClubHealth health;

  @override
  Widget build(BuildContext context) {
    final color = switch (health.grade) {
      'A' || 'B' => SemanticColors.positive(context),
      'C' => SemanticColors.neutral(context),
      _ => SemanticColors.negative(context),
    };
    return Row(
      children: [
        Text(Tr.pick('経営診断 ', 'Club health '),
            style: const TextStyle(fontSize: 13)),
        Text(health.grade,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(width: 6),
        Text('${health.score}/100',
            style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
