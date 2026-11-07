import 'package:flutter/material.dart';

import '../../gm/career.dart';
import '../../gm/player.dart';
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
            Text('${p.ovr}', style: TextStyle(fontSize: 40, height: 1.0, fontWeight: FontWeight.bold, color: GmColors.ovr(p.ovr))),
            if (p.lastDelta != 0)
              Text(p.lastDelta > 0 ? '+${p.lastDelta}' : '${p.lastDelta}',
                  style: TextStyle(fontSize: 12, color: p.lastDelta > 0 ? GmColors.good : GmColors.bad)),
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
Future<void> showPlayerCard(BuildContext context, Career car, Player p, int team) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            PlayerCardHeader(p: p, team: team),
            const SizedBox(height: 12),
            AttrBars(p: p),
            const SizedBox(height: 10),
            // シーズン前とオフは、今季の成績がまだ前のシーズンのもの
            if (p.stats.gp > 0) _line(car.seasonStarted ? '今季' : '昨季', '${p.stats.line}(${p.stats.gp}試合)'),
            if (p.prev.gp > 0) _line(car.seasonStarted ? '昨季' : '2季前', '${p.prev.line}(${p.prev.gp}試合)'),
            if (p.allStars > 0) _line('オールスター', '${p.allStars}回'),
            for (final a in car.awards.where((a) => a.player == p.id)) _line('表彰', '${a.season}年目 ${a.kind.label}'),
            _line('年俸', '${money(p.salary)}(残り${p.years}年)'),
            _line('伸びしろ', p.grade == '-' ? 'なし' : p.grade),
            if (p.injured > 0) _line('けが', 'あと${p.injured}試合'),
          ]),
        ),
      ),
    );

Widget _line(String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        SizedBox(width: 110, child: Text(k, style: const TextStyle(color: GmColors.sub))),
        Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.bold))),
      ]),
    );
