import 'dart:math';

import 'package:flutter/material.dart';

import '../../game/player.dart';
import '../labels.dart';

/// 能力のレーダーチャート。値が変わると、なめらかに形が変わる。
class AbilityRadar extends StatelessWidget {
  const AbilityRadar({super.key, required this.player, this.size = 240});
  final Player player;
  final double size;

  @override
  Widget build(BuildContext context) {
    final abilities = abilitiesOf(player.role);
    final raw = [for (final a in abilities) player.of(a)];
    // 外枠は、いちばん高い能力より少し上にする(序盤でも形が読めるように)。
    final scale = radarScale(raw.reduce((a, b) => a > b ? a : b));
    final values = [for (final v in raw) v.toDouble(), scale.toDouble()];
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      label: '能力: ${[
        for (final a in abilities) '${abilityLabel(a)} ${player.of(a)}'
      ].join('、')}',
      child: SizedBox(
        height: size,
        width: double.infinity,
        child: TweenAnimationBuilder<List<double>>(
          tween: _ValuesTween(end: values),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          builder: (context, tweened, _) {
            // 役割が変わった直後は、アニメの始点が前の役割の長さのまま来る。長さが違えば今の値を使う。
            final v = tweened.length == values.length ? tweened : values;
            return CustomPaint(
              painter: RadarPainter(
                labels: [for (final a in abilities) abilityLabel(a)],
                values: v.sublist(0, v.length - 1),
                scale: v.last,
                accent: cs.primary,
                grid: cs.outlineVariant,
                text: cs.onSurface,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// レーダーの外枠。最高値より10上を10刻みで切り上げ、最低でも50、最大99。
double radarScale(int maxValue) {
  final s = ((maxValue + 10) / 10).ceil() * 10;
  return s.clamp(50, 99).toDouble();
}

class _ValuesTween extends Tween<List<double>> {
  _ValuesTween({required List<double> end}) : super(end: end);

  @override
  List<double> lerp(double t) {
    final e = end!;
    final b = begin;
    if (b == null || b.length != e.length) return e;
    return [for (var i = 0; i < e.length; i++) b[i] + (e[i] - b[i]) * t];
  }
}

class RadarPainter extends CustomPainter {
  RadarPainter({
    required this.labels,
    required this.values,
    required this.scale,
    required this.accent,
    required this.grid,
    required this.text,
  });

  final List<String> labels;
  final List<double> values;

  /// 外枠にあたる値(25ごとに格子を引く)。
  final double scale;
  final Color accent;
  final Color grid;
  final Color text;

  @override
  void paint(Canvas canvas, Size size) {
    final n = values.length;
    if (n < 3) return;
    final c = size.center(Offset.zero);
    final r = min(size.width, size.height) * 0.34;
    Offset at(int i, double f) {
      final a = -pi / 2 + 2 * pi * i / n;
      return c + Offset(cos(a), sin(a)) * (r * f);
    }

    // 格子: 外枠の 25・50・75・100%
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..color = grid
      ..strokeWidth = 1;
    for (final f in [0.25, 0.5, 0.75, 1.0]) {
      final path = Path()..moveTo(at(0, f).dx, at(0, f).dy);
      for (var i = 1; i < n; i++) {
        path.lineTo(at(i, f).dx, at(i, f).dy);
      }
      path.close();
      canvas.drawPath(path, ring);
    }
    for (var i = 0; i < n; i++) {
      canvas.drawLine(c, at(i, 1), ring);
    }

    // 能力の多角形
    final poly = Path();
    for (var i = 0; i < n; i++) {
      final o = at(i, (values[i] / scale).clamp(0.0, 1.0));
      i == 0 ? poly.moveTo(o.dx, o.dy) : poly.lineTo(o.dx, o.dy);
    }
    poly.close();
    canvas.drawPath(poly, Paint()..color = accent.withValues(alpha: 0.28));
    canvas.drawPath(
      poly,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = accent
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );

    for (var i = 0; i < n; i++) {
      final v = values[i].round();
      final o = at(i, (values[i] / scale).clamp(0.0, 1.0));
      canvas.drawCircle(o, 5, Paint()..color = rankColor(rankOf(v)));
      canvas.drawCircle(
          o,
          5,
          Paint()
            ..style = PaintingStyle.stroke
            ..color = Colors.white
            ..strokeWidth = 1.5);

      // 名前とランクを外側に。
      final lp = at(i, 1.0) + (at(i, 1.0) - c) / r * 22;
      final tp = TextPainter(
        text: TextSpan(children: [
          TextSpan(
              text: labels[i],
              style: TextStyle(fontFamily: kFont, fontSize: 12, color: text)),
          TextSpan(
            text: '\n${rankOf(v)}  $v',
            style: TextStyle(
                fontFamily: kFont,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: rankColor(rankOf(v))),
          ),
        ]),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, lp - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(RadarPainter old) =>
      old.values != values ||
      old.scale != scale ||
      old.accent != accent ||
      old.grid != grid ||
      old.text != text;
}
