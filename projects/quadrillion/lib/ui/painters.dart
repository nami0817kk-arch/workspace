import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/game.dart';
import 'widgets.dart';

// 街の絵（TownPainter・本社の建物）は 1.1.0+42 で外した。街の画面は数字とカードだけにしている

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
      text(tr('期を進めると、ここに線が引かれます'), 16, 84, 14);
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
      text(yen(math.pow(10, i).toDouble()).replaceAll('円', '').replaceAll('¥', ''), 2, y + 4, 12);
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

/// 売上と利益（月）の推移。目盛りはふつうの間隔で、利益が負の月は0の線の下に出す
class RevProfitPainter extends CustomPainter {
  final List<HistEntry> hist;
  RevProfitPainter(this.hist);

  static const revCol = Color(0xFF3E6FB0), proCol = Color(0xFF2E8B57), lossCol = Color(0xFFC0392B);

  /// 描いた線の点（テストで確かめる）。[0] が売上、[1] が利益
  final List<List<Offset>> drawn = [[], []];

  /// 0の線の高さ（テストで確かめる）
  double zeroY = 0;

  @override
  void paint(Canvas canvas, Size size) {
    const W = 640.0, H = 180.0, L = 52.0, top = 10.0, bot = 14.0;
    canvas.save();
    canvas.scale(size.width / W, size.height / H);
    void text(String t, double x, double y, double fs, [Color c = Pal.mute]) {
      final tp = TextPainter(text: TextSpan(text: t, style: TextStyle(fontSize: fs, color: c, fontFamily: fontFamily)), textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(canvas, Offset(x, y - tp.height * .8));
    }

    drawn[0].clear();
    drawn[1].clear();
    if (hist.length < 2) {
      text(tr('期を進めると、ここに線が引かれます'), 16, 94, 14);
      canvas.restore();
      return;
    }
    var hi = 0.0, lo = 0.0;
    for (final h in hist) {
      hi = math.max(hi, math.max(h.rev, h.pre));
      lo = math.min(lo, math.min(h.rev, h.pre));
    }
    if (hi <= lo) hi = lo + 1;
    // きりのよい目盛りの幅（1・2・5 × 10の累乗）
    final raw = (hi - lo) / 4;
    final p10 = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    final step = [1.0, 2.0, 5.0, 10.0].map((k) => k * p10).firstWhere((v) => v >= raw);
    lo = (lo / step).floorToDouble() * step;
    hi = (hi / step).ceilToDouble() * step;
    double yOf(double v) => top + (hi - v) / (hi - lo) * (H - top - bot);
    final grid = Paint()
      ..color = const Color(0xFFE2DCCD)
      ..strokeWidth = 1;
    for (var v = lo; v <= hi + step / 2; v += step) {
      final yy = yOf(v);
      canvas.drawLine(Offset(L, yy), Offset(W - 8, yy), grid);
      text(v == 0 ? '0' : yen(v).replaceAll('円', '').replaceAll('¥', ''), 2, yy + 4, 11.5);
    }
    zeroY = yOf(0);
    canvas.drawLine(
        Offset(L, zeroY),
        Offset(W - 8, zeroY),
        Paint()
          ..color = const Color(0xFF8A8270)
          ..strokeWidth = 1.4);
    // 赤字の月は0の線の下を薄く塗る
    final n = hist.length;
    double xOf(int i) => L + i / (n - 1) * (W - L - 12);
    final loss = Paint()..color = const Color(0x22C0392B);
    for (var i = 0; i < n; i++) {
      if (hist[i].pre < 0) {
        final w = (W - L - 12) / (n - 1);
        canvas.drawRect(Rect.fromLTRB(math.max(L, xOf(i) - w / 2), zeroY, math.min(W - 12, xOf(i) + w / 2), yOf(hist[i].pre)), loss);
      }
    }
    void line(int k, double Function(HistEntry) f, Color c) {
      final path = Path();
      for (var i = 0; i < n; i++) {
        final o = Offset(xOf(i), yOf(f(hist[i])));
        drawn[k].add(o);
        if (i == 0) {
          path.moveTo(o.dx, o.dy);
        } else {
          path.lineTo(o.dx, o.dy);
        }
      }
      canvas.drawPath(
          path,
          Paint()
            ..color = c
            ..strokeWidth = 2
            ..style = PaintingStyle.stroke);
    }

    line(0, (h) => h.rev, revCol);
    line(1, (h) => h.pre, proCol);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
