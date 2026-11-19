import 'dart:math';

import 'package:flutter/material.dart';

/// はじめの画面の絵。GMの部屋の窓から、夜のアリーナを見下ろす後ろ姿(2026-11-20 に Cloudflare の FLUX で作り直した絵、`assets/art/title.jpg`)。
/// 読み込めなければ、コードで描いた夕焼けの絵(ゴールに向かうボールと街のシルエット)に戻る。
class TitleArt extends StatelessWidget {
  const TitleArt({super.key, this.height = 190});
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Image.asset(
            'assets/art/title.jpg',
            fit: BoxFit.cover,
            alignment: Alignment.center,
            // 読み込み中も、読み込めなかったときも、コードで描いた絵を出す(空白にしない)。
            frameBuilder: (context, child, frame, sync) =>
                (frame == null && !sync)
                    ? CustomPaint(painter: _TitlePainter())
                    : child,
            errorBuilder: (_, __, ___) =>
                CustomPaint(painter: _TitlePainter()),
          ),
        ),
      );
}

/// 画面の上に置く横長の絵(Gemini で生成した `assets/art/*.jpg`)。
/// 読み込み中・読み込めなかったときは、オレンジのグラデーションを出す(空白や例外にしない)。
class ArtBanner extends StatelessWidget {
  const ArtBanner(this.asset, {super.key, this.height = 150});
  final String asset;
  final double height;

  @override
  Widget build(BuildContext context) {
    const placeholder = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFB74D), Color(0xFFBF360C)],
        ),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Image.asset(
          asset,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          frameBuilder: (context, child, frame, sync) =>
              (frame == null && !sync) ? placeholder : child,
          errorBuilder: (_, __, ___) => placeholder,
        ),
      ),
    );
  }
}

class _TitlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    // 夕焼けの空。
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF5C6BC0), Color(0xFFFF8A65), Color(0xFFFFCC80)],
          stops: [0.0, 0.65, 1.0],
        ).createShader(Offset.zero & size),
    );

    // 夕日。
    canvas.drawCircle(Offset(w * 0.28, h * 0.62), h * 0.20,
        Paint()..color = const Color(0xFFFFE082).withValues(alpha: 0.9));

    // 街のシルエット。
    final city = Paint()..color = const Color(0xFF37474F);
    final rnd = Random(7);
    var x = 0.0;
    while (x < w) {
      final bw = 18 + rnd.nextDouble() * 26;
      final bh = h * (0.16 + rnd.nextDouble() * 0.20);
      canvas.drawRect(Rect.fromLTWH(x, h * 0.80 - bh, bw, bh + h * 0.2), city);
      x += bw + 2;
    }

    // 地面(コート)。
    canvas.drawRect(Rect.fromLTWH(0, h * 0.80, w, h * 0.2),
        Paint()..color = const Color(0xFFBF7A3A));
    canvas.drawLine(
        Offset(0, h * 0.80),
        Offset(w, h * 0.80),
        Paint()
          ..color = Colors.white70
          ..strokeWidth = 2);

    // ゴール(右)。
    final hx = w * 0.74;
    canvas.drawRect(Rect.fromLTWH(hx + 20, h * 0.18, 6, h * 0.62),
        Paint()..color = const Color(0xFF263238));
    canvas.drawRect(Rect.fromLTWH(hx + 8, h * 0.18, 30, h * 0.20),
        Paint()..color = Colors.white);
    canvas.drawRect(
        Rect.fromLTWH(hx + 8, h * 0.18, 30, h * 0.20),
        Paint()
          ..color = Colors.black26
          ..style = PaintingStyle.stroke);
    final rim = Offset(hx - 18, h * 0.36);
    canvas.drawLine(Offset(hx + 8, h * 0.36), rim,
        Paint()..color = const Color(0xFFE65100)..strokeWidth = 4);
    final net = Paint()
      ..color = Colors.white70
      ..strokeWidth = 1.3;
    for (var i = 0; i < 6; i++) {
      canvas.drawLine(Offset(rim.dx + i * 5, rim.dy),
          Offset(rim.dx + 3 + i * 4, rim.dy + 22), net);
    }

    // ボールの軌跡(放物線の点線)と、ボール。
    final path = Path()..moveTo(w * 0.22, h * 0.70);
    path.quadraticBezierTo(w * 0.42, h * 0.02, rim.dx + 12, rim.dy - 4);
    final dash = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length * 0.78) {
        canvas.drawPath(m.extractPath(d, d + 8), dash);
        d += 16;
      }
    }
    final ball = Offset(w * 0.50, h * 0.215);
    canvas.drawCircle(ball + const Offset(0, 0), 15, Paint()..color = const Color(0xFFE65100));
    final seam = Paint()
      ..color = const Color(0xFF3E2723)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawCircle(ball, 15, seam);
    canvas.drawLine(ball + const Offset(-15, 0), ball + const Offset(15, 0), seam);
    canvas.drawLine(ball + const Offset(0, -15), ball + const Offset(0, 15), seam);
  }

  @override
  bool shouldRepaint(_TitlePainter old) => false;
}

/// ホームの上に置く、いまの時期の場面の帯(高さ [height])。下を暗くして、左下に時期の名前を載せる。
class SceneStrip extends StatelessWidget {
  const SceneStrip(this.asset, this.label, {super.key, this.height = 92});
  final String asset;
  final String label;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Stack(fit: StackFit.expand, children: [
            ArtBanner(asset, height: height),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0xB3000000)],
                  stops: [0.35, 1],
                ),
              ),
            ),
            Positioned(
              left: 14,
              bottom: 8,
              child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(blurRadius: 6)])),
            ),
          ]),
        ),
      );
}

/// 出来事(トレード成立・契約・けが・指名)の小さな絵。角を丸めた横長。
class EventArt extends StatelessWidget {
  const EventArt(this.asset, {super.key, this.width = 120, this.height = 68});
  final String asset;
  final double width, height;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: width,
          height: height,
          child: Image.asset(asset, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF213150))),
        ),
      );
}
