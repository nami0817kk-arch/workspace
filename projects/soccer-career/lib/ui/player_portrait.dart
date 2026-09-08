import 'dart:math';

import 'package:flutter/material.dart';

import '../models/club.dart';
import '../models/look.dart';
import 'club_identity.dart';

/// 選手の似顔。
///
/// 画像は持たず、その場で描く。素材を持つと権利と容量の話になるし、
/// クラブの色と背番号がそのまま乗るので、移籍すると見た目も変わる。
///
/// **実在の人物を思わせる要素は入れない。** 顔は目鼻を描かず、
/// 髪型と肌の色と、着ているものだけで「自分の選手」にする。
class PlayerPortrait extends StatelessWidget {
  const PlayerPortrait({
    super.key,
    required this.look,
    this.club,
    this.squadNumber = 0,
    this.size = 72,
  });

  final PlayerLook look;

  /// 着ているクラブ。無ければ落ち着いた色で描く。
  final Club? club;

  /// 背中と胸に入る番号。0 なら入れない。
  final int squadNumber;

  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final identity = club == null ? null : ClubIdentity.of(club!);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _PortraitPainter(
          look: look,
          kit: identity?.primary ?? theme.colorScheme.primary,
          trim: identity?.secondary ?? theme.colorScheme.onPrimary,
          striped: identity?.striped ?? false,
          squadNumber: squadNumber,
          backdrop: theme.colorScheme.surfaceContainerHighest,
        ),
      ),
    );
  }
}

class _PortraitPainter extends CustomPainter {
  _PortraitPainter({
    required this.look,
    required this.kit,
    required this.trim,
    required this.striped,
    required this.squadNumber,
    required this.backdrop,
  });

  final PlayerLook look;
  final Color kit;
  final Color trim;
  final bool striped;
  final int squadNumber;
  final Color backdrop;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final skin = Color(PlayerLook.skinTones[look.skin]);
    final hair = Color(PlayerLook.hairColors[look.hairColor]);
    final shade = Color.lerp(skin, Colors.black, 0.18)!;

    final frame = Rect.fromLTWH(0, 0, s, s);
    final rounded = RRect.fromRectAndRadius(frame, Radius.circular(s * 0.22));
    canvas.save();
    canvas.clipRRect(rounded);

    // 背景。上を明るく、下を落として奥行きを出す。
    canvas.drawRect(
      frame,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(backdrop, Colors.white, 0.35)!,
            backdrop,
          ],
        ).createShader(frame),
    );

    // 首。肩より先に描いて、襟で隠す。
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s * 0.42, s * 0.50, s * 0.16, s * 0.22),
        Radius.circular(s * 0.05),
      ),
      Paint()..color = shade,
    );

    // 肩から胸。なで肩にすると人に見える。
    final torso = Path()
      ..moveTo(s * 0.10, s)
      ..lineTo(s * 0.12, s * 0.86)
      ..quadraticBezierTo(s * 0.16, s * 0.68, s * 0.36, s * 0.63)
      ..lineTo(s * 0.64, s * 0.63)
      ..quadraticBezierTo(s * 0.84, s * 0.68, s * 0.88, s * 0.86)
      ..lineTo(s * 0.90, s)
      ..close();
    canvas.drawPath(torso, Paint()..color = kit);

    if (striped) {
      canvas.save();
      canvas.clipPath(torso);
      final stripe = Paint()..color = trim.withValues(alpha: 0.55);
      for (var i = 0; i < 4; i++) {
        canvas.drawRect(
          Rect.fromLTWH(s * (0.14 + i * 0.20), s * 0.60, s * 0.075, s * 0.45),
          stripe,
        );
      }
      canvas.restore();
    }

    // 襟。
    final collar = Path()
      ..moveTo(s * 0.38, s * 0.635)
      ..lineTo(s * 0.50, s * 0.75)
      ..lineTo(s * 0.62, s * 0.635)
      ..close();
    canvas.drawPath(collar, Paint()..color = trim);

    // 頭。
    final head = Rect.fromCenter(
      center: Offset(s * 0.5, s * 0.42),
      width: s * 0.38,
      height: s * 0.44,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(head, Radius.circular(s * 0.17)),
      Paint()..color = skin,
    );
    // 耳。
    for (final dx in [-0.20, 0.20]) {
      canvas.drawCircle(
        Offset(s * (0.5 + dx), s * 0.44),
        s * 0.035,
        Paint()..color = shade,
      );
    }

    _paintHair(canvas, s, hair, head, skin);

    // 背番号。胸の右に小さく。
    if (squadNumber > 0) {
      final painter = TextPainter(
        text: TextSpan(
          text: '$squadNumber',
          style: TextStyle(
            color: trim,
            fontSize: s * 0.16,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        Offset(s * 0.70 - painter.width / 2, s * 0.80 - painter.height / 2),
      );
    }

    canvas.restore();
  }

  /// 髪。頭のかたちに沿わせて上から被せ、生え際を肌色で削り出す。
  ///
  /// 頭の輪郭と別の形で描くと、額に隙間が空いて鉢巻きに見える。
  void _paintHair(Canvas canvas, double s, Color hair, Rect head, Color skin) {
    final paint = Paint()..color = hair;
    final radius = Radius.circular(s * 0.17);

    /// 頭頂から [coverage] の割合まで髪で覆い、[hairline] の深さで額を出す。
    void cap(double coverage, {double hairline = 0.42, double bulge = 0.012}) {
      final rect = Rect.fromLTRB(
        head.left - s * bulge,
        head.top - s * bulge,
        head.right + s * bulge,
        head.top + head.height * coverage,
      );
      canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), paint);
      if (hairline <= 0) return;
      // 額。髪の下端を丸く削ると生え際になる。
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(head.center.dx, rect.bottom),
          width: head.width * 0.86,
          height: head.height * hairline,
        ),
        Paint()..color = skin,
      );
    }

    switch (look.hair) {
      case HairStyle.bald:
        // 剃り上げ。輪郭にうっすら残るだけ。
        canvas.save();
        canvas.clipRRect(
            RRect.fromRectAndRadius(head, radius));
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(head.left, head.top, head.right,
                head.top + head.height * 0.34),
            radius,
          ),
          Paint()..color = hair.withValues(alpha: 0.28),
        );
        canvas.restore();
      case HairStyle.crop:
        cap(0.40, hairline: 0.34);
      case HairStyle.short:
        cap(0.48, hairline: 0.40);
      case HairStyle.long:
        // 横に垂らす。先に長い面を描いてから、上を被せる。
        for (final dir in [-1.0, 1.0]) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(
                head.center.dx + dir * head.width * 0.5 - head.width * 0.14,
                head.top + head.height * 0.12,
                head.width * 0.20,
                head.height * 0.78,
              ),
              Radius.circular(s * 0.05),
            ),
            paint,
          );
        }
        cap(0.50, hairline: 0.38);
      case HairStyle.bun:
        // 束ねた髪。台の上に載せて、隙間を作らない。
        cap(0.44, hairline: 0.36);
        canvas.drawCircle(
          Offset(head.center.dx, head.top - s * 0.012),
          s * 0.055,
          paint,
        );
      case HairStyle.curly:
        // 丸を重ねて輪郭を崩す。土台を敷いてから外側に丸を置く。
        cap(0.44, hairline: 0.34);
        for (var i = 0; i < 9; i++) {
          final angle = pi * (1.04 - i / 8 * 1.08);
          canvas.drawCircle(
            Offset(
              head.center.dx + cos(angle) * head.width * 0.54,
              head.center.dy - head.height * 0.10 -
                  sin(angle) * head.height * 0.42,
            ),
            s * 0.052,
            paint,
          );
        }
    }
  }

  @override
  bool shouldRepaint(_PortraitPainter old) =>
      old.look.skin != look.skin ||
      old.look.hair != look.hair ||
      old.look.hairColor != look.hairColor ||
      old.kit != kit ||
      old.trim != trim ||
      old.striped != striped ||
      old.squadNumber != squadNumber ||
      old.backdrop != backdrop;
}
