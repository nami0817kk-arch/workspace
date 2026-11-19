import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/economy_scale.dart';
import '../state/game_state.dart';
import '../theme/semantic_colors.dart';

/// 1本の折れ線(シーズンごとの値)。[lowerIsBetter]なら上下を逆に描く
/// (順位は小さいほど上)。
class TrendChart extends StatelessWidget {
  final String title;
  final List<(int season, double value)> points;
  final String Function(double) format;
  final bool lowerIsBetter;
  final Color color;

  const TrendChart({
    super.key,
    required this.title,
    required this.points,
    required this.format,
    required this.color,
    this.lowerIsBetter = false,
  });

  @override
  Widget build(BuildContext context) {
    final small =
        TextStyle(fontSize: 11, color: SemanticColors.subtleText(context));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        SizedBox(
          height: 90,
          child: points.length < 2
              ? Center(
                  child: Text(
                      Tr.pick('2季以上たつと線になります', 'A line appears after two seasons'),
                      style: small))
              : CustomPaint(
                  size: Size.infinite,
                  painter: _LinePainter(
                    values: [for (final p in points) p.$2],
                    color: color,
                    invert: lowerIsBetter,
                    grid: SemanticColors.subtleText(context).withValues(alpha: 0.3),
                  ),
                ),
        ),
        if (points.isNotEmpty)
          Text(
            Tr.pick(
                '第${points.first.$1}季 ${format(points.first.$2)} → 第${points.last.$1}季 ${format(points.last.$2)}',
                'Season ${points.first.$1} ${format(points.first.$2)} -> season ${points.last.$1} ${format(points.last.$2)}'),
            style: small,
          ),
      ],
    );
  }
}

class _LinePainter extends CustomPainter {
  final List<double> values;
  final Color color;
  final Color grid;
  final bool invert;
  _LinePainter(
      {required this.values,
      required this.color,
      required this.grid,
      required this.invert});

  @override
  void paint(Canvas canvas, Size size) {
    final lo = values.reduce(min);
    final hi = values.reduce(max);
    final span = hi - lo == 0 ? 1.0 : hi - lo;
    double y(double v) {
      final t = (v - lo) / span;
      final f = invert ? t : 1 - t;
      return 6 + f * (size.height - 12);
    }

    final g = Paint()
      ..color = grid
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, size.height / 2),
        Offset(size.width, size.height / 2), g);
    final step = size.width / (values.length - 1);
    final path = Path()..moveTo(0, y(values.first));
    for (var i = 1; i < values.length; i++) {
      path.lineTo(i * step, y(values[i]));
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    final dot = Paint()..color = color;
    for (var i = 0; i < values.length; i++) {
      canvas.drawCircle(Offset(i * step, y(values[i])), 3, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) =>
      old.values != values || old.color != color;
}

/// シーズンごとの推移(順位・クラブ価値・営業収入・損益)。
class TrendsCard extends StatelessWidget {
  const TrendsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final save = gs.save;
    if (save == null) return const SizedBox.shrink();
    final mine = save.seasonHistory
        .where((r) => r.clubName == save.clubName)
        .toList()
      ..sort((a, b) => a.season.compareTo(b.season));
    // 部をまたいでも比べられるよう、全部の部を通した位置(1部1位が1)で描く。
    final rank = [
      for (final r in mine)
        (r.season, ((r.divisionTier - 1) * r.teamCount + r.finalRank).toDouble()),
    ];
    final value = [
      for (final e in (save.clubValueHistory.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key))))
        (e.key, e.value.toDouble()),
    ];
    final ledgers = gs.pastLedgers;
    final income = [
      for (final l in ledgers) (l.season, l.operatingIncome.toDouble()),
    ];
    final profit = [
      for (final l in ledgers) (l.season, l.profit.toDouble()),
    ];
    final scheme = Theme.of(context).colorScheme;
    String money(double v) => formatMoney(v.round());
    final charts = [
      TrendChart(
        title: Tr.pick('順位(全部の部を通した位置)', 'Position across all divisions'),
        points: rank,
        format: (v) => Tr.pick('${v.round()}番目', 'no. ${v.round()}'),
        lowerIsBetter: true,
        color: scheme.primary,
      ),
      TrendChart(
        title: Tr.pick('クラブ価値', 'Club value'),
        points: value,
        format: money,
        color: Colors.indigo,
      ),
      TrendChart(
        title: Tr.pick('営業収入', 'Operating income'),
        points: income,
        format: money,
        color: Colors.teal,
      ),
      TrendChart(
        title: Tr.pick('損益', 'Result'),
        points: profit,
        format: money,
        color: Colors.deepOrange,
      ),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Tr.pick('推移', 'Trends'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            LayoutBuilder(builder: (context, c) {
              // 横に広ければ2列。
              final cols = c.maxWidth >= 600 ? 2 : 1;
              final w = (c.maxWidth - (cols - 1) * 12) / cols;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final ch in charts) SizedBox(width: w, child: ch),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}
