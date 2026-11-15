import 'package:flutter/material.dart';

import '../../gm/career.dart';
import '../../gm/league.dart';
import '../../gm/player.dart';
import 'common.dart';
import 'style.dart';

/// 次の相手の分析(2026-11-15、ユーザー「2Kのプレイ動画とか調べて、質を近づける」。
/// 2K の MyGM にある、次の相手と自分の強み・弱みの比べ)。
/// 能力6つは、けが人を除いた上から8人の平均。勝つ見込みは試合の計算と同じ式(ホーム+1)。
class NextOpponentCard extends StatelessWidget {
  const NextOpponentCard({super.key, required this.car});
  final Career car;

  static List<Player> _top(Team t) => t.order.where((p) => p.injured == 0).take(8).toList();

  static double _avg(List<Player> ps, Attr a) => ps.isEmpty ? 0 : ps.fold(0, (n, p) => n + p.attr(a)) / ps.length;

  @override
  Widget build(BuildContext context) {
    final next = car.upcoming(count: 1);
    if (next.isEmpty) return const SizedBox.shrink();
    final (opp, home) = next.first;
    final me = car.me, them = car.teams[opp];
    final chance = home ? winChance(me.strength, them.strength) : 1 - winChance(them.strength, me.strength);
    final mine = _top(me), theirs = _top(them);
    final diffs = [for (final a in Attr.values) (a, _avg(mine, a) - _avg(theirs, a))];
    final byEdge = [...diffs]..sort((x, y) => x.$2.compareTo(y.$2));
    final theirEdge = byEdge.first, myEdge = byEdge.last;
    final star = [...them.healthy]..sort((a, b) => b.ovr.compareTo(a.ovr));
    final hurt = [for (final p in them.roster) if (p.injured > 0) p]..sort((a, b) => b.ovr.compareTo(a.ovr));
    final r = car.h2h[opp];
    final rank = car.strengthRank(opp) + 1;
    final pct = (chance * 100).round();
    final pctColor = pct >= 60 ? GmColors.good : pct >= 40 ? GmColors.gold : GmColors.bad;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics_rounded, size: 18, color: GmColors.ball),
                const SizedBox(width: 6),
                const Text('次の相手の分析', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                Text(home ? 'ホーム' : 'アウェー', style: const TextStyle(fontSize: 11, color: GmColors.sub)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                TeamBadge(team: opp, size: 34),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(them.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        '${record(them)}・強さ$rank位${r == null || r[0] + r[1] == 0 ? '' : '・通算の対戦 ${r[0]}勝${r[1]}敗'}',
                        style: const TextStyle(fontSize: 11, color: GmColors.sub),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: pct.toDouble()),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutCubic,
                      builder: (context, v, _) => Text(
                        '${v.round()}%',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: pctColor),
                      ),
                    ),
                    const Text('勝つ見込み', style: TextStyle(fontSize: 10, color: GmColors.sub)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            // 能力6つの比べ(中央から、こちらが上なら右へ橙、相手が上なら左へ青)
            for (final (a, d) in diffs)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 1.5),
                child: Row(
                  children: [
                    SizedBox(
                      width: 78,
                      child: Text(a.label, style: const TextStyle(fontSize: 11, color: GmColors.sub)),
                    ),
                    Expanded(child: _EdgeBar(d: d)),
                    SizedBox(
                      width: 34,
                      child: Text(
                        '${d >= 0 ? '+' : ''}${d.toStringAsFixed(1)}',
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: d >= 0 ? GmColors.ball : const Color(0xFF8FD3FF)),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            Text(
              [
                if (theirEdge.$2 < -0.5) '相手の強みは${theirEdge.$1.label}',
                if (myEdge.$2 > 0.5) 'こちらは${myEdge.$1.label}で上回る',
                if (star.isNotEmpty) '要注意は${star.first.name}(${star.first.pos.short}・OVR${shown(star.first.ovr)}・${star.first.stats.gp > 0 ? star.first.stats.line : '今季まだ出場なし'})',
                if (hurt.isNotEmpty) '相手は${hurt.first.name}${hurt.length > 1 ? 'ら${hurt.length}人' : ''}がけがで欠場',
              ].join('。'),
              style: const TextStyle(fontSize: 11, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// 中央から左右に伸びる差の帯(±12で端まで。弱い相手でも差が見分けられる幅)。
class _EdgeBar extends StatelessWidget {
  const _EdgeBar({required this.d});
  final double d;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 8,
    child: LayoutBuilder(
      builder: (context, cons) {
        final half = cons.maxWidth / 2;
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: (d / 12).clamp(-1.0, 1.0)),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) => Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(color: GmColors.line.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(3)),
                ),
              ),
              Positioned(left: half - 0.5, top: 0, bottom: 0, width: 1, child: Container(color: GmColors.sub)),
              Positioned(
                left: v >= 0 ? half : half + v * half,
                width: (v.abs() * half).clamp(0.0, half),
                top: 1,
                bottom: 1,
                child: Container(
                  decoration: BoxDecoration(color: v >= 0 ? GmColors.ball : const Color(0xFF8FD3FF), borderRadius: BorderRadius.circular(2)),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
