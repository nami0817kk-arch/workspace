import 'dart:math';

import 'package:flutter/material.dart';

/// 紙吹雪。一度だけ降る。
class Confetti extends StatefulWidget {
  const Confetti(
      {super.key,
      this.duration = const Duration(milliseconds: 2800),
      this.count = 70});
  final Duration duration;
  final int count;

  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration);

  @override
  void initState() {
    super.initState();
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          painter: ConfettiPainter(_c.value, widget.count),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class ConfettiPainter extends CustomPainter {
  ConfettiPainter(this.t, this.count);
  final double t;
  final int count;

  static const _colors = [
    Color(0xFFE53935),
    Color(0xFFFDD835),
    Color(0xFF43A047),
    Color(0xFF1E88E5),
    Color(0xFFFB8C00),
    Color(0xFF8E24AA),
    Color(0xFFFFFFFF),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(11);
    final fade = t > 0.8 ? 1 - (t - 0.8) / 0.2 : 1.0;
    for (var i = 0; i < count; i++) {
      final x0 = rng.nextDouble();
      final speed = 0.6 + rng.nextDouble() * 0.9;
      final phase = rng.nextDouble() * 2 * pi;
      final sz = 4 + rng.nextDouble() * 5;
      final rot = rng.nextDouble() * 2 * pi;
      final color = _colors[i % _colors.length];
      final y = -12 + (size.height + 24) * (t * speed);
      final x = x0 * size.width + sin(t * 7 + phase) * 16;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rot + t * 9);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: sz, height: sz * 0.55),
        Paint()..color = color.withValues(alpha: fade.clamp(0.0, 1.0)),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(ConfettiPainter old) => old.t != t;
}
