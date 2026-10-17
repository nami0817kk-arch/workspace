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
          painter: FacePainter(seed: playerId.hashCode, shirt: ringColor),
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

  /// 肩に着せるユニフォームの色。ポジション別カラーを渡している。
  final Color shirt;

  const FacePainter({required this.seed, this.shirt = const Color(0xFF4A5568)});

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

  /// 顔の中心。首と肩を入れるぶん、円の中心より上に置く。
  static const _faceCenterY = 0.44;

  /// [FaceFeatures] の寸法に掛ける率。1.0 だと顔が円を埋めてしまい、
  /// 首も肩も入らない。入れないと「首から上だけが浮いている」絵になる。
  static const _faceScale = 0.80;

  @override
  void paint(Canvas canvas, Size size) {
    final f = FaceFeatures.fromSeed(seed);
    final w = size.width;
    final h = size.height;

    final skin = skinTones[f.skinIndex];
    final hair = hairColors[f.hairIndex];

    _paintBackground(canvas, size, f);

    final faceRect = Rect.fromCenter(
      center: Offset(w * 0.5, h * _faceCenterY),
      width: w * f.faceWidth * _faceScale,
      // 縦に 0.94 掛けているのは、顔を円より小さくしたときに
      // faceHeight の上限が面長を通り越して見えたため。
      height: h * f.faceHeight * _faceScale * 0.94,
    );

    _paintShoulders(canvas, size);
    _paintNeck(canvas, size, skin, faceRect);
    _paintEars(canvas, skin, faceRect);

    // 輪郭。肌より暗い線を回すと、背景や髪と肌の明度が近いときでも
    // 顔の形が消えない(赤毛に明るい肌の組み合わせで実際に溶けていた)。
    canvas.drawOval(faceRect, Paint()..color = skin);
    canvas.drawOval(
      faceRect,
      Paint()
        ..color = _shade(skin, 0.80)
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.0, h * 0.012),
    );
    _paintFaceShading(canvas, skin, faceRect);

    _paintHair(canvas, size, f, hair, faceRect);
    _paintBrows(canvas, size, f, hair, faceRect);
    _paintEyes(canvas, size, f, faceRect);
    _paintNose(canvas, skin, faceRect);
    _paintMouth(canvas, f, skin, faceRect);
    _paintFacialHair(canvas, f, hair, faceRect);
  }

  /// 明度を [factor] 倍する(1未満で暗く、1超で明るく)。
  static Color _shade(Color c, double factor) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness * factor).clamp(0.0, 1.0)).toColor();
  }

  void _paintBackground(Canvas canvas, Size size, FaceFeatures f) {
    // 平らな一色だと、顔の輪郭が背景に貼り付いて見える。上を明るく、
    // 下を濃くすると、人物が前に出る。
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            HSLColor.fromAHSL(1, f.backgroundHue, 0.34, 0.91).toColor(),
            HSLColor.fromAHSL(1, f.backgroundHue, 0.40, 0.76).toColor(),
          ],
        ).createShader(rect),
    );
  }

  void _paintShoulders(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // 肩は円に切り抜かれるので、左右は枠の外まで伸ばしてよい。
    final top = h * 0.84;
    canvas.drawPath(
      Path()
        ..moveTo(-w * 0.1, h * 1.05)
        ..quadraticBezierTo(w * 0.10, top, w * 0.5, top)
        ..quadraticBezierTo(w * 0.90, top, w * 1.1, h * 1.05)
        ..close(),
      Paint()..color = shirt,
    );
    // 襟。シャツを少し暗くした V を入れると、ユニフォームらしくなる。
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.36, top + h * 0.004)
        ..lineTo(w * 0.5, h * 0.95)
        ..lineTo(w * 0.64, top + h * 0.004)
        ..close(),
      Paint()..color = _shade(shirt, 0.74),
    );
  }

  void _paintNeck(Canvas canvas, Size size, Color skin, Rect face) {
    final w = size.width;
    final h = size.height;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(w * 0.5 - w * 0.13, face.bottom - h * 0.06,
            w * 0.5 + w * 0.13, h * 0.92),
        Radius.circular(w * 0.05),
      ),
      Paint()..color = _shade(skin, 0.88),
    );
  }

  void _paintEars(Canvas canvas, Color skin, Rect face) {
    final paint = Paint()..color = _shade(skin, 0.94);
    final y = face.center.dy + face.height * 0.04;
    for (final x in [
      face.left + face.width * 0.01,
      face.right - face.width * 0.01,
    ]) {
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(x, y),
            width: face.width * 0.14,
            height: face.height * 0.17),
        paint,
      );
    }
  }

  void _paintFaceShading(Canvas canvas, Color skin, Rect face) {
    canvas.save();
    canvas.clipPath(Path()..addOval(face));
    // 右下から回り込む影。光源は左上に決めて、全員で揃える。
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(face.center.dx + face.width * 0.30,
            face.center.dy + face.height * 0.16),
        width: face.width * 1.30,
        height: face.height * 1.30,
      ),
      Paint()..color = _shade(skin, 0.86).withValues(alpha: 0.42),
    );
    // 顎の下の影。首とのつながりを作る。
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(face.center.dx, face.bottom),
        width: face.width * 0.52,
        height: face.height * 0.16,
      ),
      Paint()..color = _shade(skin, 0.78).withValues(alpha: 0.35),
    );
    canvas.restore();
  }

  void _paintHair(
      Canvas canvas, Size size, FaceFeatures f, Color hair, Rect face) {
    final h = size.height;
    final skin = skinTones[f.skinIndex];
    final paint = Paint()..color = hair;
    // 髪は顔の外周より少しだけ大きく回す。
    final cap = Rect.fromCenter(
      center: Offset(face.center.dx, face.center.dy - face.height * 0.04),
      width: face.width * 1.06,
      height: face.height * 1.02,
    );

    void capArc(Rect r, Paint p) => canvas.drawArc(r, pi, pi, true, p);

    // 生え際。髪のお椀から肌色の楕円を抜いて作る。位置と大きさで額の
    // 広さが決まる。
    //
    // **顔で切る。** 切らずに描くと、抜きの楕円が顔より広いときに顔の外へ
    // 肌色がはみ出し、髪が斜めに切れて帽子がずれたように見えた。
    void hairline(double cxOffset, double cyFactor, double wFactor,
        double hFactor) {
      canvas.save();
      canvas.clipPath(Path()..addOval(face));
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(
              face.center.dx + cxOffset, cap.top + cap.height * cyFactor),
          width: cap.width * wFactor,
          height: cap.height * hFactor,
        ),
        Paint()..color = skin,
      );
      canvas.restore();
    }

    switch (f.hairStyle) {
      case 0: // 短髪
        capArc(cap, paint);
        hairline(0, 0.46, 0.94, 0.46);
        _hairGloss(canvas, cap, hair);
      case 1: // サイド分け
        capArc(cap, paint);
        hairline(face.width * 0.10, 0.48, 0.88, 0.44);
        _hairGloss(canvas, cap, hair);
      case 2: // くせ毛
        for (var t = 0.0; t <= 1.001; t += 0.1) {
          final angle = pi + t * pi;
          canvas.drawCircle(
            Offset(cap.center.dx + cos(angle) * cap.width * 0.46,
                cap.center.dy + sin(angle) * cap.height * 0.42),
            face.width * 0.15,
            paint,
          );
        }
        hairline(0, 0.46, 0.92, 0.46);
      case 3: // 生え際が後退している
        capArc(
          Rect.fromCenter(
            center: Offset(cap.center.dx, cap.center.dy + cap.height * 0.06),
            width: cap.width,
            height: cap.height * 0.86,
          ),
          Paint()..color = hair.withValues(alpha: 0.72),
        );
        hairline(0, 0.52, 1.02, 0.52);
      case 4: // 長髪(耳を覆う)
        for (final side in const [-1.0, 1.0]) {
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(face.center.dx + side * face.width * 0.50,
                  face.center.dy + face.height * 0.16),
              width: face.width * 0.22,
              height: face.height * 0.70,
            ),
            paint,
          );
        }
        capArc(cap, paint);
        hairline(0, 0.44, 1.00, 0.46);
        _hairGloss(canvas, cap, hair);
      default: // 5: 刈り上げ(トップだけ残す)
        capArc(
          Rect.fromCenter(
            center: Offset(cap.center.dx, cap.center.dy + cap.height * 0.10),
            width: cap.width,
            height: cap.height * 0.94,
          ),
          Paint()..color = hair.withValues(alpha: 0.38),
        );
        capArc(
          Rect.fromCenter(
            center: Offset(cap.center.dx, cap.center.dy - cap.height * 0.02),
            width: cap.width * 0.88,
            height: cap.height * 0.78,
          ),
          paint,
        );
        hairline(0, 0.42, 0.88, 0.38);
        _hairGloss(canvas, cap, hair);
    }

    // **明るい髪は肌と同化する。** 金髪・白髪は輪郭が消えて、頭の形が
    // 分からなくなっていた。外周に線を回して形を残す(薄毛はお椀の形と
    // 実際の形が違うので対象外)。
    if (HSLColor.fromColor(hair).lightness > 0.55 && f.hairStyle != 3) {
      canvas.drawArc(
        cap,
        pi,
        pi,
        false,
        Paint()
          ..color = _shade(hair, 0.70)
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1.0, h * 0.013),
      );
    }

    // 髪が顔へ落とす影。
    //
    // **これが無いと生え際が消える。** 赤毛に中間の肌色のように髪と肌の
    // 明度が近いと、額を出していても「髪が顔の半分を覆っている」ように
    // 見えた。境目に影を置くと、色が近くても頭と顔が分かれて見える。
    canvas.save();
    canvas.clipPath(Path()..addOval(face));
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(face.center.dx, cap.top + cap.height * 0.48),
        width: cap.width * 0.92,
        height: cap.height * 0.36,
      ),
      pi,
      pi,
      false,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = h * 0.035,
    );
    canvas.restore();
  }

  /// 髪の艶。光源は顔の陰影と同じく左上。
  ///
  /// **明るい髪には乗せない。** 金髪や白髪に白い弧を重ねると、頭が
  /// ガラスのドームに見える(実際にそうなった)。
  void _hairGloss(Canvas canvas, Rect cap, Color hair) {
    if (HSLColor.fromColor(hair).lightness > 0.55) return;
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(cap.center.dx - cap.width * 0.12,
            cap.center.dy - cap.height * 0.06),
        width: cap.width * 0.56,
        height: cap.height * 0.62,
      ),
      pi * 1.12,
      pi * 0.46,
      false,
      Paint()
        ..color = _shade(hair, 1.45).withValues(alpha: 0.13)
        ..style = PaintingStyle.stroke
        ..strokeWidth = cap.height * 0.05
        ..strokeCap = StrokeCap.round,
    );
  }

  void _paintBrows(
      Canvas canvas, Size size, FaceFeatures f, Color hair, Rect face) {
    final w = size.width;
    final paint = Paint()
      ..color = _shade(hair, 0.85)
      ..strokeWidth = face.height * 0.045
      ..strokeCap = StrokeCap.round;
    final y = face.center.dy - face.height * 0.13;
    final inner = 0.5 - f.eyeSpread + 0.02;
    final outer = 0.5 - f.eyeSpread - 0.07;
    final tilt = face.height * f.browTilt;
    canvas.drawLine(
        Offset(w * outer, y - tilt), Offset(w * inner, y + tilt), paint);
    canvas.drawLine(Offset(w * (1 - inner), y + tilt),
        Offset(w * (1 - outer), y - tilt), paint);
  }

  void _paintEyes(Canvas canvas, Size size, FaceFeatures f, Rect face) {
    final w = size.width;
    final y = face.center.dy + face.height * 0.01;
    final left = Offset(w * (0.5 - f.eyeSpread), y);
    final right = Offset(w * (0.5 + f.eyeSpread), y);
    final white = Paint()..color = const Color(0xFFF7F4F0);
    final iris = Paint()..color = const Color(0xFF2E2A26);
    final spark = Paint()..color = Colors.white.withValues(alpha: 0.9);
    final r = face.width * 0.075;

    switch (f.eyeStyle) {
      case 1: // 細い目。白目を描くとつぶれるので線のまま。
        for (final c in [left, right]) {
          canvas.drawOval(
            Rect.fromCenter(
                center: c, width: r * 1.9, height: face.height * 0.045),
            iris,
          );
        }
      default: // 0: 丸い目 / 2: 小さめの目
        final scale = f.eyeStyle == 0 ? 1.0 : 0.78;
        for (final c in [left, right]) {
          canvas.drawOval(
            Rect.fromCenter(
                center: c, width: r * 2.1 * scale, height: r * 1.7 * scale),
            white,
          );
          canvas.drawCircle(c, r * 0.72 * scale, iris);
          canvas.drawCircle(
            Offset(c.dx - r * 0.26 * scale, c.dy - r * 0.26 * scale),
            r * 0.24 * scale,
            spark,
          );
        }
    }
  }

  void _paintNose(Canvas canvas, Color skin, Rect face) {
    // 縦線1本だと傷のように見えていた。小さな影の塊にする。
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(face.center.dx + face.width * 0.01,
            face.center.dy + face.height * 0.16),
        width: face.width * 0.17,
        height: face.height * 0.10,
      ),
      Paint()..color = _shade(skin, 0.84).withValues(alpha: 0.55),
    );
  }

  void _paintMouth(Canvas canvas, FaceFeatures f, Color skin, Rect face) {
    final paint = Paint()
      // 固定の赤茶にしていたら、暗い肌の上で紫に浮いた。肌から作る。
      ..color = _shade(skin, 0.58)
      ..style = PaintingStyle.stroke
      ..strokeWidth = face.height * 0.050
      ..strokeCap = StrokeCap.round;
    final y = face.center.dy + face.height * 0.29;
    final x0 = face.center.dx - face.width * 0.17;
    final x1 = face.center.dx + face.width * 0.17;
    final path = Path()..moveTo(x0, y);
    switch (f.mouthStyle) {
      case 0: // 口角が上がっている
        path.quadraticBezierTo(face.center.dx, y + face.height * 0.055, x1, y);
      case 1: // 真一文字
        path.lineTo(x1, y);
      default: // 2: 口角がわずかに下がっている
        // ここを深く曲げると、名簿がしかめ面ばかりになる。差が分かる
        // 範囲でいちばん浅くしてある。
        path.quadraticBezierTo(face.center.dx, y - face.height * 0.018, x1,
            y + face.height * 0.012);
    }
    canvas.drawPath(path, paint);
  }

  void _paintFacialHair(
      Canvas canvas, FaceFeatures f, Color hair, Rect face) {
    final cx = face.center.dx;
    final cy = face.center.dy;
    final fw = face.width;
    final fh = face.height;

    /// 顎ひげは輪郭からはみ出すと「浮いたあごひげ」になる。顔で切る。
    void clipped(void Function() draw) {
      canvas.save();
      canvas.clipPath(Path()..addOval(face));
      draw();
      canvas.restore();
    }

    switch (f.facialHair) {
      case 1: // 無精ひげ(顎まわりを薄く)
        clipped(() => canvas.drawPath(
              Path()
                ..moveTo(cx - fw * 0.34, cy + fh * 0.12)
                ..quadraticBezierTo(
                    cx, cy + fh * 0.62, cx + fw * 0.34, cy + fh * 0.12)
                ..quadraticBezierTo(
                    cx, cy + fh * 0.34, cx - fw * 0.34, cy + fh * 0.12),
              Paint()..color = hair.withValues(alpha: 0.32),
            ));
      case 2: // 顎ひげ
        clipped(() => canvas.drawPath(
              Path()
                ..moveTo(cx - fw * 0.30, cy + fh * 0.14)
                ..quadraticBezierTo(
                    cx, cy + fh * 0.60, cx + fw * 0.30, cy + fh * 0.14)
                ..quadraticBezierTo(
                    cx, cy + fh * 0.32, cx - fw * 0.30, cy + fh * 0.14),
              Paint()..color = hair.withValues(alpha: 0.9),
            ));
      case 3: // 口ひげ
        canvas.drawPath(
          Path()
            ..moveTo(cx - fw * 0.17, cy + fh * 0.215)
            ..quadraticBezierTo(
                cx, cy + fh * 0.150, cx + fw * 0.17, cy + fh * 0.215)
            ..quadraticBezierTo(
                cx, cy + fh * 0.265, cx - fw * 0.17, cy + fh * 0.215),
          Paint()..color = hair.withValues(alpha: 0.9),
        );
      default: // 0: なし
        break;
    }
  }

  @override
  bool shouldRepaint(covariant FacePainter oldDelegate) =>
      oldDelegate.seed != seed || oldDelegate.shirt != shirt;
}
