import 'package:flutter/material.dart';

import '../../game/game.dart';

/// 成長の軌跡。年齢を横軸に、総合評価(線)と身長(細い線)を描く。
class GrowthChart extends StatelessWidget {
  const GrowthChart({super.key, required this.points, this.height = 140});
  final List<GrowthPoint> points;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) {
      return SizedBox(
        height: height,
        child: const Center(child: Text('1年たつと、成長の軌跡が描かれる。')),
      );
    }
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _ChartPainter(
          points: points,
          line: cs.primary,
          sub: cs.outline,
          text: cs.onSurface,
        ),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter(
      {required this.points,
      required this.line,
      required this.sub,
      required this.text});
  final List<GrowthPoint> points;
  final Color line;
  final Color sub;
  final Color text;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 30.0, bottom = 20.0, top = 8.0, right = 8.0;
    final w = size.width - left - right;
    final h = size.height - bottom - top;
    final minAge = points.first.age.toDouble();
    final maxAge = points.last.age.toDouble();
    final ageSpan = (maxAge - minAge).clamp(1, 100);

    double x(int age) => left + (age - minAge) / ageSpan * w;
    double yOverall(double v) => top + (1 - v.clamp(0, 100) / 100) * h;
    final minH = points.map((p) => p.heightCm).reduce((a, b) => a < b ? a : b);
    final maxH = points.map((p) => p.heightCm).reduce((a, b) => a > b ? a : b);
    final hSpan = (maxH - minH).clamp(1, 200);
    double yHeight(double v) => top + (1 - (v - minH) / hSpan) * h;

    // 目盛りの横線(総合 0・50・100)。
    final grid = Paint()
      ..color = sub.withValues(alpha: 0.25)
      ..strokeWidth = 1;
    for (final v in [0.0, 50.0, 100.0]) {
      canvas.drawLine(Offset(left, yOverall(v)), Offset(size.width - right, yOverall(v)), grid);
      _label(canvas, '${v.round()}', Offset(2, yOverall(v) - 6), 10);
    }

    // 身長(細い線)。
    final hp = Path();
    for (var i = 0; i < points.length; i++) {
      final o = Offset(x(points[i].age), yHeight(points[i].heightCm));
      i == 0 ? hp.moveTo(o.dx, o.dy) : hp.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(
        hp,
        Paint()
          ..color = sub
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);

    // 総合評価(太い線と点)。
    final op = Path();
    for (var i = 0; i < points.length; i++) {
      final o = Offset(x(points[i].age), yOverall(points[i].overall));
      i == 0 ? op.moveTo(o.dx, o.dy) : op.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(
        op,
        Paint()
          ..color = line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round);
    for (final p in points) {
      canvas.drawCircle(Offset(x(p.age), yOverall(p.overall)), 3, Paint()..color = line);
    }

    // 年齢の目盛り(最初・最後と、5歳刻み)。
    for (final p in points) {
      if (p.age == points.first.age || p.age == points.last.age || p.age % 5 == 0) {
        _label(canvas, '${p.age}', Offset(x(p.age) - 6, size.height - bottom + 4), 10);
      }
    }
  }

  void _label(Canvas canvas, String s, Offset at, double size) {
    final tp = TextPainter(
      text: TextSpan(
          text: s,
          style: TextStyle(
              fontFamily: 'NotoSansJP', color: text, fontSize: size)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(_ChartPainter old) => old.points != points;
}
