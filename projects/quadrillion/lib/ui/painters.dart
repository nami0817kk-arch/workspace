import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/game.dart';
import 'widgets.dart';

/// 試作の drawTown。320×180 の点描きを、幅に合わせて拡大して描く
class TownPainter extends CustomPainter {
  final Game s;

  /// 描く中身が変わったかの目印（月・売上・時価総額・事業の数・拠点・言語）。同じなら描き直さない
  final int stamp;

  /// 絵の横の幅（高さは180）。横向きの画面では横に広い 480（1.1.0+25）
  final double W;

  /// 見ている都市圏（自分の国の都市の番号）と、そこにある自社の店などの数（1.1.0+26。看板の数になる）
  final int city;
  final double shops;
  TownPainter(this.s, {this.W = 320, this.city = 0})
      : shops = _cityUnits(s, city),
        stamp = Object.hash(s.turn, s.rev, s.cap, s.biz.length, s.subs().length, s.home, s.wealth, L.lang, city);

  static double _cityUnits(Game s, int city) {
    if (!s.unitsOn) return 0;
    var n = 0.0;
    for (final b in s.biz) {
      for (final k in s.siteKeys(s.home, s.kindB(b))) {
        final p = k.split('/');
        if (p[1] == '$city' || (city == 0 && p[1] == '-' && p[2] == 'n')) n += s.unitsAt(b, k);
      }
    }
    return n;
  }

  @override
  void paint(Canvas canvas, Size size) {
    const H = 180.0;
    final W = this.W;
    canvas.save();
    canvas.scale(size.width / W, size.height / H);
    final p = Paint()..isAntiAlias = false;
    void rect(double x, double y, double w, double h, Color c) {
      p.color = c;
      canvas.drawRect(Rect.fromLTWH(x, y, w, h), p);
    }

    final sky = Paint()
      ..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF8CCAF5), Color(0xFFE4F3FF)])
          .createShader(Rect.fromLTWH(0, 0, W, H));
    canvas.drawRect(Rect.fromLTWH(0, 0, W, H), sky);
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
      rect(W - 46 - w, 24.0 + yy, w * 2, 1, const Color(0xFFFFD75E));
    }
    // 遠くの CPU のビル
    final top = s.rankList().where((x) => !x.me).take(W > 320 ? 24 : 16).toList();
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
      // 宿敵のビルは、その宿敵の色で塗る（1.1.0+26）
      final rv = c.c?.rival;
      rect(x, H - 22 - hh, w, hh, rv != null ? Color.lerp(_hex(rv.col), const Color(0xFFA9B6CF), .35)! : const Color(0xFFA9B6CF));
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
    // 店の看板（その都市圏にある自社の店などの数。多いほど並ぶ。1.1.0+26）
    if (shops > 0) {
      final n = math.min(38, shops <= 18 ? shops.ceil() : (18 + math.log(shops / 18) / math.ln2 * 5).round());
      for (var i = 0; i < n; i++) {
        final sx = 6.0 + i * (W - 12) / math.max(n, 1);
        rect(sx, H - 15, 9, 9, const Color(0xFFF3EBDD));
        rect(sx - 1, H - 17, 11, 3, Pal.gold);
        rect(sx + 3, H - 11, 3, 5, const Color(0xFF6A5A48));
      }
    }
    final cities = s.cityList(s.home);
    final cityName = city < cities.length ? (L.en ? cities[city].en : cities[city].ja) : cm[s.home]!.city;
    final tp = TextPainter(
        text: TextSpan(text: cityName, style: const TextStyle(fontSize: 10, color: Color(0xFF2B3550), fontFamily: fontFamily)),
        textDirection: TextDirection.ltr)
      ..layout();
    tp.paint(canvas, Offset(6, 14 - tp.height * .8));
    canvas.restore();
  }

  /// 900社の並べ替えを伴うので、中身が変わったときだけ描き直す（上の帯の数字が光るあいだも描き直さない）
  @override
  bool shouldRepaint(covariant TownPainter oldDelegate) => oldDelegate.s != s || oldDelegate.stamp != stamp || oldDelegate.W != W;
}

/// 「#9fb3ff」の色
Color _hex(String h) => Color(int.parse('FF${h.replaceAll('#', '')}', radix: 16));

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
