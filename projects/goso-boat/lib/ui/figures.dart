import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../engine/rules.dart';
import 'palette.dart';

/// 役ごとの人物の絵。1人ぶんは 40×50 の座標で描き、手錠の2人は 80×50。
class Figure extends StatelessWidget {
  const Figure({super.key, required this.role, this.order = 0, this.mood = Mood.calm, this.bob = 0});

  final Role role;
  final int order;
  final Mood mood;

  /// 0〜1 の待機の揺れ（全員で1つの時計を共有して、番号でずらす）。
  final double bob;

  static double aspect(Role r) => r == Role.cuffed ? 80 / 50 : 40 / 50;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _FigurePainter(role, order, mood, bob),
        size: Size.infinite,
      );
}

enum Mood { calm, alert, happy }

class _FigurePainter extends CustomPainter {
  _FigurePainter(this.role, this.order, this.mood, this.bob);
  final Role role;
  final int order;
  final Mood mood;
  final double bob;

  static final _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5
    ..color = Palette.ink
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;

  Paint fill(Color c) => Paint()..color = c;

  @override
  void paint(Canvas canvas, Size size) {
    final w = role == Role.cuffed ? 80.0 : 40.0;
    final s = size.width / w;
    canvas.save();
    canvas.scale(s);
    // 影
    canvas.drawOval(Rect.fromCenter(center: Offset(w / 2, 49), width: w * 0.55, height: 3.5), fill(const Color(0x2E000000)));
    final lift = mood == Mood.happy ? -math.sin(bob * math.pi * 2).abs() * 6 : -math.sin((bob + order * 0.23) * math.pi * 2) * 0.8;
    final shake = mood == Mood.alert ? math.sin(bob * math.pi * 16) * 1.2 : 0.0;
    canvas.translate(shake, lift);
    switch (role) {
      case Role.police:
        _officer(canvas, chief: false);
      case Role.chief:
        _officer(canvas, chief: true);
      case Role.dog:
        _dog(canvas);
      case Role.prisoner:
        _convict(canvas, number: order + 1);
      case Role.boss:
        _convict(canvas, boss: true);
      case Role.cuffed:
        _convict(canvas, number: order * 2 + 11);
        canvas.save();
        canvas.translate(40, 0);
        _convict(canvas, number: order * 2 + 12);
        canvas.restore();
        _chain(canvas);
    }
    if (mood == Mood.alert && role.weight > 0) _alertMark(canvas, w);
    canvas.restore();
  }

  void _legs(Canvas c, Paint p) {
    for (final x in [13.0, 22.0]) {
      final r = RRect.fromRectAndRadius(Rect.fromLTWH(x, 41, 5, 8), const Radius.circular(2));
      c.drawRRect(r, p);
      c.drawRRect(r, _stroke);
    }
  }

  void _officer(Canvas c, {required bool chief}) {
    final uniform = chief ? const Color(0xFF1B2F63) : const Color(0xFF2B4FA8);
    _legs(c, fill(chief ? const Color(0xFF14244D) : const Color(0xFF223F86)));
    final body = RRect.fromRectAndRadius(const Rect.fromLTWH(11, 27, 18, 16), const Radius.circular(5));
    c.drawRRect(body, fill(uniform));
    c.drawRRect(body, _stroke);
    c.drawLine(const Offset(19.5, 29), const Offset(19.5, 37), Paint()..color = Palette.gold..strokeWidth = 1.5);
    if (chief) {
      // 肩章
      for (final x in [11.0, 25.0]) {
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, 27, 4, 3), const Radius.circular(1)), fill(Palette.gold));
      }
    } else {
      // 警棒
      c.save();
      c.translate(29, 37);
      c.rotate(-0.44);
      final baton = RRect.fromRectAndRadius(const Rect.fromLTWH(-1.5, -7, 3, 14), const Radius.circular(1.5));
      c.drawRRect(baton, fill(const Color(0xFF5A3A22)));
      c.drawRRect(baton, _stroke..strokeWidth = 1);
      _stroke.strokeWidth = 1.5;
      c.restore();
    }
    // 顔
    c.drawCircle(const Offset(20, 19), 9, fill(const Color(0xFFFFD9B8)));
    c.drawCircle(const Offset(20, 19), 9, _stroke);
    c.drawCircle(const Offset(16.8, 20), 1.3, fill(Palette.ink));
    c.drawCircle(const Offset(23.2, 20), 1.3, fill(Palette.ink));
    c.drawLine(const Offset(15, 17.3), const Offset(18, 18.1), _stroke..strokeWidth = 1.1);
    c.drawLine(const Offset(25, 17.3), const Offset(22, 18.1), _stroke);
    _stroke.strokeWidth = 1.5;
    if (chief) {
      // ひげ
      final m = Path()
        ..moveTo(15.5, 23.2)
        ..quadraticBezierTo(18, 21.8, 20, 23)
        ..quadraticBezierTo(22, 21.8, 24.5, 23.2)
        ..quadraticBezierTo(20, 25, 15.5, 23.2);
      c.drawPath(m, fill(const Color(0xFF3B2A1E)));
    } else {
      final mouth = Path()
        ..moveTo(17.5, 24)
        ..quadraticBezierTo(20, 25.2, 22.5, 24);
      c.drawPath(mouth, _stroke..strokeWidth = 1.2);
      _stroke.strokeWidth = 1.5;
    }
    // 帽子
    final cap = Path()
      ..moveTo(9, 14)
      ..quadraticBezierTo(20, 4, 31, 14)
      ..lineTo(31, 16)
      ..lineTo(9, 16)
      ..close();
    c.drawPath(cap, fill(chief ? Colors.white : const Color(0xFF1E3A86)));
    c.drawPath(cap, _stroke);
    final brim = RRect.fromRectAndRadius(const Rect.fromLTWH(8, 14.5, 24, 3), const Radius.circular(1.5));
    c.drawRRect(brim, fill(chief ? Palette.ink : const Color(0xFF15295E)));
    if (chief) {
      _star(c, const Offset(20, 10.5), 3.2);
    } else {
      c.drawCircle(const Offset(20, 10.5), 2.2, fill(Palette.gold));
      c.drawCircle(const Offset(20, 10.5), 2.2, _stroke..strokeWidth = 0.8);
      _stroke.strokeWidth = 1.5;
    }
  }

  void _star(Canvas c, Offset o, double r) {
    final p = Path();
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + i * math.pi / 5;
      final rr = i.isEven ? r : r * 0.45;
      final pt = o + Offset(math.cos(a) * rr, math.sin(a) * rr);
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    p.close();
    c.drawPath(p, fill(Palette.gold));
    c.drawPath(p, _stroke..strokeWidth = 0.8);
    _stroke.strokeWidth = 1.5;
  }

  void _dog(Canvas c) {
    const fur = Color(0xFFB9824A);
    const dark = Color(0xFF6E4524);
    // 脚
    for (final x in [9.0, 14.0, 25.0, 30.0]) {
      final r = RRect.fromRectAndRadius(Rect.fromLTWH(x, 38, 4, 11), const Radius.circular(2));
      c.drawRRect(r, fill(fur));
      c.drawRRect(r, _stroke);
    }
    // しっぽ
    final tail = Path()
      ..moveTo(33, 31)
      ..quadraticBezierTo(39, 26, 37, 20);
    c.drawPath(tail, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..color = fur);
    // 胴（青いベスト）
    final body = RRect.fromRectAndRadius(const Rect.fromLTWH(7, 27, 28, 14), const Radius.circular(7));
    c.drawRRect(body, fill(fur));
    final vest = RRect.fromRectAndRadius(const Rect.fromLTWH(14, 27, 14, 14), const Radius.circular(3));
    c.drawRRect(vest, fill(const Color(0xFF2B4FA8)));
    c.drawRRect(body, _stroke);
    final tp = TextPainter(
      text: const TextSpan(text: 'K9', style: TextStyle(fontSize: 5.5, fontWeight: FontWeight.w900, color: Colors.white)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset(21 - tp.width / 2, 31));
    // 頭
    c.drawCircle(const Offset(12, 22), 8, fill(fur));
    c.drawCircle(const Offset(12, 22), 8, _stroke);
    final snout = RRect.fromRectAndRadius(const Rect.fromLTWH(1, 22, 9, 6), const Radius.circular(3));
    c.drawRRect(snout, fill(const Color(0xFFE6C39A)));
    c.drawRRect(snout, _stroke);
    c.drawCircle(const Offset(2.5, 23.5), 1.6, fill(Palette.ink));
    c.drawCircle(const Offset(10, 20), 1.3, fill(Palette.ink));
    final ear = Path()
      ..moveTo(13, 15)
      ..quadraticBezierTo(19, 12, 18, 21)
      ..quadraticBezierTo(15, 19, 13, 15);
    c.drawPath(ear, fill(dark));
    c.drawPath(ear, _stroke);
  }

  void _convict(Canvas c, {int number = 1, bool boss = false}) {
    final stripe = boss ? const Color(0xFFE8792B) : const Color(0xFF2A2A2A);
    void striped(RRect r) {
      c.save();
      c.clipRRect(r);
      c.drawRect(r.outerRect, fill(Colors.white));
      for (var y = r.top; y < r.bottom; y += 6) {
        c.drawRect(Rect.fromLTWH(r.left, y + 3, r.width, 3), fill(stripe));
      }
      c.restore();
      c.drawRRect(r, _stroke);
    }

    for (final x in [13.0, 22.0]) {
      striped(RRect.fromRectAndRadius(Rect.fromLTWH(x, 41, 5, 8), const Radius.circular(2)));
    }
    final body = boss ? const Rect.fromLTWH(9, 26, 22, 17) : const Rect.fromLTWH(11, 27, 18, 16);
    striped(RRect.fromRectAndRadius(body, const Radius.circular(5)));
    if (boss) {
      // 金の鎖
      final chain = Path()
        ..moveTo(13, 27)
        ..quadraticBezierTo(20, 35, 27, 27);
      c.drawPath(chain, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Palette.gold);
    } else {
      final tp = TextPainter(
        text: TextSpan(text: '$number', style: const TextStyle(fontSize: 6, fontWeight: FontWeight.w900, color: Palette.bad)),
        textDirection: TextDirection.ltr,
      )..layout();
      final bg = Rect.fromCenter(center: const Offset(20, 35), width: tp.width + 3, height: 7);
      c.drawRect(bg, fill(Colors.white));
      tp.paint(c, Offset(20 - tp.width / 2, 35 - tp.height / 2));
    }
    // 頭
    final r = boss ? 11.0 : 10.0;
    c.drawCircle(Offset(20, boss ? 17 : 18), r, fill(const Color(0xFFF2C9A5)));
    c.drawCircle(Offset(20, boss ? 17 : 18), r, _stroke);
    if (boss) {
      // サングラスと傷
      final glasses = RRect.fromRectAndRadius(const Rect.fromLTWH(11, 14, 18, 5), const Radius.circular(2.5));
      c.drawRRect(glasses, fill(Palette.ink));
      c.drawLine(const Offset(26, 7), const Offset(29, 12), _stroke..color = const Color(0xFFB0574A));
      _stroke.color = Palette.ink;
      final mouth = Path()
        ..moveTo(16, 23.5)
        ..lineTo(24, 22.5);
      c.drawPath(mouth, _stroke);
    } else {
      final mask = RRect.fromRectAndRadius(const Rect.fromLTWH(10.5, 15, 19, 5), const Radius.circular(2.5));
      c.drawRRect(mask, fill(const Color(0xFF1F1F1F)));
      c.drawCircle(const Offset(16.5, 17.5), 1.1, fill(Colors.white));
      c.drawCircle(const Offset(23.5, 17.5), 1.1, fill(Colors.white));
      final grin = mood == Mood.alert;
      final mouth = Path()
        ..moveTo(16.5, 24.5)
        ..quadraticBezierTo(20, grin ? 27 : 22.5, 23.5, 24.5);
      c.drawPath(mouth, _stroke..strokeWidth = 1.3);
      _stroke.strokeWidth = 1.5;
    }
  }

  void _chain(Canvas c) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = const Color(0xFF8A8F99);
    for (var i = 0; i < 4; i++) {
      c.drawOval(Rect.fromLTWH(29 + i * 5.5, 33 + (i.isEven ? 0 : 1), 6, 4), p);
    }
    for (final x in [27.0, 51.0]) {
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, 32, 4, 6), const Radius.circular(1.5)), fill(const Color(0xFF8A8F99)));
    }
  }

  void _alertMark(Canvas c, double w) {
    final o = Offset(w / 2, 1);
    c.drawCircle(o, 6, fill(Palette.bad));
    c.drawCircle(o, 6, _stroke);
    final tp = TextPainter(
      text: const TextSpan(text: '!', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, o - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_FigurePainter old) =>
      old.role != role || old.mood != mood || old.bob != bob || old.order != order;
}

/// 舟。席の数で横幅が変わる。
class BoatPainter extends CustomPainter {
  const BoatPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final hull = Path()
      ..moveTo(0, h * 0.25)
      ..lineTo(w, h * 0.25)
      ..lineTo(w - w * 0.08, h * 0.85)
      ..quadraticBezierTo(w - w * 0.1, h, w - w * 0.16, h)
      ..lineTo(w * 0.16, h)
      ..quadraticBezierTo(w * 0.1, h, w * 0.08, h * 0.85)
      ..close();
    canvas.drawPath(hull, Paint()..color = const Color(0xFFFBFBFB));
    canvas.drawLine(Offset(w * 0.04, h * 0.5), Offset(w * 0.96, h * 0.5), Paint()
      ..color = Palette.riverDeep
      ..strokeWidth = 3);
    canvas.drawLine(Offset(w * 0.12, h * 0.75), Offset(w * 0.88, h * 0.75), Paint()
      ..color = Palette.bad
      ..strokeWidth = 2);
    canvas.drawPath(hull, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = Palette.ink
      ..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(BoatPainter oldDelegate) => false;
}
