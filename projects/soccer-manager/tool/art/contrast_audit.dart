/// 撮った画面の、文字と地の色の差(コントラスト比)を機械で測る。
///
/// 明るい見た目を足したとき(2026-11-24)、画面ごとに直書きした白い文字が
/// 明るい地に乗って読めなくなる箇所を、何百枚の画像を目で追う前に拾う
/// ために作った。描かれた文字(RenderParagraph)ごとに、文字の色と、
/// 文字の箱のすぐ外側の画素(=地)の色を比べる。
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

/// 1件の見つかったもの。
class ContrastIssue {
  ContrastIssue(this.text, this.ratio, this.fg, this.bg);
  final String text;
  final double ratio;
  final Color fg;
  final Color bg;

  String _hex(Color c) =>
      (c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0');

  @override
  String toString() =>
      '${ratio.toStringAsFixed(2)} fg#${_hex(fg)} bg#${_hex(bg)} 「$text」';
}

double _lum(Color c) {
  double ch(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double contrastRatio(Color a, Color b) {
  final la = _lum(a), lb = _lum(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// [root] の下の文字を全部測り、比が [threshold] を下回るものを返す。
/// [image] は [root] を pixelRatio [scale] で書き出したもの。
Future<List<ContrastIssue>> auditContrast(
  RenderObject root,
  ui.Image image,
  double scale, {
  double threshold = 3.0,
}) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final bytes = data!.buffer.asUint8List();
  final w = image.width, h = image.height;

  Color? pixel(int x, int y) {
    if (x < 0 || y < 0 || x >= w || y >= h) return null;
    final i = (y * w + x) * 4;
    return Color.fromARGB(255, bytes[i], bytes[i + 1], bytes[i + 2]);
  }

  Color? background(Rect r) {
    // 箱のすぐ外側の輪(2px)の画素の、いちばん多い色を地とみなす。
    final counts = <int, int>{};
    final samples = <int, Color>{};
    void add(int x, int y) {
      final c = pixel(x, y);
      if (c == null) return;
      final q = (c.toARGB32() >> 4) & 0x0F0F0F;
      counts[q] = (counts[q] ?? 0) + 1;
      samples[q] = c;
    }

    final l = (r.left * scale).floor() - 2, t = (r.top * scale).floor() - 2;
    final rr = (r.right * scale).ceil() + 2, b = (r.bottom * scale).ceil() + 2;
    for (var x = l; x <= rr; x += 2) {
      add(x, t);
      add(x, b);
    }
    for (var y = t; y <= b; y += 2) {
      add(l, y);
      add(rr, y);
    }
    if (counts.isEmpty) return null;
    final best = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return samples[best.key];
  }

  final issues = <ContrastIssue>[];
  void visit(RenderObject o) {
    if (o is RenderParagraph && o.hasSize && o.attached) {
      final text = o.text.toPlainText().trim();
      if (text.isNotEmpty) {
        final topLeft = o.localToGlobal(Offset.zero, ancestor: root);
        final bottomRight =
            o.localToGlobal(o.size.bottomRight(Offset.zero), ancestor: root);
        final rect = Rect.fromPoints(topLeft, bottomRight);
        final colors = <Color>{};
        o.text.visitChildren((span) {
          if (span is TextSpan &&
              (span.text ?? '').trim().isNotEmpty &&
              span.style?.color != null) {
            colors.add(span.style!.color!);
          }
          return true;
        });
        final rootColor = o.text.style?.color;
        if (colors.isEmpty && rootColor != null) colors.add(rootColor);
        // 隠れている文字(IndexedStack の裏・スクロールで外へ出たもの・
        // 上に別の画面が重なったもの)は測らない。中心で当たり判定を
        // 取り、その文字に届くものだけを見る。
        bool reachable() {
          if (root is! RenderBox) return true;
          final result = BoxHitTestResult();
          root.hitTest(result, position: rect.center);
          return result.path.any((e) => e.target == o);
        }

        final visible = rect.width > 2 &&
            reachable() &&
            rect.height > 2 &&
            rect.right > 0 &&
            rect.bottom > 0 &&
            rect.left * scale < w &&
            rect.top * scale < h;
        if (visible) {
          final bg = background(rect);
          if (bg != null) {
            for (final c in colors) {
              // 半透明の文字は地と混ぜた色で見る。
              final fg = Color.alphaBlend(c, bg);
              final ratio = contrastRatio(fg, bg);
              if (ratio < threshold) {
                issues.add(ContrastIssue(
                    text.length > 30 ? '${text.substring(0, 30)}…' : text,
                    ratio,
                    fg,
                    bg));
              }
            }
          }
        }
      }
    }
    o.visitChildren(visit);
  }

  visit(root);
  return issues;
}
