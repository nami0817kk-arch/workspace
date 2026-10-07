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
    final palette = ClubPalette.of(teamId, clubName: teamName);
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
            // 頭文字。濃い縁取りを敷いた上に白を重ねる。影だけだと、
            // 明るい地の色(黄土・薄緑)の上で輪郭が沈んでいた。
            Text(
              initial,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: size * 0.38,
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = size * 0.07
                  ..strokeJoin = StrokeJoin.round
                  ..color = _darken(base, 0.45),
              ),
            ),
            Text(
              initial,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: size * 0.38,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 明度を [factor] 倍する。縁取りと内側の縁に使う。
Color _darken(Color c, double factor) {
  final hsl = HSLColor.fromColor(c);
  return hsl.withLightness((hsl.lightness * factor).clamp(0.0, 1.0)).toColor();
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
          // 頭文字に重ならない高さに置く。以前は文字の裏に隠れていた。
          _starPath(Offset(w / 2, h * 0.21), w * 0.13),
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
    // 上を明るく、下を暗くする。平らな塗りのままだと、紋章ではなく
    // 色の付いた図形に見える。
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x38FFFFFF), Color(0x00FFFFFF), Color(0x2B000000)],
          stops: [0.0, 0.46, 1.0],
        ).createShader(Offset.zero & size),
    );
    canvas.restore();

    // 縁は二重にする。濃い縁の中央に細い白を通すのは実際の紋章の作りで、
    // これだけで「図形」から「エンブレム」に見え方が変わる。黒の半透明を
    // 1本引いていた頃は、背景と混ざって灰色のふちどりに見えていた。
    canvas.drawPath(
      path,
      Paint()
        ..color = _darken(base, 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.075,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.82)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.022,
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
