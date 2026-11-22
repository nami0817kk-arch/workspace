import 'package:flutter/material.dart';

import '../engine/life.dart';
import 'theme.dart';

/// 能力・指標の横棒。
class Gauge extends StatelessWidget {
  const Gauge(this.label, this.value, {super.key, this.color = Pal.accent, this.labelWidth = 56});
  final String label;
  final double value;
  final Color color;
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0, 100).toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        SizedBox(width: labelWidth, child: Text(label, style: const TextStyle(fontSize: 13.5))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: v / 100,
              minHeight: 8,
              backgroundColor: const Color(0xFF0E0C0A),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        SizedBox(
          width: 34,
          child: Text(value.round().toString(),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}

class Panel extends StatelessWidget {
  const Panel({super.key, this.title, required this.child, this.padding = 14});
  final String? title;
  final Widget child;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Pal.panel,
        border: Border.all(color: Pal.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(title!,
                style: const TextStyle(
                    color: Pal.gold, fontWeight: FontWeight.w600, letterSpacing: 2, fontSize: 15)),
          ),
        child,
      ]),
    );
  }
}

class Tag extends StatelessWidget {
  const Tag(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 1),
        decoration: BoxDecoration(
          border: Border.all(color: Pal.gold),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(text, style: const TextStyle(color: Pal.gold, fontSize: 12)),
      );
}

class KV extends StatelessWidget {
  const KV(this.k, this.v, {super.key});
  final String k, v;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 3),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Pal.line, style: BorderStyle.solid))),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(k, style: const TextStyle(color: Pal.muted, fontSize: 13.5)),
          Text(v, style: const TextStyle(fontSize: 13.5)),
        ]),
      );
}

class BigButton extends StatelessWidget {
  const BigButton(this.text, this.onTap, {super.key, this.secondary = false});
  final String text;
  final VoidCallback? onTap;
  final bool secondary;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: secondary ? Pal.panel2 : Pal.accent,
            foregroundColor: Pal.ink,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: onTap,
          child: Text(text, style: const TextStyle(fontSize: 16, letterSpacing: 2)),
        ),
      );
}

Color logColor(String kind) => switch (kind) {
      'good' => Pal.good,
      'bad' => Pal.bad,
      'big' => Pal.gold,
      _ => Pal.line,
    };

class LogList extends StatelessWidget {
  const LogList(this.entries, {super.key});
  final List<LogEntry> entries;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final e in entries)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.only(left: 10),
              decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: logColor(e.kind), width: 3))),
              child: Text.rich(TextSpan(children: [
                TextSpan(
                    text: '${e.t}  ', style: const TextStyle(color: Pal.muted, fontSize: 12)),
                TextSpan(
                    text: e.txt,
                    style: TextStyle(
                        fontSize: 14.5, color: e.kind == 'big' ? Pal.gold : Pal.ink, height: 1.55)),
              ])),
            ),
        ],
      );
}

/// 人生の軌跡。健康・幸福・知識・人間関係の4本。
class LifeChart extends StatelessWidget {
  const LifeChart(this.hist, {super.key});
  final List<HistPoint> hist;

  @override
  Widget build(BuildContext context) => Column(children: [
        AspectRatio(aspectRatio: 3.2, child: CustomPaint(painter: _ChartPainter(hist), size: Size.infinite)),
        const SizedBox(height: 6),
        const Wrap(spacing: 14, children: [
          _Legend('健康', Pal.good),
          _Legend('幸福', Pal.gold),
          _Legend('知識', Pal.blue),
          _Legend('人間関係', Pal.purple),
        ]),
      ]);
}

class _Legend extends StatelessWidget {
  const _Legend(this.text, this.color);
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 3, color: color),
        const SizedBox(width: 5),
        Text(text, style: TextStyle(color: color, fontSize: 12)),
      ]);
}

class _ChartPainter extends CustomPainter {
  _ChartPainter(this.h);
  final List<HistPoint> h;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(6)),
        Paint()..color = const Color(0xFF17130F));
    if (h.length < 2) return;
    const pl = 28.0, pr = 8.0, pt = 8.0, pb = 18.0;
    final x0 = h.first.age, x1 = h.last.age;
    double x(double a) => pl + (a - x0) / ((x1 - x0) == 0 ? 1 : (x1 - x0)) * (size.width - pl - pr);
    double y(double v) => pt + (1 - v.clamp(0, 100) / 100) * (size.height - pt - pb);

    final grid = Paint()
      ..color = Pal.line
      ..strokeWidth = 1;
    void text(String s, Offset o, {TextAlign align = TextAlign.left}) {
      final tp = TextPainter(
        text: TextSpan(text: s, style: const TextStyle(color: Pal.muted, fontSize: 10)),
        textDirection: TextDirection.ltr,
      )..layout();
      final dx = align == TextAlign.center ? o.dx - tp.width / 2 : o.dx;
      tp.paint(canvas, Offset(dx, o.dy - tp.height / 2));
    }

    for (final v in [0.0, 50.0, 100.0]) {
      canvas.drawLine(Offset(pl, y(v)), Offset(size.width - pr, y(v)), grid);
      text(v.round().toString(), Offset(2, y(v)));
    }
    for (var a = (x0 / 10).ceil() * 10; a <= x1; a += 10) {
      text('$a歳', Offset(x(a.toDouble()), size.height - 6), align: TextAlign.center);
    }
    void line(double Function(HistPoint) f, Color c) {
      final p = Path();
      for (var i = 0; i < h.length; i++) {
        final o = Offset(x(h[i].age), y(f(h[i])));
        i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(
          p,
          Paint()
            ..color = c
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8);
    }

    line((p) => p.hp, Pal.good);
    line((p) => p.joy, Pal.gold);
    line((p) => p.chi, Pal.blue);
    line((p) => p.net, Pal.purple);
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) => old.h.length != h.length;
}
