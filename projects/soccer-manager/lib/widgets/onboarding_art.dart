import 'dart:math';

import 'package:flutter/material.dart';

/// 初回チュートリアルの各ページに置く挿絵。
///
/// アイコン1つでは画面の大半が余白になっていた。かといって画像を持たせると
/// 容量が増え、生成した絵はアプリの流儀(平面的で余計な陰影を持たない)に
/// 揃わない。ピッチの描画と同じく、テーマの色を使ってコードで描く。
enum OnboardingArtKind {
  /// 5部から頂点まで上がっていく。
  climb,

  /// 布陣と役割を組む。
  squad,

  /// 移籍とクラブ経営。
  market,

  /// 試合をライブで見て采配する。
  live,

  /// 通算成績とトロフィー。
  career,
}

class OnboardingArt extends StatelessWidget {
  final OnboardingArtKind kind;
  final double width;

  const OnboardingArt({super.key, required this.kind, this.width = 240});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      height: width * 2 / 3,
      child: CustomPaint(
        painter: OnboardingArtPainter(
          kind: kind,
          primary: scheme.primary,
          container: scheme.primaryContainer,
          accent: scheme.secondary,
        ),
      ),
    );
  }
}

class OnboardingArtPainter extends CustomPainter {
  final OnboardingArtKind kind;
  final Color primary;
  final Color container;
  final Color accent;

  const OnboardingArtPainter({
    required this.kind,
    required this.primary,
    required this.container,
    required this.accent,
  });

  static const _turf = Color(0xFF2C7C36);
  static const _turfDark = Color(0xFF20642A);
  static const _line = Color(0xCCFFFFFF);

  @override
  void paint(Canvas canvas, Size size) {
    switch (kind) {
      case OnboardingArtKind.climb:
        _climb(canvas, size);
      case OnboardingArtKind.squad:
        _squad(canvas, size);
      case OnboardingArtKind.market:
        _market(canvas, size);
      case OnboardingArtKind.live:
        _live(canvas, size);
      case OnboardingArtKind.career:
        _career(canvas, size);
    }
  }

  /// 5部から1部へ。ディビジョンを帯として積み、上へ突き抜ける。
  ///
  /// 棒グラフにすると通算成績([_career])の絵と見分けがつかなくなるので、
  /// 「段を上がる」ことが分かる形にしてある。
  void _climb(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const tiers = 5;
    final bandH = h / (tiers + 0.6);
    for (var i = 0; i < tiers; i++) {
      // i=0 が最上段(1部)。上ほど濃く、幅も広い。
      final t = 1 - i / (tiers - 1);
      final bandW = w * (0.46 + 0.34 * t);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH((w - bandW) / 2, bandH * (i + 0.6), bandW,
              bandH * 0.66),
          const Radius.circular(4),
        ),
        Paint()..color = Color.lerp(container, primary, t)!,
      );
    }
    // 帯を貫いて上がる矢印。
    final arrow = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final x = w * 0.5;
    canvas.drawLine(Offset(x, h * 0.92), Offset(x, h * 0.16), arrow);
    canvas.drawPath(
      Path()
        ..moveTo(x - w * 0.055, h * 0.28)
        ..lineTo(x, h * 0.16)
        ..lineTo(x + w * 0.055, h * 0.28),
      arrow,
    );
  }

  /// 自陣半分に 4-4-2 を置く。役割の輪を2つだけ強調する。
  void _squad(Canvas canvas, Size size) {
    final rect = _pitch(canvas, size, halfOnly: true);
    const rows = [
      [0.5],
      [0.16, 0.38, 0.62, 0.84],
      [0.16, 0.38, 0.62, 0.84],
      [0.34, 0.66],
    ];
    const xs = [0.08, 0.30, 0.55, 0.80];
    for (var r = 0; r < rows.length; r++) {
      for (final y in rows[r]) {
        final c = Offset(
          rect.left + rect.width * xs[r],
          rect.top + rect.height * y,
        );
        canvas.drawCircle(c, rect.height * 0.055, Paint()..color = Colors.white);
        // 前線の2人だけ、役割を決めた印として色を変える。
        if (r == rows.length - 1) {
          canvas.drawCircle(c, rect.height * 0.055, Paint()..color = accent);
          canvas.drawCircle(
            c,
            rect.height * 0.095,
            Paint()
              ..color = accent
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.6,
          );
        }
      }
    }
  }

  /// 2つのクラブの間で選手が動き、対価が動く。
  void _market(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final crestW = w * 0.20;
    final crestH = h * 0.44;

    void crest(double cx, Color color) {
      final left = cx - crestW / 2;
      final top = h * 0.16;
      canvas.drawPath(
        Path()
          ..moveTo(cx, top)
          ..lineTo(left + crestW, top + crestH * 0.2)
          ..lineTo(left + crestW, top + crestH * 0.55)
          ..quadraticBezierTo(
              left + crestW, top + crestH * 0.95, cx, top + crestH)
          ..quadraticBezierTo(left, top + crestH * 0.95, left, top + crestH * 0.55)
          ..lineTo(left, top + crestH * 0.2)
          ..close(),
        Paint()..color = color,
      );
    }

    crest(w * 0.22, primary);
    crest(w * 0.78, accent);

    // 行き来する2本の矢印。
    final arrow = Paint()
      ..color = primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    for (final down in const [true, false]) {
      final y = h * (down ? 0.30 : 0.44);
      final from = down ? w * 0.36 : w * 0.64;
      final to = down ? w * 0.64 : w * 0.36;
      canvas.drawLine(Offset(from, y), Offset(to, y), arrow);
      final dir = to > from ? 1.0 : -1.0;
      canvas.drawLine(
          Offset(to, y), Offset(to - 7 * dir, y - 5), arrow);
      canvas.drawLine(
          Offset(to, y), Offset(to - 7 * dir, y + 5), arrow);
    }

    // 積み上がる資金。経営もこの画面の話だと分かるように。
    for (var i = 0; i < 3; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.40, h * (0.86 - i * 0.09), w * 0.20, h * 0.065),
          const Radius.circular(3),
        ),
        Paint()..color = Color.lerp(container, accent, i / 2)!,
      );
    }
  }

  /// 決定機。ボールの軌跡がゴールへ向かう。
  void _live(Canvas canvas, Size size) {
    final rect = _pitch(canvas, size, halfOnly: false);
    final start = Offset(rect.left + rect.width * 0.18, rect.bottom - rect.height * 0.22);
    final end = Offset(rect.right - rect.width * 0.06, rect.center.dy);
    canvas.drawPath(
      Path()
        ..moveTo(start.dx, start.dy)
        ..quadraticBezierTo(
            rect.center.dx, rect.top + rect.height * 0.08, end.dx, end.dy),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );
    canvas.drawCircle(start, rect.height * 0.05, Paint()..color = Colors.white);
    // 決定機の印。
    canvas.drawCircle(
      end,
      rect.height * 0.10,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4,
    );
  }

  /// 積み上がるシーズンと、トロフィー。
  void _career(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    for (var i = 0; i < 6; i++) {
      final t = i / 5;
      final barH = h * (0.14 + 0.34 * t);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * (0.06 + i * 0.10), h - barH, w * 0.07, barH),
          const Radius.circular(3),
        ),
        Paint()..color = Color.lerp(container, primary, t)!,
      );
    }

    // トロフィー。カップ・持ち手・台座。
    final cx = w * 0.78;
    final top = h * 0.16;
    final cupW = w * 0.20;
    final cupH = h * 0.34;
    canvas.drawPath(
      Path()
        ..moveTo(cx - cupW / 2, top)
        ..lineTo(cx + cupW / 2, top)
        ..quadraticBezierTo(cx + cupW / 2, top + cupH, cx, top + cupH)
        ..quadraticBezierTo(cx - cupW / 2, top + cupH, cx - cupW / 2, top)
        ..close(),
      Paint()..color = accent,
    );
    for (final side in const [-1.0, 1.0]) {
      canvas.drawArc(
        Rect.fromCircle(
            center: Offset(cx + side * cupW * 0.5, top + cupH * 0.26),
            radius: cupW * 0.20),
        side < 0 ? pi / 2 : -pi / 2,
        pi,
        false,
        Paint()
          ..color = accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4,
      );
    }
    canvas.drawRect(
      Rect.fromCenter(
          center: Offset(cx, top + cupH + h * 0.06),
          width: cupW * 0.18,
          height: h * 0.12),
      Paint()..color = accent,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(cx, top + cupH + h * 0.14),
            width: cupW * 0.9,
            height: h * 0.07),
        const Radius.circular(3),
      ),
      Paint()..color = primary,
    );
  }

  /// 芝とラインを敷いて、描画に使う矩形を返す。
  Rect _pitch(Canvas canvas, Size size, {required bool halfOnly}) {
    final rect = Rect.fromLTWH(0, size.height * 0.08, size.width,
        size.height * 0.84);
    canvas.save();
    canvas.clipRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(8)));
    const stripes = 6;
    for (var i = 0; i < stripes; i++) {
      canvas.drawRect(
        Rect.fromLTWH(rect.left + rect.width / stripes * i, rect.top,
            rect.width / stripes + 1, rect.height),
        Paint()..color = i.isEven ? _turfDark : _turf,
      );
    }
    final linePaint = Paint()
      ..color = _line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final inner = rect.deflate(rect.height * 0.05);
    canvas.drawRect(inner, linePaint);
    if (halfOnly) {
      // 自陣だけを見せる。右端がハーフウェイライン。
      canvas.drawArc(
        Rect.fromCircle(
            center: Offset(inner.right, inner.center.dy),
            radius: inner.height * 0.22),
        pi / 2,
        pi,
        false,
        linePaint,
      );
    } else {
      canvas.drawLine(Offset(inner.center.dx, inner.top),
          Offset(inner.center.dx, inner.bottom), linePaint);
      canvas.drawCircle(inner.center, inner.height * 0.18, linePaint);
    }
    // ゴール側のペナルティエリア。
    final boxW = inner.width * 0.14;
    final boxH = inner.height * 0.5;
    canvas.drawRect(
      Rect.fromLTWH(inner.left, inner.center.dy - boxH / 2, boxW, boxH),
      linePaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(
          inner.right - boxW, inner.center.dy - boxH / 2, boxW, boxH),
      linePaint,
    );
    canvas.restore();
    return rect;
  }

  @override
  bool shouldRepaint(covariant OnboardingArtPainter oldDelegate) =>
      oldDelegate.kind != kind ||
      oldDelegate.primary != primary ||
      oldDelegate.container != container ||
      oldDelegate.accent != accent;
}
