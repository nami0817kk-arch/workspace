import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../gm/game_sim.dart';
import 'common.dart';
import 'style.dart';

/// 采配の画面の上の板。上から見たコート(左がアウェー・右がホーム、それぞれのチームの色)に、
/// 大きな点と区切りの名前、下に「試合の流れ」(自分から見た点差の線)。
class LiveCourt extends StatelessWidget {
  const LiveCourt({
    super.key,
    required this.home,
    required this.away,
    required this.homeName,
    required this.awayName,
    required this.result,
    required this.mineHome,
    required this.label,
  });

  final int home, away;
  final String homeName, awayName;
  final SimResult result;
  final bool mineHome;

  /// 真ん中に出す区切りの名前(「前半終了」「試合終了」など)。
  final String label;

  @override
  Widget build(BuildContext context) {
    final r = result;
    Widget side(int team, String name, SimTeam t, bool mine, CrossAxisAlignment align) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: align,
              children: [
                TeamBadge(team: team, size: 30),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(name, maxLines: 1, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: mine ? GmColors.ball : GmColors.text)),
                ),
                Text('${t.pts}', style: const TextStyle(fontSize: 38, height: 1.05, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 6)])),
                Text([for (final p in t.periods) '$p'].join('・'), style: const TextStyle(fontSize: 11, color: GmColors.sub)),
              ],
            ),
          ),
        );
    return Container(
      key: const Key('live-court'),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: GmColors.line)),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        SizedBox(
          height: 132,
          child: CustomPaint(
            painter: _CourtPainter(left: colorOf(away).jersey, right: colorOf(home).jersey),
            child: Row(children: [
              side(away, awayName, r.away, !mineHome, CrossAxisAlignment.start),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: GmColors.bg.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(6)),
                child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: GmColors.gold)),
              ),
              side(home, homeName, r.home, mineHome, CrossAxisAlignment.end),
            ]),
          ),
        ),
        Container(
          height: 54,
          color: GmColors.panel,
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
          child: CustomPaint(
            painter: _MomentumPainter([for (final d in r.flow) mineHome ? d : -d]),
            size: Size.infinite,
          ),
        ),
      ]),
    );
  }
}

/// 上から見たコート。木の床に、左右の半面をチームの色でうっすら塗る。
class _CourtPainter extends CustomPainter {
  _CourtPainter({required this.left, required this.right});
  final Color left, right;

  @override
  void paint(Canvas canvas, Size s) {
    final floor = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF9C6B3C), Color(0xFF7A5230)],
      ).createShader(Offset.zero & s);
    canvas.drawRect(Offset.zero & s, floor);
    // 板の目
    final grain = Paint()
      ..color = const Color(0x14000000)
      ..strokeWidth = 1;
    for (var y = 6.0; y < s.height; y += 9) {
      canvas.drawLine(Offset(0, y), Offset(s.width, y), grain);
    }
    final half = s.width / 2;
    canvas.drawRect(Rect.fromLTWH(0, 0, half, s.height), Paint()..color = left.withValues(alpha: 0.55));
    canvas.drawRect(Rect.fromLTWH(half, 0, half, s.height), Paint()..color = right.withValues(alpha: 0.55));
    // 文字が読めるよう、全体を少し暗く
    canvas.drawRect(Offset.zero & s, Paint()..color = const Color(0x66000000));

    final line = Paint()
      ..color = const Color(0x4DFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    const pad = 6.0;
    final court = Rect.fromLTRB(pad, pad, s.width - pad, s.height - pad);
    canvas.drawRect(court, line);
    canvas.drawLine(Offset(half, court.top), Offset(half, court.bottom), line);
    final cy = s.height / 2;
    canvas.drawCircle(Offset(half, cy), s.height * 0.16, line);
    // 両側のゴール下(制限区域・フリースローの円・3ポイントの弧・リング)
    final keyW = s.height * 0.42, keyL = s.width * 0.16;
    for (final leftSide in [true, false]) {
      final baseX = leftSide ? court.left : court.right;
      final dir = leftSide ? 1.0 : -1.0;
      canvas.drawRect(Rect.fromLTRB(math.min(baseX, baseX + dir * keyL), cy - keyW / 2, math.max(baseX, baseX + dir * keyL), cy + keyW / 2), line);
      canvas.drawCircle(Offset(baseX + dir * keyL, cy), keyW / 2, line);
      final hoop = Offset(baseX + dir * s.width * 0.045, cy);
      canvas.drawCircle(hoop, 3.2, Paint()..color = GmColors.ball);
      final arcR = s.height * 0.44;
      canvas.drawArc(Rect.fromCircle(center: hoop, radius: arcR), leftSide ? -math.pi / 2 : math.pi / 2, math.pi, false, line);
    }
  }

  @override
  bool shouldRepaint(covariant _CourtPainter old) => old.left != left || old.right != right;
}

/// 自分から見た点差の流れ。上(リード)は緑、下(ビハインド)は赤。4つのクォーターに区切りの線。
class _MomentumPainter extends CustomPainter {
  _MomentumPainter(this.diff);
  final List<int> diff;

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
  }

  @override
  bool shouldRepaint(covariant _MomentumPainter old) => old.diff != diff;
}
