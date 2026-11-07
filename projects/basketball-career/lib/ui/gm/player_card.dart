import 'package:flutter/material.dart';

import '../../gm/career.dart';
import '../../gm/league.dart';
import '../../gm/player.dart';
import 'box_score.dart';
import 'common.dart';
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
          PlayerAvatar(team: team, size: 84, pose: p.pos.big ? 'dunk' : 'shoot'),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name, maxLines: 2, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 2),
              Text('${p.pos.short}・${p.age}歳・${p.exp == 0 ? '新人' : '${p.exp}年目'}', style: const TextStyle(color: Colors.white70)),
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
              final (lo, hi) = potentialRange(p);
              return '$lo〜$hi';
            }(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
          ]),
        ]),
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
                        Expanded(child: Text(s.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: GmColors.sub))),
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
            _line('伸びしろ', p.grade == '-' ? 'なし' : p.grade),
            if (p.injured > 0) _line('けが', 'あと${p.injured}試合'),
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
        const SizedBox(height: 4),
        row(['年', 'チーム', '試合', '得点', 'リバ', 'アシ'], head: true),
        for (final r in p.career)
          row(['${r[0]}年目', teamDefs[r[1]].short, '${r[2]}', f(r[3], r[2]), f(r[4], r[2]), f(r[5], r[2])]),
        const Divider(height: 10),
        row(['通算', '${p.career.length}シーズン', '${t.gp}', f(t.pts, t.gp), f(t.reb, t.gp), f(t.ast, t.gp)], color: GmColors.gold),
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
