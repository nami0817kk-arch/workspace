import 'dart:math';

import 'package:flutter/material.dart';

import '../models/attributes.dart';

/// 能力の形。カテゴリを多角形の頂点に並べて、面積で「どんな選手か」を出す。
///
/// 棒が6本並んでいるだけでは、**数字を読まないと選手の形が分からなかった**。
/// 速いのか、上手いのか、強いのか——それは1枚の絵で分かるはずのもの。
/// 棒は残す（正確な値はそちらで読む）。この形は**輪郭を覚えるためのもの**。
///
/// 判定には一切効かない。`Attributes` をそのまま映すだけ。
class AttributeShape extends StatelessWidget {
  const AttributeShape({
    super.key,
    required this.attributes,
    required this.keys,
    this.compareTo,
    this.size = 168,
  });

  final Attributes attributes;

  /// 頂点に並べるカテゴリ。GK かどうかで数が変わる。
  final List<AttributeKey> keys;

  /// 比べる相手（今季の開幕時など）。無ければ描かない。
  final Attributes? compareTo;

  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ShapePainter(
          values: [for (final k in keys) attributes[k]],
          before: compareTo == null
              ? null
              : [for (final k in keys) compareTo![k]],
          labels: [for (final k in keys) k.label],
          fill: theme.colorScheme.primary,
          grid: theme.colorScheme.outlineVariant,
          // **絵の中の文字も、テーマの書体から取る。**
          // `CustomPainter` の中で `TextStyle` を素で作ると同梱フォントに
          // 乗らず、Web で豆腐（□）になる。ここは実際にそうなっていた。
          label: (theme.textTheme.labelSmall ?? const TextStyle()).copyWith(
            fontSize: 9,
            height: 1.25,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          before2: theme.colorScheme.tertiary,
        ),
      ),
    );
  }
}

class _ShapePainter extends CustomPainter {
  _ShapePainter({
    required this.values,
    required this.before,
    required this.labels,
    required this.fill,
    required this.grid,
    required this.label,
    required this.before2,
  });

  final List<int> values;
  final List<int>? before;
  final List<String> labels;
  final Color fill;
  final Color grid;
  final TextStyle label;
  final Color before2;

  /// 目盛りの上限。99 を頂点にすると、普通の選手の形が小さく潰れる。
  static const double ceiling = 100;

  /// 中心に残す穴。0 から描くと、低い能力が1点に集まって形が読めない。
  static const double floor = 0.18;

  @override
  void paint(Canvas canvas, Size size) {
    final n = values.length;
    if (n < 3) return;
    // 文字のぶんだけ内側に描く。
    final radius = size.shortestSide / 2 - 22;
    final center = Offset(size.width / 2, size.height / 2);

    Offset at(int i, double t) {
      final angle = -pi / 2 + 2 * pi * i / n;
      final r = radius * (floor + (1 - floor) * t.clamp(0.0, 1.0));
      return center + Offset(cos(angle) * r, sin(angle) * r);
    }

    // 目盛り。25 刻みで4本。
    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = grid;
    for (final step in [0.25, 0.5, 0.75, 1.0]) {
      final path = Path();
      for (var i = 0; i < n; i++) {
        final p = at(i, step);
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path..close(), gridPaint);
    }
    for (var i = 0; i < n; i++) {
      canvas.drawLine(at(i, 0), at(i, 1.0), gridPaint);
    }

    // 開幕時の形。今季どれだけ膨らんだかが、輪郭の差で分かる。
    if (before != null) {
      final path = Path();
      for (var i = 0; i < n; i++) {
        final p = at(i, before![i] / ceiling);
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
        path..close(),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = before2.withValues(alpha: 0.75),
      );
    }

    // 今の形。
    final path = Path();
    for (var i = 0; i < n; i++) {
      final p = at(i, values[i] / ceiling);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(
        path, Paint()..color = fill.withValues(alpha: 0.22));
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = fill,
    );
    for (var i = 0; i < n; i++) {
      canvas.drawCircle(
          at(i, values[i] / ceiling), 2.5, Paint()..color = fill);
    }

    // 頂点の名前と値。
    for (var i = 0; i < n; i++) {
      final anchor = at(i, 1.0);
      final outward = (anchor - center);
      final painter = TextPainter(
        text: TextSpan(text: '${labels[i]}\n${values[i]}', style: label),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();
      final dir =
          outward.distance == 0 ? Offset.zero : outward / outward.distance;
      final pos =
          anchor + dir * 12 - Offset(painter.width / 2, painter.height / 2);
      painter.paint(canvas, pos);
    }
  }

  @override
  bool shouldRepaint(covariant _ShapePainter old) =>
      old.values.toString() != values.toString() ||
      old.before.toString() != before.toString();
}
