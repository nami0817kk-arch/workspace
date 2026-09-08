import 'dart:math';

import 'package:flutter/material.dart';
import '../l10n/tr.dart';
import '../theme/club_palette.dart';

/// チームIDから決定論的に生成する、実際のロゴ画像を持たない代替のクラブエンブレム。
/// 同じチームなら常に同じ形・色・イニシャルになる。
class ClubEmblem extends StatelessWidget {
  final String teamId;
  final String teamName;
  final double size;

  const ClubEmblem({
    super.key,
    required this.teamId,
    required this.teamName,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final seed = teamId.hashCode;
    // 色の導出は ClubPalette に置いてある。ピッチ上のユニフォームも
    // 同じ値を引くので、ここで独自に計算すると画面ごとに色がずれる。
    final palette = ClubPalette.of(teamId);
    final base = palette.base;
    final accent = palette.accent;
    final shapeIndex = seed.abs() % _EmblemPainter.shapeCount;
    final motifIndex =
        (seed.abs() ~/ _EmblemPainter.shapeCount) % _EmblemPainter.motifCount;
    final initial =
        teamName.trim().isEmpty ? '?' : teamName.trim().substring(0, 1);

    return Semantics(
      label: Tr.pick('$teamNameのエンブレム', '$teamName crest'),
      image: true,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size(size, size),
              painter: _EmblemPainter(
                base: base,
                accent: accent,
                shapeIndex: shapeIndex,
                motifIndex: motifIndex,
              ),
            ),
            Text(
              initial,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: size * 0.4,
                shadows: const [Shadow(color: Colors.black45, blurRadius: 2)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmblemPainter extends CustomPainter {
  final Color base;
  final Color accent;
  final int shapeIndex;
  final int motifIndex;

  const _EmblemPainter({
    required this.base,
    required this.accent,
    required this.shapeIndex,
    required this.motifIndex,
  });

  /// 形と柄の種類数。ここを増やすと、そのぶんクラブの見た目が散る。
  static const int shapeCount = 6;
  static const int motifCount = 6;

  Path _shapePath(Size size) {
    final w = size.width;
    final h = size.height;
    switch (shapeIndex) {
      case 0: // 盾形(シールド)
        return Path()
          ..moveTo(w * 0.5, 0)
          ..lineTo(w, h * 0.2)
          ..lineTo(w, h * 0.55)
          ..quadraticBezierTo(w, h * 0.95, w * 0.5, h)
          ..quadraticBezierTo(0, h * 0.95, 0, h * 0.55)
          ..lineTo(0, h * 0.2)
          ..close();
      case 1: // 六角形
        return Path()
          ..moveTo(w * 0.5, 0)
          ..lineTo(w, h * 0.25)
          ..lineTo(w, h * 0.75)
          ..lineTo(w * 0.5, h)
          ..lineTo(0, h * 0.75)
          ..lineTo(0, h * 0.25)
          ..close();
      case 2: // 円形
        return Path()..addOval(Rect.fromLTWH(0, 0, w, h));
      case 3: // 角丸の四角(近年のクラブに多い簡素な形)
        return Path()
          ..addRRect(RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.04, h * 0.04, w * 0.92, h * 0.92),
            Radius.circular(w * 0.18),
          ));
      case 4: // ひし形
        return Path()
          ..moveTo(w * 0.5, 0)
          ..lineTo(w, h * 0.5)
          ..lineTo(w * 0.5, h)
          ..lineTo(0, h * 0.5)
          ..close();
      default: // 5: 逆さ盾(上が丸く、下が尖る)
        return Path()
          ..moveTo(w * 0.5, h * 0.02)
          ..quadraticBezierTo(w, h * 0.02, w, h * 0.42)
          ..quadraticBezierTo(w, h * 0.78, w * 0.5, h)
          ..quadraticBezierTo(0, h * 0.78, 0, h * 0.42)
          ..quadraticBezierTo(0, h * 0.02, w * 0.5, h * 0.02)
          ..close();
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _shapePath(size);
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [base, accent],
    );
    canvas.drawPath(
      path,
      Paint()..shader = gradient.createShader(Offset.zero & size),
    );

    canvas.save();
    canvas.clipPath(path);
    final w = size.width;
    final h = size.height;
    // 薄すぎると柄が形の中に沈んで、どのクラブも同じに見える。
    final motifPaint = Paint()..color = Colors.white.withValues(alpha: 0.30);
    switch (motifIndex) {
      case 0: // 斜めの帯(サッシュ)
        canvas.save();
        canvas.translate(w / 2, h / 2);
        canvas.rotate(-pi / 5);
        canvas.drawRect(
          Rect.fromCenter(
              center: Offset.zero, width: w * 2, height: h * 0.24),
          motifPaint,
        );
        canvas.restore();
      case 1: // 星
        canvas.drawPath(
          _starPath(Offset(w / 2, h * 0.32), w * 0.18),
          motifPaint,
        );
      case 2: // 横二分割
        canvas.drawRect(Rect.fromLTWH(0, h / 2, w, h / 2), motifPaint);
      case 3: // 縦縞
        for (var i = 0; i < 3; i++) {
          canvas.drawRect(
            Rect.fromLTWH(w * (0.08 + i * 0.30), 0, w * 0.14, h),
            motifPaint,
          );
        }
      case 4: // シェブロン(山形)
        canvas.drawPath(
          Path()
            ..moveTo(0, h * 0.72)
            ..lineTo(w * 0.5, h * 0.34)
            ..lineTo(w, h * 0.72)
            ..lineTo(w, h * 0.92)
            ..lineTo(w * 0.5, h * 0.54)
            ..lineTo(0, h * 0.92)
            ..close(),
          motifPaint,
        );
      default: // 5: 四分割(左上と右下だけ塗る)
        canvas.drawRect(Rect.fromLTWH(0, 0, w / 2, h / 2), motifPaint);
        canvas.drawRect(Rect.fromLTWH(w / 2, h / 2, w / 2, h / 2), motifPaint);
    }
    canvas.restore();

    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.04,
    );
  }

  Path _starPath(Offset center, double radius) {
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final outerAngle = -pi / 2 + i * 2 * pi / 5;
      final innerAngle = outerAngle + pi / 5;
      final outer = center + Offset(cos(outerAngle), sin(outerAngle)) * radius;
      final inner =
          center + Offset(cos(innerAngle), sin(innerAngle)) * radius * 0.45;
      if (i == 0) {
        path.moveTo(outer.dx, outer.dy);
      } else {
        path.lineTo(outer.dx, outer.dy);
      }
      path.lineTo(inner.dx, inner.dy);
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _EmblemPainter oldDelegate) =>
      oldDelegate.base != base ||
      oldDelegate.accent != accent ||
      oldDelegate.shapeIndex != shapeIndex ||
      // motifIndex を見ていなかった。形と色が同じで柄だけ違うクラブが
      // 隣り合うと、描き直されず前のクラブの柄が残る。
      oldDelegate.motifIndex != motifIndex;
}
