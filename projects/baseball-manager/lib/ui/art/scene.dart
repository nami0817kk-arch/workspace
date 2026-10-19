import 'dart:math';

import 'package:flutter/material.dart';

import '../../game/calendar.dart';
import '../../game/career.dart';
import '../../game/player.dart';
import 'avatar.dart';

/// 季節で変わる球場の背景に、選手が立つ。
class SceneBanner extends StatelessWidget {
  const SceneBanner({
    super.key,
    required this.season,
    required this.stage,
    required this.role,
    required this.mood,
    required this.label,
    this.height = 168,
  });

  final Season season;
  final Stage stage;
  final Role role;
  final Mood mood;

  /// 右下に大きく出すターン名(「7月」「夏」)。
  final String label;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          child: Stack(
            key: ValueKey(season),
            fit: StackFit.expand,
            children: [
              CustomPaint(painter: ScenePainter(season)),
              Positioned(
                left: 0,
                right: 0,
                bottom: 6,
                child: Align(
                  alignment: const Alignment(-0.45, 1),
                  child: PlayerAvatar(
                      stage: stage,
                      role: role,
                      mood: mood,
                      height: height * 0.72),
                ),
              ),
              Positioned(
                left: 14,
                top: 8,
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [Shadow(blurRadius: 6, color: Color(0x66000000))],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Palette {
  const _Palette(this.skyTop, this.skyBottom, this.hill, this.grassA,
      this.grassB, this.sun);
  final Color skyTop;
  final Color skyBottom;
  final Color hill;
  final Color grassA;
  final Color grassB;
  final Color sun;
}

_Palette _paletteOf(Season s) => switch (s) {
      Season.spring => const _Palette(
          Color(0xFFBFE3FF),
          Color(0xFFFFE6EF),
          Color(0xFF9CCC65),
          Color(0xFF7CB342),
          Color(0xFF8BC34A),
          Color(0xFFFFF59D)),
      Season.summer => const _Palette(
          Color(0xFF4FC3F7),
          Color(0xFFD6F3FF),
          Color(0xFF43A047),
          Color(0xFF2E9B3E),
          Color(0xFF3CB04D),
          Color(0xFFFFEB3B)),
      Season.autumn => const _Palette(
          Color(0xFFFFC38A),
          Color(0xFFFFEBD0),
          Color(0xFFB59A4A),
          Color(0xFF8DA13E),
          Color(0xFF9DB44A),
          Color(0xFFFF8F3D)),
      Season.winter => const _Palette(
          Color(0xFFB7C6DA),
          Color(0xFFF1F5FA),
          Color(0xFFCFD8DC),
          Color(0xFFB9C9BE),
          Color(0xFFC6D4CB),
          Color(0xFFFFFFFF)),
    };

class ScenePainter extends CustomPainter {
  ScenePainter(this.season);
  final Season season;

  @override
  void paint(Canvas canvas, Size size) {
    final p = _paletteOf(season);
    final w = size.width, h = size.height;
    final horizon = h * 0.60;

    // 空
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.skyTop, p.skyBottom],
        ).createShader(Offset.zero & size),
    );

    // 太陽(季節で位置と大きさが違う)
    final sunPos = switch (season) {
      Season.summer => Offset(w * 0.80, h * 0.20),
      Season.autumn => Offset(w * 0.78, h * 0.42),
      Season.spring => Offset(w * 0.82, h * 0.26),
      Season.winter => Offset(w * 0.78, h * 0.34),
    };
    final sunR = season == Season.summer ? 22.0 : 16.0;
    canvas.drawCircle(
        sunPos, sunR * 2.2, Paint()..color = p.sun.withValues(alpha: 0.25));
    canvas.drawCircle(sunPos, sunR, Paint()..color = p.sun);

    // 雲
    final cloud = Paint()
      ..color =
          Colors.white.withValues(alpha: season == Season.winter ? 0.9 : 0.8);
    _cloud(canvas, Offset(w * 0.18, h * 0.18), 1.0, cloud);
    _cloud(canvas, Offset(w * 0.55, h * 0.12), 0.7, cloud);
    if (season != Season.summer) {
      _cloud(canvas, Offset(w * 0.40, h * 0.34), 0.6, cloud);
    }

    // 遠くの山
    final hill = Path()
      ..moveTo(0, horizon)
      ..quadraticBezierTo(w * 0.18, horizon - 34, w * 0.4, horizon - 8)
      ..quadraticBezierTo(w * 0.62, horizon - 40, w * 0.85, horizon - 10)
      ..quadraticBezierTo(w * 0.95, horizon - 22, w, horizon - 6)
      ..lineTo(w, horizon + 4)
      ..lineTo(0, horizon + 4)
      ..close();
    canvas.drawPath(hill, Paint()..color = p.hill);

    // 外野フェンス
    final fenceTop = horizon - 2;
    canvas.drawRect(Rect.fromLTWH(0, fenceTop, w, 13),
        Paint()..color = const Color(0xFF2E5E3A));
    canvas.drawRect(Rect.fromLTWH(0, fenceTop, w, 3),
        Paint()..color = const Color(0xFFF2C94C));
    final post = Paint()..color = const Color(0x33FFFFFF);
    for (var x = 8.0; x < w; x += 22) {
      canvas.drawRect(Rect.fromLTWH(x, fenceTop + 3, 2, 10), post);
    }

    // 芝(縞)
    final grassTop = fenceTop + 13;
    for (var i = 0; i < 8; i++) {
      final x0 = w / 8 * i;
      canvas.drawRect(Rect.fromLTWH(x0, grassTop, w / 8 + 1, h - grassTop),
          Paint()..color = i.isEven ? p.grassA : p.grassB);
    }

    // 土(ダイヤモンドの走路)
    final dirt = Paint()
      ..color = season == Season.winter
          ? const Color(0xFFCDB9A3)
          : const Color(0xFFC89B6B);
    final cx = w * 0.5, by = h - 6;
    final path = Path()
      ..moveTo(cx - w * 0.30, by)
      ..lineTo(cx - w * 0.05, grassTop + 6)
      ..lineTo(cx + w * 0.05, grassTop + 6)
      ..lineTo(cx + w * 0.30, by)
      ..close();
    canvas.drawPath(path, dirt);
    // ベース
    final base = Paint()..color = Colors.white;
    for (final o in [
      Offset(cx, grassTop + 12),
      Offset(cx - w * 0.17, h * 0.80),
      Offset(cx + w * 0.17, h * 0.80)
    ]) {
      canvas.drawRect(Rect.fromCenter(center: o, width: 7, height: 4), base);
    }

    // 季節の飾り
    final rng = Random(season.index + 7);
    switch (season) {
      case Season.spring:
        for (var i = 0; i < 26; i++) {
          _petal(
              canvas,
              Offset(rng.nextDouble() * w, rng.nextDouble() * h * 0.9),
              const Color(0xFFFFB7C9),
              rng.nextDouble());
        }
      case Season.autumn:
        for (var i = 0; i < 20; i++) {
          _petal(
              canvas,
              Offset(rng.nextDouble() * w, rng.nextDouble() * h * 0.9),
              i.isEven ? const Color(0xFFE65100) : const Color(0xFFBF360C),
              rng.nextDouble());
        }
      case Season.winter:
        for (var i = 0; i < 36; i++) {
          canvas.drawCircle(
              Offset(rng.nextDouble() * w, rng.nextDouble() * h),
              1 + rng.nextDouble() * 1.8,
              Paint()..color = Colors.white.withValues(alpha: 0.9));
        }
      case Season.summer:
        // 入道雲
        _cloud(canvas, Offset(w * 0.10, horizon - 12), 1.5,
            Paint()..color = Colors.white.withValues(alpha: 0.95));
    }
  }

  void _cloud(Canvas c, Offset o, double s, Paint paint) {
    c.drawOval(
        Rect.fromCenter(center: o, width: 44 * s, height: 16 * s), paint);
    c.drawOval(
        Rect.fromCenter(
            center: o + Offset(12 * s, -6 * s), width: 28 * s, height: 16 * s),
        paint);
    c.drawOval(
        Rect.fromCenter(
            center: o + Offset(-12 * s, -4 * s), width: 24 * s, height: 14 * s),
        paint);
  }

  void _petal(Canvas c, Offset o, Color color, double rot) {
    c.save();
    c.translate(o.dx, o.dy);
    c.rotate(rot * pi);
    c.drawOval(Rect.fromCenter(center: Offset.zero, width: 7, height: 4),
        Paint()..color = color);
    c.restore();
  }

  @override
  bool shouldRepaint(ScenePainter old) => old.season != season;
}
