import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../gm/potential_view.dart';
import '../../gm/career.dart';
import '../../gm/league.dart';
import '../../gm/player.dart';
import 'box_score.dart';
import 'common.dart';
import 'player_face.dart';
import 'style.dart';

/// バッジの段階の色(銅・銀・金・殿堂)。
const badgeColors = [Color(0xFFCD8A55), Color(0xFFC9D3E0), GmColors.gold, Color(0xFFB98CFF)];

/// 選手のカードの上の部分。チームの色の帯に、大きな力の数字・型・ポジション・バッジ。
class PlayerCardHeader extends StatelessWidget {
  const PlayerCardHeader({super.key, required this.p, required this.team});
  final Player p;
  final int team;

  @override
  Widget build(BuildContext context) {
    final color = colorOf(team);
    final badges = badgesOf(p);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.accent.withValues(alpha: 0.9), GmColors.panelHi],
        ),
        border: Border.all(color: color.jersey.withValues(alpha: 0.8)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          PlayerFace(p: p, team: team, size: 84),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name, maxLines: 2, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 2),
              Text('#${jerseyOf(p)}・${p.pos.short}・${p.age}歳・${p.exp == 0 ? '新人' : '${p.exp}年目'}', style: const TextStyle(color: Colors.white70)),
              Text(() {
                final (h, w, span) = physicalOf(p);
                return '${h}cm・${w}kg・WS ${span}cm';
              }(), style: const TextStyle(fontSize: 12, color: Colors.white70)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                child: Text(archetypeOf(p), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ]),
          ),
          Column(children: [
            const Text('OVR', style: TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.bold)),
            Text('${shown(p.ovr)}', style: TextStyle(fontSize: 40, height: 1.0, fontWeight: FontWeight.bold, color: GmColors.ovr(p.ovr))),
            if (shownDelta(p.ovr, p.lastDelta) != 0)
              Text(shownDelta(p.ovr, p.lastDelta) > 0 ? '+${shownDelta(p.ovr, p.lastDelta)}' : '${shownDelta(p.ovr, p.lastDelta)}',
                  style: TextStyle(fontSize: 12, color: p.lastDelta > 0 ? GmColors.good : GmColors.bad)),
            const SizedBox(height: 4),
            const Text('POT', style: TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.bold)),
            Text(() {
              final pv = potentialShown(p);
              return '${pv.potLo}〜${pv.potHi}';
            }(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
          ]),
        ]),
        const SizedBox(height: 8),
        Text(traitsLine(viewingCareer, p), style: const TextStyle(fontSize: 12, color: Colors.white70)),
        if (traitsText(viewingCareer, p).isNotEmpty) Text(traitsText(viewingCareer, p), style: const TextStyle(fontSize: 11, color: Colors.white60, height: 1.4)),
        if (badges.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final (name, tier) in badges) BadgeChip(name: name, tier: tier),
          ]),
        ],
      ]),
    );
  }
}

/// 能力の一覧。6つの分類ごとに、分類の値と細かい能力を2列で並べる。
class RatingsPanel extends StatelessWidget {
  const RatingsPanel({super.key, required this.p});
  final Player p;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (badgesOf(p).isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            decoration: BoxDecoration(color: GmColors.panelHi, borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('バッジの試合での効き', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              for (final a in Attr.values)
                if (badgeTierOf(p, a) >= 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1.5),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SizedBox(
                        width: 110,
                        child: Text('${badgeNames[a]}(${badgeTiers[badgeTierOf(p, a)]})',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: badgeColors[badgeTierOf(p, a)])),
                      ),
                      Expanded(child: Text(badgeEffects[a]!, style: const TextStyle(fontSize: 12, color: GmColors.sub))),
                    ]),
                  ),
            ]),
          ),
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text('● の付いた項目は、試合の1回ずつの攻めの計算に使っている(ほかは見せるだけ)',
              style: TextStyle(fontSize: 11, color: GmColors.sub)),
        ),
        for (final a in Attr.values) ...[
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            decoration: BoxDecoration(color: GmColors.panelHi, borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(child: Text(a.label, style: const TextStyle(fontWeight: FontWeight.bold))),
                Text('${shown(p.attr(a))}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: GmColors.ovr(p.attr(a)))),
              ]),
              const SizedBox(height: 4),
              LayoutBuilder(builder: (context, cons) {
                final w = (cons.maxWidth - 16) / 2;
                return Wrap(spacing: 16, runSpacing: 2, children: [
                  for (final s in subRatings.where((s) => s.attr == a))
                    SizedBox(
                      width: w,
                      child: Row(children: [
                        Expanded(
                          child: Text('${simSubRatings.contains(s.label) ? '● ' : ''}${s.label}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: simSubRatings.contains(s.label) ? Colors.white70 : GmColors.sub)),
                        ),
                        Text('${subRating(p, s)}',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _subColor(subRating(p, s)), fontFeatures: const [FontFeature.tabularFigures()])),
                      ]),
                    ),
                ]);
              }),
            ]),
          ),
        ],
      ]);
}

/// 見せる数字の色(90以上が金、80台が橙、70台が水色)。
Color _subColor(int v) => v >= 90
    ? GmColors.gold
    : v >= 80
        ? GmColors.ball
        : v >= 70
            ? const Color(0xFF8FD3FF)
            : GmColors.sub;

class BadgeChip extends StatelessWidget {
  const BadgeChip({super.key, required this.name, required this.tier});
  final String name;
  final int tier;

  @override
  Widget build(BuildContext context) {
    final c = badgeColors[tier];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.shield_rounded, size: 14, color: c),
        const SizedBox(width: 4),
        Text('$name(${badgeTiers[tier]})', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: c)),
      ]),
    );
  }
}

/// ほかのチームの選手のカードを見る(トレードやリーグの画面から)。
Future<void> showPlayerCard(BuildContext context, Career car, Player p, int team) => showGmSheet<void>(
      context,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            PlayerCardHeader(p: p, team: team),
            RatingsPanel(p: p),
            const SizedBox(height: 10),
            // シーズン前とオフは、今季の成績がまだ前のシーズンのもの
            if (p.stats.gp > 0) _line(car.seasonStarted ? '今季' : '昨季', '${p.stats.line}(${p.stats.gp}試合)'),
            if (p.stats.fga > 0)
              _line('シュート', 'FG ${(p.stats.fgPct * 100).toStringAsFixed(1)}%・3P ${p.stats.tpa == 0 ? '-' : '${(p.stats.tpPct * 100).toStringAsFixed(1)}%'}・FT ${p.stats.fta == 0 ? '-' : '${(p.stats.ftPct * 100).toStringAsFixed(1)}%'}'),
            if (p.prev.gp > 0) _line(car.seasonStarted ? '昨季' : '2季前', '${p.prev.line}(${p.prev.gp}試合)'),
            if (p.allStars > 0) _line('オールスター', '${p.allStars}回'),
            if (awardsSummary(car, p).isNotEmpty) _line('表彰', awardsSummary(car, p)),
            _line('年俸', '${money(p.salary)}(残り${p.years}年)'),
            _line('伸びしろ', potentialLine(car, p)),
            if (p.age < 30) _line('伸び方', growthLine(car, p)),
            if (p.injured > 0) _line('けが', p.injuryText.isEmpty ? 'あと${p.injured}試合' : p.injuryText),
            if (p.injCount >= 3) _line('けがの歴', '${p.injCount}回(繰り返している)'),
            RecentGames(car: car, p: p),
            if (p.career.isNotEmpty) CareerTable(p: p),
          ]),
        ),
      ),
    );

/// 受けた表彰を種類ごとにまとめる(「MVP 2回・オールリーグ1st 3回」)。
String awardsSummary(Career car, Player p) {
  final mine = car.awards.where((a) => a.player == p.id).toList();
  return [
    for (final k in AwardKind.values)
      if (mine.any((a) => a.kind == k)) '${k.label} ${mine.where((a) => a.kind == k).length}回',
  ].join('・');
}

/// 年ごとの成績と通算(このリーグに来てから)。
class CareerTable extends StatelessWidget {
  const CareerTable({super.key, required this.p});
  final Player p;

  @override
  Widget build(BuildContext context) {
    Widget row(List<String> cells, {bool head = false, Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            for (var i = 0; i < cells.length; i++)
              Expanded(
                flex: i == 1 ? 3 : 2,
                child: Text(cells[i],
                    textAlign: i <= 1 ? TextAlign.left : TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: color ?? (head ? GmColors.sub : null),
                      fontWeight: head ? null : FontWeight.bold,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    )),
              ),
          ]),
        );
    String f(int v, int gp) => gp == 0 ? '-' : (v / gp).toStringAsFixed(1);
    final t = p.careerTotals;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(color: GmColors.panelHi, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('年ごとの成績', style: TextStyle(fontWeight: FontWeight.bold)),
        if (p.career.length >= 2) ...[
          const SizedBox(height: 6),
          SizedBox(height: 90, child: CustomPaint(key: const Key('career-chart'), painter: _CareerChart(p.career))),
          const Text('棒: 1試合の得点 / 線: その年の終わりのOVR', style: TextStyle(fontSize: 11, color: GmColors.sub)),
        ],
        const SizedBox(height: 4),
        row(['年', 'チーム', '試合', '得点', 'リバ', 'アシ', 'OVR'], head: true),
        for (final r in p.career)
          row(['${r[0]}年目', teamDefs[r[1]].short, '${r[2]}', f(r[3], r[2]), f(r[4], r[2]), f(r[5], r[2]), r.length > 6 ? '${shown(r[6])}' : '-']),
        const Divider(height: 10),
        row(['通算', '${p.career.length}シーズン', '${t.gp}', f(t.pts, t.gp), f(t.reb, t.gp), f(t.ast, t.gp), ''], color: GmColors.gold),
      ]),
    );
  }
}

Widget _line(String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        SizedBox(width: 110, child: Text(k, style: const TextStyle(color: GmColors.sub))),
        Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.bold))),
      ]),
    );

/// 年ごとの得点(棒)と OVR(線)。
class _CareerChart extends CustomPainter {
  _CareerChart(this.rows);
  final List<List<int>> rows;

  @override
  void paint(Canvas canvas, Size size) {
    final n = rows.length;
    final w = size.width / n;
    final ppg = [for (final r in rows) r[2] == 0 ? 0.0 : r[3] / r[2]];
    // 得点は35点を上の端にする(1年だけの選手でも棒がいっぱいにならない)
    final top = math.max(35.0, ppg.reduce(math.max));
    final bar = Paint()..color = GmColors.ball.withValues(alpha: 0.75);
    final bw = math.min(w * 0.6, 34.0);
    for (var i = 0; i < n; i++) {
      final h = (size.height - 16) * ppg[i] / top;
      final cx = i * w + w / 2;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(cx - bw / 2, size.height - h, bw, h), const Radius.circular(3)), bar);
      final tp = TextPainter(
        text: TextSpan(text: ppg[i].toStringAsFixed(1), style: const TextStyle(fontFamily: 'NotoSansJP', fontSize: 10, color: GmColors.text)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, size.height - h - tp.height - 1));
    }
    final ovr = [for (final r in rows) if (r.length > 6) shown(r[6])];
    if (ovr.length == n) {
      final line = Paint()
        ..color = GmColors.gold
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      double y(int o) => size.height - (size.height - 12) * ((o - 40) / 60).clamp(0.0, 1.0);
      final path = Path()..moveTo(w / 2, y(ovr[0]));
      for (var i = 1; i < n; i++) {
        path.lineTo(i * w + w / 2, y(ovr[i]));
      }
      canvas.drawPath(path, line);
      for (var i = 0; i < n; i++) {
        canvas.drawCircle(Offset(i * w + w / 2, y(ovr[i])), 3, Paint()..color = GmColors.gold);
        final tp = TextPainter(
          text: TextSpan(text: '${ovr[i]}', style: const TextStyle(fontFamily: 'NotoSansJP', fontSize: 10, color: GmColors.gold, fontWeight: FontWeight.bold)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(i * w + w / 2 + 5, y(ovr[i]) - tp.height));
      }
    }
  }

  @override
  bool shouldRepaint(_CareerChart old) => old.rows != rows;
}
