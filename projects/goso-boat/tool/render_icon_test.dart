// アプリアイコンを、ゲームの中と同じ絵（警官と囚人と舟）から書き出す。
//
//   flutter test tool/render_icon_test.dart
//   python tool/finish_icon.py      … 透過を消して iOS の AppIcon と Web の favicon に置く
//
// tool/ に置いているので CI のテスト（test/）には入らない。絵を変えたときだけ手で回す。
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goso_boat/engine/rules.dart';
import 'package:goso_boat/ui/figures.dart';
import 'package:goso_boat/ui/palette.dart';

class _Backdrop extends CustomPainter {
  const _Backdrop();

  @override
  void paint(Canvas c, Size s) {
    final r = Offset.zero & s;
    c.drawRect(r, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Palette.skyTop, Palette.sky]).createShader(r));
    // 川（下 58%）
    final river = Rect.fromLTWH(0, s.height * 0.42, s.width, s.height * 0.58);
    c.drawRect(river, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Palette.river, Palette.riverDeep]).createShader(river));
    // 向こう岸の草
    c.drawRect(Rect.fromLTWH(0, s.height * 0.36, s.width, s.height * 0.07), Paint()..color = Palette.grass);
    c.drawRect(Rect.fromLTWH(0, s.height * 0.42, s.width, s.height * 0.012), Paint()..color = Palette.grassDark);
    // 波
    final wave = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..strokeWidth = s.width * 0.018
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final (x, y, w) in [(0.12, 0.84, 0.16), (0.72, 0.9, 0.18), (0.62, 0.52, 0.12), (0.08, 0.56, 0.1)]) {
      final p = Path()..moveTo(s.width * x, s.height * y);
      p.quadraticBezierTo(s.width * (x + w / 2), s.height * (y - 0.02), s.width * (x + w), s.height * y);
      c.drawPath(p, wave);
    }
    // 「!」の吹き出し（逃げそうな囚人の上）
    final o = Offset(s.width * 0.7, s.height * 0.2);
    c.drawCircle(o, s.width * 0.085, Paint()..color = Palette.bad);
    c.drawCircle(o, s.width * 0.085, Paint()
      ..color = Palette.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = s.width * 0.014);
    final bar = RRect.fromRectAndRadius(Rect.fromCenter(center: o - Offset(0, s.width * 0.018), width: s.width * 0.03, height: s.width * 0.08), Radius.circular(s.width * 0.015));
    c.drawRRect(bar, Paint()..color = Colors.white);
    c.drawCircle(o + Offset(0, s.width * 0.045), s.width * 0.017, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_Backdrop oldDelegate) => false;
}

void main() {
  testWidgets('アイコンを書き出す', (tester) async {
    // テストの既定の字（四角になる）ではなく、同梱の字で囚人の番号を描く
    await tester.runAsync(() async {
      final loader = FontLoader('Goso')..addFont(Future.value(ByteData.sublistView(File('assets/fonts/GosoRounded-ExtraBold.ttf').readAsBytesSync())));
      await loader.load();
    });
    const side = 256.0;
    final key = GlobalKey();
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
      child: RepaintBoundary(
        key: key,
        child: SizedBox(
          width: side,
          height: side,
          child: Stack(children: [
            const Positioned.fill(child: CustomPaint(painter: _Backdrop())),
            const Positioned(left: 22, right: 22, top: 168, height: 56, child: CustomPaint(painter: BoatPainter())),
            Positioned(
              left: 34,
              top: 58,
              width: 96,
              height: 120,
              child: Transform.rotate(angle: -0.04, child: const Figure(role: Role.police)),
            ),
            Positioned(
              left: 122,
              top: 60,
              width: 96,
              height: 120,
              child: Transform.rotate(angle: math.pi * 0.02, child: const Figure(role: Role.prisoner)),
            ),
          ]),
        ),
      ),
    )));
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1024 / side);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('build/icon-1024.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });
}
