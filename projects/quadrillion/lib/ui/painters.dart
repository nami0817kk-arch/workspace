import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/game.dart';
import 'widgets.dart';

/// 試作の drawTown。320×180 の点描きを、幅に合わせて拡大して描く
class TownPainter extends CustomPainter {
  final Game s;
  TownPainter(this.s);

  @override
  void paint(Canvas canvas, Size size) {
    const W = 320.0, H = 180.0;
    canvas.save();
    canvas.scale(size.width / W, size.height / H);
    final p = Paint()..isAntiAlias = false;
    void rect(double x, double y, double w, double h, Color c) {
      p.color = c;
      canvas.drawRect(Rect.fromLTWH(x, y, w, h), p);
    }

    final sky = Paint()
      ..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF8CCAF5), Color(0xFFE4F3FF)])
          .createShader(const Rect.fromLTWH(0, 0, W, H));
    canvas.drawRect(const Rect.fromLTWH(0, 0, W, H), sky);
    var seed = 7;
    double sr() {
      seed = (seed * 16807) % 2147483647;
      return seed / 2147483647;
    }

    for (var i = 0; i < 5; i++) {
      final cx = (sr() * W).floorToDouble(), cy = 10 + (sr() * 40).floorToDouble();
      rect(cx, cy, 18, 4, Colors.white);
      rect(cx + 4, cy - 3, 10, 3, Colors.white);
    }
    // 太陽
    const r = 9;
    for (var yy = -r; yy <= r; yy++) {
      final w = jsRound(math.sqrt(r * r - yy * yy));
      rect(274 - w, 24.0 + yy, w * 2, 1, const Color(0xFFFFD75E));
    }
    // 遠くの CPU のビル
    final top = s.rankList().where((x) => !x.me).take(16).toList();
    var x = 4.0;
    final lmax = math.log(math.max(top.isNotEmpty ? top.first.cap : 1, 1)) / math.ln10;
    final lmin = math.log(math.max(top.isNotEmpty ? top.last.cap : 1, 1)) / math.ln10;
    final order = top.toList();
    for (var i = order.length - 1; i > 0; i--) {
      final j = (sr() * (i + 1)).floor();
      final t = order[i];
      order[i] = order[j];
      order[j] = t;
    }
    for (final c in order) {
      final hh = jsRound(24 + 96 * (math.log(math.max(c.cap, 1)) / math.ln10 - lmin) / math.max(.3, lmax - lmin));
      final w = 10 + (sr() * 8).floorToDouble();
      rect(x, H - 22 - hh, w, hh, const Color(0xFFA9B6CF));
      for (var yy = H - 20 - hh; yy < H - 26; yy += 5) {
        for (var xx = x + 2; xx < x + w - 2; xx += 3) {
          if (sr() < .35) rect(xx, yy, 1, 2, const Color(0xFFC9D3E6));
        }
      }
      x += w + 2;
      if (x > W) break;
    }
    // 自分のビル
    final mine = [
      for (final b in s.biz) (rev: b.rev, col: Pal.gold),
      for (final c in s.subs()) (rev: c.rev, col: const Color(0xFF4FD1C5)),
    ]..ssort((a, b) => b.rev.compareTo(a.rev));
    x = 20;
    rect(0, H - 22, W, 22, const Color(0xFF7D8A6A));
    rect(0, H - 22, W, 2, const Color(0xFF5C6650));
    if (s.rev * 12 / s.nom() < 5e7) {
      rect(40, H - 40, 26, 18, const Color(0xFF6A5A48));
      rect(46, H - 34, 4, 4, Pal.gold);
      rect(56, H - 34, 4, 4, Pal.gold);
      rect(38, H - 42, 30, 3, const Color(0xFF8A3C32));
    } else {
      for (final b in mine.take(12)) {
        final hh = clampD(math.log(math.max(b.rev, 1e5)) / math.ln10 * 11 - 58, 10, 140);
        final w = 14 + (hh / 14).floorToDouble();
        rect(x, H - 22 - hh, w, hh, const Color(0xFF3E4F7A));
        for (var yy = H - 19 - hh; yy < H - 26; yy += 5) {
          for (var xx = x + 2; xx < x + w - 2; xx += 4) {
            if (sr() < .75) rect(xx, yy, 2, 2, b.col);
          }
        }
        rect(x + w / 2 - 1, H - 26 - hh, 2, 4, b.col);
        x += w + 5;
        if (x > W - 10) break;
      }
    }
    final tp = TextPainter(
        text: TextSpan(text: cm[s.home]!.city, style: const TextStyle(fontSize: 10, color: Color(0xFF2B3550), fontFamily: fontFamily)),
        textDirection: TextDirection.ltr)
      ..layout();
    tp.paint(canvas, Offset(6, 14 - tp.height * .8));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// 試作の drawSpark（時価総額の推移・対数の目盛り）
class SparkPainter extends CustomPainter {
  final List<HistEntry> hist;
  SparkPainter(this.hist);

  @override
  void paint(Canvas canvas, Size size) {
    const W = 640.0, H = 160.0;
    canvas.save();
    canvas.scale(size.width / W, size.height / H);
    void text(String t, double x, double y, double fs) {
      final tp = TextPainter(
          text: TextSpan(text: t, style: TextStyle(fontSize: fs, color: Pal.mute, fontFamily: fontFamily)), textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(canvas, Offset(x, y - tp.height * .8));
    }

    final d = hist.map((x) => math.log(math.max(x.cap, 1)) / math.ln10).toList();
    if (d.length < 2) {
      text('期を進めると、ここに線が引かれます', 16, 84, 14);
      canvas.restore();
      return;
    }
    final lo = d.reduce(math.min), hi = d.reduce(math.max) + .01;
    final grid = Paint()
      ..color = const Color(0xFFE2DCCD)
      ..strokeWidth = 1;
    for (var i = lo.ceil(); i <= hi; i++) {
      final y = H - 12 - (i - lo) / (hi - lo) * (H - 30);
      canvas.drawLine(Offset(40, y), Offset(W - 8, y), grid);
      text(yen(math.pow(10, i).toDouble()).replaceAll('円', ''), 2, y + 4, 12);
    }
    final path = Path();
    for (var i = 0; i < d.length; i++) {
      final x = 40 + i / (d.length - 1) * (W - 50), y = H - 12 - (d[i] - lo) / (hi - lo) * (H - 30);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFC98A00)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
