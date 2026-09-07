import 'dart:math';

import 'package:flutter/material.dart';

import '../models/player.dart';
import 'position_colors.dart';

/// 選手IDから決定論的に生成する、実際の顔写真を持たない代替の似顔絵。
/// ポジション別カラーのリングで縁取り、一目でポジションも分かるようにする。
class PlayerFaceAvatar extends StatelessWidget {
  final String playerId;
  final Position position;
  final double size;
  final bool highlighted;

  const PlayerFaceAvatar({
    super.key,
    required this.playerId,
    required this.position,
    this.size = 40,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final ringColor = position.group.color;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ringColor, width: highlighted ? 2.5 : 1.5),
      ),
      padding: const EdgeInsets.all(1.5),
      child: ClipOval(
        child: CustomPaint(
          size: Size.square(size),
          painter: FacePainter(seed: playerId.hashCode),
        ),
      ),
    );
  }
}

/// 1人分の顔の作り。IDから決まる。
///
/// 髪と肌の色だけを振っていた頃は、全員が同じ顔に違う髪を載せただけに
/// 見えていた。輪郭・目・眉・口も振ることで、名簿を眺めたときに
/// 別人が並んでいるように見える。
class FaceFeatures {
  final int skinIndex;
  final int hairIndex;
  final int hairStyle;
  final int facialHair;
  final int eyeStyle;
  final int mouthStyle;

  /// 顔の横幅(輪郭の広さ)。丸顔と面長を作り分ける。
  final double faceWidth;

  /// 顔の縦の長さ。
  final double faceHeight;

  /// 両目の間隔。
  final double eyeSpread;

  /// 眉の角度。上がり眉と下がり眉。
  final double browTilt;

  /// 背景の色相。
  final double backgroundHue;

  const FaceFeatures({
    required this.skinIndex,
    required this.hairIndex,
    required this.hairStyle,
    required this.facialHair,
    required this.eyeStyle,
    required this.mouthStyle,
    required this.faceWidth,
    required this.faceHeight,
    required this.eyeSpread,
    required this.browTilt,
    required this.backgroundHue,
  });

  static const int hairStyleCount = 6;
  static const int facialHairCount = 4;
  static const int eyeStyleCount = 3;
  static const int mouthStyleCount = 3;

  factory FaceFeatures.fromSeed(int seed) {
    final rng = Random(seed);
    return FaceFeatures(
      skinIndex: rng.nextInt(FacePainter.skinTones.length),
      hairIndex: rng.nextInt(FacePainter.hairColors.length),
      hairStyle: rng.nextInt(hairStyleCount),
      facialHair: rng.nextInt(facialHairCount),
      eyeStyle: rng.nextInt(eyeStyleCount),
      mouthStyle: rng.nextInt(mouthStyleCount),
      faceWidth: 0.78 + rng.nextDouble() * 0.16,
      faceHeight: 0.86 + rng.nextDouble() * 0.14,
      eyeSpread: 0.11 + rng.nextDouble() * 0.05,
      browTilt: -0.035 + rng.nextDouble() * 0.07,
      backgroundHue: rng.nextDouble() * 360,
    );
  }
}

class FacePainter extends CustomPainter {
  final int seed;

  const FacePainter({required this.seed});

  static const skinTones = [
    Color(0xFFFFDBAC),
    Color(0xFFF1C27D),
    Color(0xFFE0AC69),
    Color(0xFFC68642),
    Color(0xFF8D5524),
  ];

  static const hairColors = [
    Color(0xFF1B1B1B),
    Color(0xFF3B2314),
    Color(0xFF6B4226),
    Color(0xFFB55239),
    Color(0xFFD4C4A8),
    Color(0xFF4A4A4A),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final f = FaceFeatures.fromSeed(seed);
    final w = size.width;
    final h = size.height;

    final skin = skinTones[f.skinIndex];
    final hair = hairColors[f.hairIndex];
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = HSLColor.fromAHSL(1, f.backgroundHue, 0.35, 0.88).toColor(),
    );

    // 耳と輪郭。輪郭の幅と高さを振ることで、丸顔と面長ができる。
    final skinPaint = Paint()..color = skin;
    final earY = h * 0.52;
    final earX = w * (0.5 - f.faceWidth / 2 + 0.04);
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(earX, earY), width: w * 0.13, height: h * 0.17),
      skinPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(w - earX, earY), width: w * 0.13, height: h * 0.17),
      skinPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.54),
        width: w * f.faceWidth,
        height: h * f.faceHeight,
      ),
      skinPaint,
    );

    _paintHair(canvas, size, f, hair);
    _paintBrows(canvas, size, f, hair);
    _paintEyes(canvas, size, f);
    _paintNose(canvas, size);
    _paintMouth(canvas, size, f);
    _paintFacialHair(canvas, size, f, hair);
  }

  void _paintHair(Canvas canvas, Size size, FaceFeatures f, Color hair) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()..color = hair;
    final hairWidth = w * (f.faceWidth + 0.05);

    switch (f.hairStyle) {
      case 0: // 短髪
        canvas.drawArc(
          Rect.fromCenter(
              center: Offset(w * 0.5, h * 0.42),
              width: hairWidth,
              height: h * 0.7),
          pi,
          pi,
          true,
          paint,
        );
      case 1: // サイド分け
        canvas.drawArc(
          Rect.fromCenter(
              center: Offset(w * 0.5, h * 0.40),
              width: hairWidth,
              height: h * 0.82),
          pi,
          pi,
          true,
          paint,
        );
        canvas.drawRect(
          Rect.fromLTWH(w * 0.06, h * 0.30, w * 0.28, h * 0.14),
          paint,
        );
      case 2: // くせ毛・アフロ
        for (double t = 0; t <= 1; t += 0.12) {
          final angle = pi + t * pi;
          canvas.drawCircle(
            Offset(w * 0.5 + cos(angle) * hairWidth * 0.5,
                h * 0.42 + sin(angle) * h * 0.4),
            w * 0.12,
            paint,
          );
        }
      case 3: // 生え際が後退している
        canvas.drawArc(
          Rect.fromCenter(
              center: Offset(w * 0.5, h * 0.40),
              width: hairWidth,
              height: h * 0.58),
          pi,
          pi,
          true,
          Paint()..color = hair.withValues(alpha: 0.55),
        );
      case 4: // 長髪(耳を覆う)
        canvas.drawArc(
          Rect.fromCenter(
              center: Offset(w * 0.5, h * 0.44),
              width: hairWidth,
              height: h * 0.86),
          pi,
          pi,
          true,
          paint,
        );
        for (final side in const [true, false]) {
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(w * (side ? 0.14 : 0.86), h * 0.56),
              width: w * 0.20,
              height: h * 0.46,
            ),
            paint,
          );
        }
      default: // 5: 刈り上げ(トップだけ残す)
        canvas.drawArc(
          Rect.fromCenter(
              center: Offset(w * 0.5, h * 0.36),
              width: hairWidth * 0.86,
              height: h * 0.52),
          pi,
          pi,
          true,
          paint,
        );
        canvas.drawArc(
          Rect.fromCenter(
              center: Offset(w * 0.5, h * 0.44),
              width: hairWidth,
              height: h * 0.66),
          pi,
          pi,
          true,
          Paint()..color = hair.withValues(alpha: 0.32),
        );
    }
  }

  void _paintBrows(Canvas canvas, Size size, FaceFeatures f, Color hair) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()
      ..color = hair
      ..strokeWidth = h * 0.035
      ..strokeCap = StrokeCap.round;
    final inner = 0.5 - f.eyeSpread + 0.02;
    final outer = 0.5 - f.eyeSpread - 0.08;
    canvas.drawLine(
      Offset(w * outer, h * (0.46 - f.browTilt)),
      Offset(w * inner, h * (0.45 + f.browTilt)),
      paint,
    );
    canvas.drawLine(
      Offset(w * (1 - inner), h * (0.45 + f.browTilt)),
      Offset(w * (1 - outer), h * (0.46 - f.browTilt)),
      paint,
    );
  }

  void _paintEyes(Canvas canvas, Size size, FaceFeatures f) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()..color = const Color(0xFF2B2B2B);
    final left = Offset(w * (0.5 - f.eyeSpread), h * 0.52);
    final right = Offset(w * (0.5 + f.eyeSpread), h * 0.52);
    switch (f.eyeStyle) {
      case 0: // 丸い目
        canvas.drawCircle(left, w * 0.05, paint);
        canvas.drawCircle(right, w * 0.05, paint);
      case 1: // 細い目
        for (final c in [left, right]) {
          canvas.drawOval(
            Rect.fromCenter(center: c, width: w * 0.11, height: h * 0.045),
            paint,
          );
        }
      default: // 2: 小さめの目
        canvas.drawCircle(left, w * 0.035, paint);
        canvas.drawCircle(right, w * 0.035, paint);
    }
  }

  void _paintNose(Canvas canvas, Size size) {
    canvas.drawLine(
      Offset(size.width * 0.5, size.height * 0.54),
      Offset(size.width * 0.5, size.height * 0.64),
      Paint()
        ..color = const Color(0xFF000000).withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.height * 0.02,
    );
  }

  void _paintMouth(Canvas canvas, Size size, FaceFeatures f) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()
      ..color = const Color(0xFF7A3B3B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = h * 0.035
      ..strokeCap = StrokeCap.round;
    final path = Path()..moveTo(w * 0.38, h * 0.74);
    switch (f.mouthStyle) {
      case 0: // 口角が上がっている
        path.quadraticBezierTo(w * 0.5, h * 0.79, w * 0.62, h * 0.74);
      case 1: // 真一文字
        path.lineTo(w * 0.62, h * 0.74);
      default: // 2: 口角がわずかに下がっている
        // ここを深く曲げると、名簿がしかめ面ばかりになる。差が分かる
        // 範囲でいちばん浅くしてある。
        path.quadraticBezierTo(w * 0.5, h * 0.725, w * 0.62, h * 0.75);
    }
    canvas.drawPath(path, paint);
  }

  void _paintFacialHair(Canvas canvas, Size size, FaceFeatures f, Color hair) {
    final w = size.width;
    final h = size.height;
    switch (f.facialHair) {
      case 1: // 無精ひげ(顎まわりを薄く)
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.30, h * 0.62)
            ..quadraticBezierTo(w * 0.5, h * 0.94, w * 0.70, h * 0.62)
            ..quadraticBezierTo(w * 0.5, h * 0.82, w * 0.30, h * 0.62),
          Paint()..color = hair.withValues(alpha: 0.35),
        );
      case 2: // 顎ひげ
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.34, h * 0.64)
            ..quadraticBezierTo(w * 0.5, h * 0.90, w * 0.66, h * 0.64)
            ..quadraticBezierTo(w * 0.5, h * 0.80, w * 0.34, h * 0.64),
          Paint()..color = hair.withValues(alpha: 0.85),
        );
      case 3: // 口ひげ
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.38, h * 0.70)
            ..quadraticBezierTo(w * 0.5, h * 0.66, w * 0.62, h * 0.70)
            ..quadraticBezierTo(w * 0.5, h * 0.73, w * 0.38, h * 0.70),
          Paint()..color = hair.withValues(alpha: 0.85),
        );
      default: // 0: なし
        break;
    }
  }

  @override
  bool shouldRepaint(covariant FacePainter oldDelegate) =>
      oldDelegate.seed != seed;
}
