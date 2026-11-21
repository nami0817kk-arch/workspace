import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'common.dart';
import 'live_playback.dart';
import 'style.dart';

/// 采配の画面の上の得点板。両チームの印・名前・点・クォーターごとの点と、真ん中に時計(区切りの名前)と見出し。
class LiveScoreboard extends StatelessWidget {
  const LiveScoreboard({
    super.key,
    required this.home,
    required this.away,
    required this.homeName,
    required this.awayName,
    required this.homePts,
    required this.awayPts,
    required this.homePeriods,
    required this.awayPeriods,
    required this.mineHome,
    required this.clock,
    this.headline,
    this.headlineColor = GmColors.gold,
  });

  final int home, away;
  final String homeName, awayName;
  final int homePts, awayPts;
  final List<int> homePeriods, awayPeriods;
  final bool mineHome;

  /// 真ん中の時計(「2Q 5:32」「前半終了」など)。動いている間は毎フレーム変わる。
  final ValueNotifier<String> clock;

  /// 流れの見出し(「8-0のラン」「逆転！」)。
  final String? headline;
  final Color headlineColor;

  @override
  Widget build(BuildContext context) {
    Widget side(int team, String name, int pts, List<int> periods, bool mine, CrossAxisAlignment align) => Expanded(
          child: Row(
            mainAxisAlignment: align == CrossAxisAlignment.start ? MainAxisAlignment.start : MainAxisAlignment.end,
            children: [
              if (align == CrossAxisAlignment.start) ...[TeamBadge(team: team, size: 26), const SizedBox(width: 6)],
              Flexible(
                child: Column(
                  crossAxisAlignment: align,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(name, maxLines: 1, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: mine ? GmColors.ball : GmColors.text)),
                    ),
                    Text(periods.join('・'), style: const TextStyle(fontSize: 10, color: GmColors.sub)),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text('$pts', style: const TextStyle(fontSize: 30, height: 1.05, fontWeight: FontWeight.bold)),
              if (align == CrossAxisAlignment.end) ...[const SizedBox(width: 6), TeamBadge(team: team, size: 26)],
            ],
          ),
        );
    return Container(
      key: const Key('live-court'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: GmColors.panel, borderRadius: BorderRadius.circular(10), border: Border.all(color: GmColors.line)),
      child: Column(
        children: [
          Row(children: [
            side(away, awayName, awayPts, awayPeriods, !mineHome, CrossAxisAlignment.start),
            ValueListenableBuilder<String>(
              valueListenable: clock,
              builder: (_, v, __) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: GmColors.bg, borderRadius: BorderRadius.circular(6)),
                child: Text(v, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: GmColors.gold, fontFeatures: [FontFeature.tabularFigures()])),
              ),
            ),
            side(home, homeName, homePts, homePeriods, mineHome, CrossAxisAlignment.end),
          ]),
          if (headline != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(headline!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: headlineColor)),
            ),
        ],
      ),
    );
  }
}

/// 上から見たコートに、10人(チームの色の丸と背番号)とボールを動かす。シュートを打った場所に印。
/// 押した選手を [onTap] で返す(何も無い所なら null)。
class CourtView extends StatelessWidget {
  const CourtView({
    super.key,
    required this.frame,
    required this.marks,
    required this.homeColor,
    required this.awayColor,
    required this.number,
    required this.mineSide,
    this.selected,
    this.onTap,
  });

  final ValueNotifier<CourtFrame?> frame;
  final List<Cue> marks;
  final Color homeColor, awayColor;
  final int Function(Who) number;
  final int mineSide;
  final Who? selected;
  final void Function(Who?)? onTap;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: courtLen / (courtWid + 1.4),
      child: LayoutBuilder(builder: (context, box) {
        final scale = box.maxWidth / courtLen;
        return GestureDetector(
          onTapUp: (d) {
            final f = frame.value;
            if (f == null || onTap == null) return;
            final m = Offset(d.localPosition.dx / scale, d.localPosition.dy / scale);
            Who? best;
            var bd = 1.4;
            for (final e in f.pos.entries) {
              final dist = (e.value - m).distance;
              if (dist < bd) {
                bd = dist;
                best = e.key;
              }
            }
            onTap!(best);
          },
          child: CustomPaint(
            painter: _FloorPainter(homeColor: homeColor, awayColor: awayColor),
            foregroundPainter: _PlayersPainter(
              frame: frame,
              marks: marks,
              homeColor: homeColor,
              awayColor: awayColor,
              sameColor: homeColor == awayColor,
              number: number,
              mineSide: mineSide,
              selected: selected,
            ),
            size: Size.infinite,
          ),
        );
      }),
    );
  }
}

/// コートの床と線(メートルで描く)。左の半面はホームが攻める側(アウェーの陣地)、右はアウェーが攻める側。
class _FloorPainter extends CustomPainter {
  _FloorPainter({required this.homeColor, required this.awayColor});
  final Color homeColor, awayColor;

  @override
  void paint(Canvas canvas, Size s) {
    final k = s.width / courtLen;
    canvas.save();
    canvas.scale(k);
    const court = Rect.fromLTWH(0, 0, courtLen, courtWid);
    canvas.drawRect(
      court,
      Paint()
        ..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF9C6B3C), Color(0xFF7A5230)]).createShader(court),
    );
    final grain = Paint()
      ..color = const Color(0x14000000)
      ..strokeWidth = 0.05;
    for (var y = 0.5; y < courtWid; y += 0.7) {
      canvas.drawLine(Offset(0, y), Offset(courtLen, y), grain);
    }
    // 守る側の陣地をうっすらチームの色に(左はアウェーが守る、右はホームが守る)
    canvas.drawRect(const Rect.fromLTWH(0, 0, courtLen / 2, courtWid), Paint()..color = awayColor.withValues(alpha: 0.28));
    canvas.drawRect(const Rect.fromLTWH(courtLen / 2, 0, courtLen / 2, courtWid), Paint()..color = homeColor.withValues(alpha: 0.28));
    canvas.drawRect(court, Paint()..color = const Color(0x40000000));
    // ベンチの帯
    canvas.drawRect(const Rect.fromLTWH(0, courtWid, courtLen, 1.4), Paint()..color = GmColors.panel);
    final line = Paint()
      ..color = const Color(0x8CFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.08;
    canvas.drawRect(court.deflate(0.05), line);
    canvas.drawLine(const Offset(courtLen / 2, 0), const Offset(courtLen / 2, courtWid), line);
    canvas.drawCircle(const Offset(courtLen / 2, courtWid / 2), 1.8, line);
    for (final left in [true, false]) {
      double x(double v) => left ? v : courtLen - v;
      const cy = courtWid / 2;
      canvas.drawRect(Rect.fromLTRB(math.min(x(0), x(5.8)), cy - 2.45, math.max(x(0), x(5.8)), cy + 2.45), line);
      canvas.drawCircle(Offset(x(5.8), cy), 1.8, line);
      final hoop = Offset(x(1.6), cy);
      // 3ポイントの線(角はまっすぐ)
      const r = 6.75;
      final a = math.asin((cy - 0.9) / r);
      canvas.drawArc(Rect.fromCircle(center: hoop, radius: r), left ? -a : math.pi - a, 2 * a, false, line);
      final cornerX = x(1.6 + r * math.cos(a));
      canvas.drawLine(Offset(x(0), 0.9), Offset(cornerX, 0.9), line);
      canvas.drawLine(Offset(x(0), courtWid - 0.9), Offset(cornerX, courtWid - 0.9), line);
      // ボード とリング
      canvas.drawLine(Offset(x(1.2), cy - 0.9), Offset(x(1.2), cy + 0.9), line..strokeWidth = 0.12);
      line.strokeWidth = 0.08;
      canvas.drawCircle(hoop, 0.23, Paint()
        ..color = GmColors.ball
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.08);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FloorPainter old) => old.homeColor != homeColor || old.awayColor != awayColor;
}

class _PlayersPainter extends CustomPainter {
  _PlayersPainter({
    required this.frame,
    required this.marks,
    required this.homeColor,
    required this.awayColor,
    required this.sameColor,
    required this.number,
    required this.mineSide,
    required this.selected,
  }) : super(repaint: frame);

  final ValueNotifier<CourtFrame?> frame;
  final List<Cue> marks;
  final Color homeColor, awayColor;
  final bool sameColor;
  final int Function(Who) number;
  final int mineSide;
  final Who? selected;

  @override
  void paint(Canvas canvas, Size s) {
    final k = s.width / courtLen;
    // シュートの印(入ったら塗り、外れたら輪)
    for (final m in marks) {
      final c = m.side == 0 ? homeColor : awayColor;
      final p = Offset(m.at.dx * k, m.at.dy * k);
      if (m.made) {
        canvas.drawCircle(p, 0.2 * k, Paint()..color = (sameColor && m.side == 1 ? Colors.white : c).withValues(alpha: 0.75));
      } else {
        canvas.drawCircle(
          p,
          0.18 * k,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.05 * k,
        );
      }
    }
    final f = frame.value;
    if (f == null) return;
    final r = 0.62 * k;
    // 攻めている側を後に描く(ボールを持つ人が上に)
    final keys = f.pos.keys.toList()..sort((a, b) => (a == f.holder ? 1 : 0).compareTo(b == f.holder ? 1 : 0));
    for (final w in keys) {
      final p = f.pos[w]! * k;
      final a = (f.alpha[w] ?? 1).clamp(0.0, 1.0);
      if (a <= 0.02) continue;
      final team = w.$1 == 0 ? homeColor : awayColor;
      final white = sameColor && w.$1 == 1;
      canvas.drawCircle(p + Offset(0, 0.12 * k), r, Paint()..color = Colors.black.withValues(alpha: 0.35 * a));
      canvas.drawCircle(p, r, Paint()..color = (white ? Colors.white : team).withValues(alpha: a));
      canvas.drawCircle(
        p,
        r,
        Paint()
          ..color = (w.$1 == mineSide ? GmColors.gold : Colors.white).withValues(alpha: (w.$1 == mineSide ? 0.95 : 0.6) * a)
          ..style = PaintingStyle.stroke
          ..strokeWidth = (w.$1 == mineSide ? 0.13 : 0.07) * k,
      );
      if (w == selected) {
        canvas.drawCircle(
          p,
          r * 1.55,
          Paint()
            ..color = GmColors.text.withValues(alpha: a)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.08 * k,
        );
      }
      final tp = TextPainter(
        text: TextSpan(
          text: '${number(w)}',
          style: TextStyle(fontFamily: 'NotoSansJP', fontSize: 0.66 * k, height: 1, fontWeight: FontWeight.bold, color: (white ? team : Colors.white).withValues(alpha: a)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
    }
    // ボール(高く上がるほど大きく、影は床に)
    final b = f.ball * k;
    final lift = f.lift.clamp(0.0, 1.5);
    canvas.drawCircle(b + Offset(0.15 * k, 0.2 * k), 0.24 * k, Paint()..color = Colors.black.withValues(alpha: 0.3));
    final up = b - Offset(0, lift * 1.6 * k);
    canvas.drawCircle(up, (0.3 + lift * 0.18) * k, Paint()..color = GmColors.ball);
    canvas.drawCircle(
      up,
      (0.3 + lift * 0.18) * k,
      Paint()
        ..color = const Color(0xFF5A2A00)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.05 * k,
    );
  }

  @override
  bool shouldRepaint(covariant _PlayersPainter old) => old.marks.length != marks.length || old.selected != selected || old.frame != frame;
}

/// 自分から見た点差の流れ。上(リード)は緑、下(ビハインド)は赤。4つのクォーターに区切りの線。
class MomentumBar extends StatelessWidget {
  const MomentumBar({super.key, required this.diff, this.marks = const [], this.onMark});

  /// 1分ごとの、自分から見た点差。
  final List<int> diff;

  /// 印(試合の分・ひとこと・采配なら true)。采配は金、逆転は白の縦線。押すと [onMark] にひとこと。
  final List<(int, String, bool)> marks;
  final void Function(String)? onMark;

  @override
  Widget build(BuildContext context) => Container(
        height: marks.isEmpty ? 46 : 58,
        decoration: BoxDecoration(color: GmColors.panel, borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        child: LayoutBuilder(
          builder: (context, box) => GestureDetector(
            onTapUp: onMark == null || marks.isEmpty
                ? null
                : (d) {
                    final total = math.max(48, diff.length);
                    (int, String, bool)? best;
                    var bd = 18.0;
                    for (final m in marks) {
                      final x = box.maxWidth * (m.$1 + 0.5) / total;
                      final dist = (x - d.localPosition.dx).abs();
                      if (dist < bd) {
                        bd = dist;
                        best = m;
                      }
                    }
                    if (best != null) onMark!(best.$2);
                  },
            child: CustomPaint(painter: _MomentumPainter(diff, marks), size: Size.infinite),
          ),
        ),
      );
}

class _MomentumPainter extends CustomPainter {
  _MomentumPainter(this.diff, [this.marks = const []]);
  final List<int> diff;
  final List<(int, String, bool)> marks;

  @override
  void paint(Canvas canvas, Size s) {
    final mid = s.height / 2;
    final total = math.max(48, diff.length);
    final guide = Paint()
      ..color = GmColors.line
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, mid), Offset(s.width, mid), guide);
    for (var q = 1; q < 4; q++) {
      final x = s.width * q * 12 / total;
      canvas.drawLine(Offset(x, 2), Offset(x, s.height - 2), guide);
    }
    if (diff.isEmpty) return;
    final peak = math.max(10, diff.map((d) => d.abs()).reduce(math.max)).toDouble();
    double x(int i) => s.width * (i + 1) / total;
    double y(int d) => mid - d / peak * (mid - 3);
    for (final up in [true, false]) {
      final path = Path()..moveTo(0, mid);
      for (var i = 0; i < diff.length; i++) {
        final d = up ? math.max(0, diff[i]) : math.min(0, diff[i]);
        path.lineTo(x(i), y(d));
      }
      path
        ..lineTo(x(diff.length - 1), mid)
        ..close();
      canvas.drawPath(path, Paint()..color = (up ? GmColors.good : GmColors.bad).withValues(alpha: 0.55));
    }
    final line = Path()..moveTo(0, mid);
    for (var i = 0; i < diff.length; i++) {
      line.lineTo(x(i), y(diff[i]));
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = GmColors.text
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    // 印(采配は金、逆転は白)。上に小さな三角
    for (final m in marks) {
      final mx = s.width * (m.$1 + 0.5) / total;
      final c = m.$3 ? GmColors.gold : Colors.white;
      canvas.drawLine(
        Offset(mx, 6),
        Offset(mx, s.height),
        Paint()
          ..color = c.withValues(alpha: 0.8)
          ..strokeWidth = 1.2,
      );
      canvas.drawPath(
        Path()
          ..moveTo(mx - 4, 0)
          ..lineTo(mx + 4, 0)
          ..lineTo(mx, 6)
          ..close(),
        Paint()..color = c,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MomentumPainter old) => old.diff.length != diff.length || old.diff != diff || old.marks.length != marks.length;
}
