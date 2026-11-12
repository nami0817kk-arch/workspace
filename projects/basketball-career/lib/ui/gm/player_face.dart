import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../gm/player.dart';
import 'common.dart' show colorOf;

/// 顔の決まり(肌・髪型・髪の色・眉・ひげ・顔の幅)。選手の id から決まり、年を取ると白髪とひげが増える。
/// 本人の写真ではなく、部品の組み合わせ(実在の選手に似せない)。
class FaceSpec {
  const FaceSpec({
    required this.skin,
    required this.hairStyle,
    required this.hair,
    required this.brow,
    required this.beard,
    required this.width,
    required this.eyeSpread,
  });

  final Color skin;

  /// 0: 短髪、1: 坊主、2: アフロ、3: スキンヘッド、4: 長髪、5: 上だけ巻き毛。
  final int hairStyle;
  final Color hair;

  /// 眉の太さ(0 細い・1 ふつう・2 太い)。
  final int brow;

  /// 0: なし、1: 無精ひげ、2: あごひげ、3: ヤギひげ。
  final int beard;

  /// 顔の幅(0.88〜1.04)。
  final double width;

  /// 目の間の広さ(0.9〜1.1)。
  final double eyeSpread;
}

const faceSkins = [Color(0xFFF1C9A5), Color(0xFFE0AC69), Color(0xFFC68642), Color(0xFF8D5524), Color(0xFF6B4423), Color(0xFF4A2F1B)];
const faceHairs = [Color(0xFF1B1B1B), Color(0xFF2B1A10), Color(0xFF4A2B17), Color(0xFF6B4226), Color(0xFF9A6B2F), Color(0xFFC9A24B)];

int _h(Player p, int salt) {
  final x = (p.id * 2654435761 + salt * 40503 + 977) & 0x7fffffff;
  return (x ^ (x >> 13)) & 0x7fffffff;
}

FaceSpec faceOf(Player p) {
  final skin = faceSkins[_h(p, 1) % faceSkins.length];
  final style = _h(p, 2) % 6;
  // 髪の色は黒・濃い茶が多い。年(33歳から)で白髪が混じる
  final base = faceHairs[[0, 0, 0, 1, 1, 2, 3, 4, 5][_h(p, 3) % 9]];
  final gray = ((p.age - 32) / 10).clamp(0.0, 0.85);
  final hair = Color.lerp(base, const Color(0xFFBDBDBD), gray)!;
  // ひげ: 22歳未満はなし。年とともに増える
  var beard = 0;
  if (p.age >= 22) {
    final r = _h(p, 4) % 100;
    final chance = 18 + (p.age - 22) * 3; // 22歳で18%、32歳で48%
    if (r < chance) beard = 1 + (_h(p, 5) % 3);
  }
  return FaceSpec(
    skin: skin,
    hairStyle: style,
    hair: hair,
    brow: _h(p, 6) % 3,
    beard: beard,
    width: 0.88 + (_h(p, 7) % 17) / 100,
    eyeSpread: 0.9 + (_h(p, 8) % 21) / 100,
  );
}

/// 選手の顔(丸い枠にチームの色のユニフォームの肩と顔)。
class PlayerFace extends StatelessWidget {
  const PlayerFace({super.key, required this.p, required this.team, this.size = 40});
  final Player p;
  final int team;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = colorOf(team);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.jersey.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: c.jersey.withValues(alpha: 0.8)),
      ),
      clipBehavior: Clip.antiAlias,
      child: CustomPaint(painter: FacePainter(faceOf(p), c.jersey)),
    );
  }
}

class FacePainter extends CustomPainter {
  FacePainter(this.f, this.jersey);
  final FaceSpec f;
  final Color jersey;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    Paint fill(Color c) => Paint()..color = c;
    final cx = s / 2;
    final faceW = s * 0.46 * f.width, faceH = s * 0.56;
    final faceTop = s * 0.22;
    final faceRect = Rect.fromCenter(center: Offset(cx, faceTop + faceH / 2), width: faceW, height: faceH);
    final dark = Color.lerp(f.skin, Colors.black, 0.18)!;

    // 髪(顔の後ろ): アフロ・長髪
    if (f.hairStyle == 2) {
      canvas.drawOval(Rect.fromCenter(center: Offset(cx, faceTop + faceH * 0.28), width: faceW * 1.55, height: faceH * 1.05), fill(f.hair));
    } else if (f.hairStyle == 4) {
      final back = Path()
        ..moveTo(cx - faceW * 0.62, faceTop + faceH * 0.25)
        ..quadraticBezierTo(cx - faceW * 0.8, faceTop + faceH * 1.1, cx - faceW * 0.45, faceTop + faceH * 1.2)
        ..lineTo(cx + faceW * 0.45, faceTop + faceH * 1.2)
        ..quadraticBezierTo(cx + faceW * 0.8, faceTop + faceH * 1.1, cx + faceW * 0.62, faceTop + faceH * 0.25)
        ..close();
      canvas.drawPath(back, fill(f.hair));
    }

    // 肩(ユニフォーム)と首
    final shoulders = Path()
      ..moveTo(s * 0.04, s)
      ..quadraticBezierTo(s * 0.06, s * 0.78, cx - s * 0.2, s * 0.76)
      ..lineTo(cx + s * 0.2, s * 0.76)
      ..quadraticBezierTo(s * 0.94, s * 0.78, s * 0.96, s)
      ..close();
    canvas.drawRect(Rect.fromCenter(center: Offset(cx, s * 0.76), width: faceW * 0.5, height: s * 0.2), fill(dark));
    canvas.drawPath(shoulders, fill(jersey));
    // えり
    canvas.drawArc(Rect.fromCenter(center: Offset(cx, s * 0.76), width: faceW * 0.62, height: s * 0.14), 0, math.pi, false, Paint()..color = Colors.white.withValues(alpha: 0.85)..style = PaintingStyle.stroke..strokeWidth = s * 0.03);

    // 耳と顔
    canvas.drawOval(Rect.fromCenter(center: Offset(cx - faceW * 0.5, faceTop + faceH * 0.55), width: s * 0.07, height: s * 0.12), fill(dark));
    canvas.drawOval(Rect.fromCenter(center: Offset(cx + faceW * 0.5, faceTop + faceH * 0.55), width: s * 0.07, height: s * 0.12), fill(dark));
    canvas.drawOval(faceRect, fill(f.skin));

    // 髪(顔の前)
    final hairPaint = fill(f.hair);
    switch (f.hairStyle) {
      case 0: // 短髪
        canvas.drawPath(_cap(cx, faceTop, faceW, faceH, 0.34), hairPaint);
      case 1: // 坊主
        canvas.drawPath(_cap(cx, faceTop, faceW, faceH, 0.2), Paint()..color = f.hair.withValues(alpha: 0.9));
      case 2: // アフロ(前の生え際だけ)
        canvas.drawPath(_cap(cx, faceTop, faceW, faceH, 0.24), hairPaint);
      case 4: // 長髪
        canvas.drawPath(_cap(cx, faceTop, faceW, faceH, 0.4), hairPaint);
      case 5: // 上だけ巻き毛
        canvas.drawPath(_cap(cx, faceTop, faceW, faceH, 0.28), hairPaint);
        for (var i = -2; i <= 2; i++) {
          canvas.drawCircle(Offset(cx + i * faceW * 0.2, faceTop - faceH * 0.02 + (i.abs() == 2 ? faceH * 0.08 : 0)), faceW * 0.14, hairPaint);
        }
      default: // スキンヘッド
        break;
    }

    // 目・眉・鼻・口
    final eyeY = faceTop + faceH * 0.5;
    final dx = faceW * 0.24 * f.eyeSpread;
    for (final sign in [-1.0, 1.0]) {
      final ex = cx + sign * dx;
      canvas.drawOval(Rect.fromCenter(center: Offset(ex, eyeY), width: s * 0.1, height: s * 0.065), fill(Colors.white));
      canvas.drawCircle(Offset(ex, eyeY), s * 0.027, fill(const Color(0xFF1B1B1B)));
      final bw = s * (0.016 + f.brow * 0.012);
      canvas.drawLine(Offset(ex - s * 0.05, eyeY - s * 0.075), Offset(ex + s * 0.05, eyeY - s * 0.085), Paint()
        ..color = f.hair.withValues(alpha: 0.95)
        ..strokeWidth = bw
        ..strokeCap = StrokeCap.round);
    }
    canvas.drawLine(Offset(cx, eyeY + s * 0.04), Offset(cx - s * 0.012, eyeY + s * 0.13), Paint()..color = dark..strokeWidth = s * 0.018..strokeCap = StrokeCap.round);
    final mouthY = faceTop + faceH * 0.83;
    canvas.drawArc(Rect.fromCenter(center: Offset(cx, mouthY), width: faceW * 0.34, height: s * 0.06), 0.1, math.pi - 0.2, false,
        Paint()..color = Color.lerp(f.skin, const Color(0xFF7A2A2A), 0.6)!..style = PaintingStyle.stroke..strokeWidth = s * 0.02..strokeCap = StrokeCap.round);

    // ひげ
    final beardColor = Color.lerp(f.hair, Colors.black, 0.1)!;
    switch (f.beard) {
      case 1: // 無精ひげ
        canvas.drawPath(_jaw(cx, faceTop, faceW, faceH, 0.62), Paint()..color = beardColor.withValues(alpha: 0.28));
      case 2: // あごひげ
        canvas.drawPath(_jaw(cx, faceTop, faceW, faceH, 0.6), Paint()..color = beardColor.withValues(alpha: 0.92));
        canvas.drawArc(Rect.fromCenter(center: Offset(cx, mouthY), width: faceW * 0.34, height: s * 0.06), 0.1, math.pi - 0.2, false,
            Paint()..color = Color.lerp(f.skin, const Color(0xFF7A2A2A), 0.6)!..style = PaintingStyle.stroke..strokeWidth = s * 0.02..strokeCap = StrokeCap.round);
      case 3: // ヤギひげ
        canvas.drawOval(Rect.fromCenter(center: Offset(cx, faceTop + faceH * 0.96), width: faceW * 0.26, height: faceH * 0.16), fill(beardColor));
        canvas.drawRect(Rect.fromCenter(center: Offset(cx, mouthY - s * 0.04), width: faceW * 0.3, height: s * 0.018), fill(beardColor));
      default:
        break;
    }
  }

  /// 髪の「ぼうし」の形(生え際の高さ [lowest] は顔の高さの割合)。
  Path _cap(double cx, double top, double w, double h, double lowest) {
    final path = Path()
      ..moveTo(cx - w * 0.54, top + h * 0.5)
      ..quadraticBezierTo(cx - w * 0.62, top - h * 0.12, cx, top - h * 0.1)
      ..quadraticBezierTo(cx + w * 0.62, top - h * 0.12, cx + w * 0.54, top + h * 0.5)
      ..quadraticBezierTo(cx + w * 0.46, top + h * (lowest * 0.55), cx + w * 0.3, top + h * lowest)
      ..quadraticBezierTo(cx, top + h * (lowest * 0.55), cx - w * 0.3, top + h * lowest)
      ..quadraticBezierTo(cx - w * 0.46, top + h * (lowest * 0.55), cx - w * 0.54, top + h * 0.5)
      ..close();
    return path;
  }

  /// あごまわりのひげの形。
  Path _jaw(double cx, double top, double w, double h, double from) {
    return Path()
      ..moveTo(cx - w * 0.5, top + h * from)
      ..quadraticBezierTo(cx - w * 0.5, top + h * 1.0, cx, top + h * 1.02)
      ..quadraticBezierTo(cx + w * 0.5, top + h * 1.0, cx + w * 0.5, top + h * from)
      ..quadraticBezierTo(cx + w * 0.3, top + h * (from + 0.16), cx, top + h * (from + 0.1))
      ..quadraticBezierTo(cx - w * 0.3, top + h * (from + 0.16), cx - w * 0.5, top + h * from)
      ..close();
  }

  @override
  bool shouldRepaint(FacePainter old) => old.f != f || old.jersey != jersey;
}
