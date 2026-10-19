import 'dart:math';

import 'package:flutter/material.dart';

/// はじめの画面の絵。夕焼けの空と、ゴールに向かうボール、街のシルエット。
class TitleArt extends StatelessWidget {
  const TitleArt({super.key, this.height = 190});
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(painter: _TitlePainter()),
        ),
      );
}

class _TitlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    // 夕焼けの空。
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF5C6BC0), Color(0xFFFF8A65), Color(0xFFFFCC80)],
          stops: [0.0, 0.65, 1.0],
        ).createShader(Offset.zero & size),
    );

    // 夕日。
    canvas.drawCircle(Offset(w * 0.28, h * 0.62), h * 0.20,
        Paint()..color = const Color(0xFFFFE082).withValues(alpha: 0.9));

    // 街のシルエット。
    final city = Paint()..color = const Color(0xFF37474F);
    final rnd = Random(7);
    var x = 0.0;
    while (x < w) {
      final bw = 18 + rnd.nextDouble() * 26;
      final bh = h * (0.16 + rnd.nextDouble() * 0.20);
      canvas.drawRect(Rect.fromLTWH(x, h * 0.80 - bh, bw, bh + h * 0.2), city);
      x += bw + 2;
    }

    // 地面(コート)。
    canvas.drawRect(Rect.fromLTWH(0, h * 0.80, w, h * 0.2),
        Paint()..color = const Color(0xFFBF7A3A));
    canvas.drawLine(
        Offset(0, h * 0.80),
        Offset(w, h * 0.80),
        Paint()
          ..color = Colors.white70
          ..strokeWidth = 2);

    // ゴール(右)。
    final hx = w * 0.74;
    canvas.drawRect(Rect.fromLTWH(hx + 20, h * 0.18, 6, h * 0.62),
        Paint()..color = const Color(0xFF263238));
    canvas.drawRect(Rect.fromLTWH(hx + 8, h * 0.18, 30, h * 0.20),
        Paint()..color = Colors.white);
    canvas.drawRect(
        Rect.fromLTWH(hx + 8, h * 0.18, 30, h * 0.20),
        Paint()
          ..color = Colors.black26
          ..style = PaintingStyle.stroke);
    final rim = Offset(hx - 18, h * 0.36);
    canvas.drawLine(Offset(hx + 8, h * 0.36), rim,
        Paint()..color = const Color(0xFFE65100)..strokeWidth = 4);
    final net = Paint()
      ..color = Colors.white70
      ..strokeWidth = 1.3;
    for (var i = 0; i < 6; i++) {
      canvas.drawLine(Offset(rim.dx + i * 5, rim.dy),
          Offset(rim.dx + 3 + i * 4, rim.dy + 22), net);
    }

    // ボールの軌跡(放物線の点線)と、ボール。
    final path = Path()..moveTo(w * 0.22, h * 0.70);
    path.quadraticBezierTo(w * 0.42, h * 0.02, rim.dx + 12, rim.dy - 4);
    final dash = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length * 0.78) {
        canvas.drawPath(m.extractPath(d, d + 8), dash);
        d += 16;
      }
    }
    final ball = Offset(w * 0.50, h * 0.215);
    canvas.drawCircle(ball + const Offset(0, 0), 15, Paint()..color = const Color(0xFFE65100));
    final seam = Paint()
      ..color = const Color(0xFF3E2723)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawCircle(ball, 15, seam);
    canvas.drawLine(ball + const Offset(-15, 0), ball + const Offset(15, 0), seam);
    canvas.drawLine(ball + const Offset(0, -15), ball + const Offset(0, 15), seam);
  }

  @override
  bool shouldRepaint(_TitlePainter old) => false;
}
