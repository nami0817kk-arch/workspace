import 'dart:math';

import 'package:flutter/material.dart';

import '../../game/career.dart';
import '../labels.dart';

/// 人生のグラフ: 6歳からの総合評価の推移。背景はランクの帯、プロ入りに縦線。
class CareerChart extends StatelessWidget {
  const CareerChart(
      {super.key, required this.history, this.proStartAge, this.height = 200});

  /// [0] が6歳。以降は1年ごと。
  final List<int> history;
  final int? proStartAge;
  final double height;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      label: '総合評価の推移。${history.first}から${history.last}まで',
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 1200),
          curve: Curves.easeOutCubic,
          builder: (context, t, _) => CustomPaint(
            painter: CareerChartPainter(
              history: history,
              proStartAge: proStartAge,
              progress: t,
              line: cs.primary,
              text: cs.onSurfaceVariant,
              marker: cs.tertiary,
            ),
          ),
        ),
      ),
    );
  }
}

class CareerChartPainter extends CustomPainter {
  CareerChartPainter({
    required this.history,
    required this.proStartAge,
    required this.progress,
    required this.line,
    required this.text,
    required this.marker,
  });

  final List<int> history;
  final int? proStartAge;
  final double progress;
  final Color line;
  final Color text;
  final Color marker;

  @override
  void paint(Canvas canvas, Size size) {
    if (history.length < 2) return;
    const left = 34.0, right = 10.0, top = 8.0, bottom = 24.0;
    final w = size.width - left - right;
    final h = size.height - top - bottom;
    final lastAge = startAge + history.length - 1;
    double xOf(int age) => left + w * (age - startAge) / (lastAge - startAge);
    double yOf(num v) => top + h * (1 - v.clamp(0, 99) / 99);

    // ランクの帯
    const bands = [
      (0, 'G'),
      (30, 'F'),
      (40, 'E'),
      (50, 'D'),
      (60, 'C'),
      (70, 'B'),
      (80, 'A'),
      (90, 'S')
    ];
    for (var i = 0; i < bands.length; i++) {
      final lo = bands[i].$1;
      final hi = i + 1 < bands.length ? bands[i + 1].$1 : 99;
      final c = rankColor(bands[i].$2);
      canvas.drawRect(
        Rect.fromLTRB(left, yOf(hi), left + w, yOf(lo)),
        Paint()..color = c.withValues(alpha: 0.10),
      );
      _text(canvas, bands[i].$2, Offset(left - 14, (yOf(hi) + yOf(lo)) / 2), c,
          bold: true);
    }

    // 横軸の年齢
    for (var age = startAge; age <= lastAge; age += 6) {
      _text(canvas, '$age', Offset(xOf(age), size.height - 10), text);
    }

    // プロ入りの縦線
    final pro = proStartAge;
    if (pro != null && pro >= startAge && pro <= lastAge) {
      final x = xOf(pro);
      final dash = Paint()
        ..color = marker
        ..strokeWidth = 1.5;
      for (var y = top; y < top + h; y += 8) {
        canvas.drawLine(Offset(x, y), Offset(x, min(y + 4, top + h)), dash);
      }
      _text(canvas, 'プロ入り', Offset(x, top + 6), marker, bold: true);
    }

    // 折れ線(進行に合わせて伸びる)
    final upTo = (history.length - 1) * progress;
    final whole = upTo.floor();
    final path = Path();
    final pts = <Offset>[
      for (var i = 0; i <= whole; i++)
        Offset(xOf(startAge + i), yOf(history[i])),
    ];
    if (whole < history.length - 1) {
      final f = upTo - whole;
      final v = history[whole] + (history[whole + 1] - history[whole]) * f;
      final x0 = xOf(startAge + whole), x1 = xOf(startAge + whole + 1);
      pts.add(Offset(x0 + (x1 - x0) * f, yOf(v)));
    }
    for (var i = 0; i < pts.length; i++) {
      i == 0
          ? path.moveTo(pts[i].dx, pts[i].dy)
          : path.lineTo(pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = line
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    if (pts.isNotEmpty) {
      canvas.drawCircle(pts.last, 5, Paint()..color = line);
      canvas.drawCircle(
          pts.last,
          5,
          Paint()
            ..style = PaintingStyle.stroke
            ..color = Colors.white
            ..strokeWidth = 2);
    }
  }

  void _text(Canvas c, String s, Offset center, Color color,
      {bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(
          text: s,
          style: TextStyle(
              fontFamily: kFont,
              fontSize: 11,
              color: color,
              fontWeight: bold ? FontWeight.bold : null)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(CareerChartPainter old) =>
      old.progress != progress ||
      old.history != history ||
      old.proStartAge != proStartAge;
}
