import 'package:flutter/material.dart';

import '../../gm/career.dart';
import '../../gm/league.dart';
import '../gm_controller.dart';
import 'common.dart';
import 'style.dart';

/// リーグのタブ。順位・各チームの考え・これまでの成績。
class LeagueTab extends StatelessWidget {
  const LeagueTab({super.key, required this.c});
  final GmController c;

  @override
  Widget build(BuildContext context) {
    final car = c.career!;
    final started = car.phase == Phase.season || car.phase == Phase.playoffs || car.phase == Phase.seasonEnd;
    // 自分の地区を先に
    final confs = [car.me.east, !car.me.east];
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
      children: [
        for (final east in confs) ...[
          SectionTitle('${east ? '東' : '西'}地区 ${started ? '順位' : '戦力の順(シーズン前)'}'),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Builder(builder: (context) {
                final list = started
                    ? standings(car.teams, east: east)
                    : ([...car.teams.where((t) => t.east == east)]..sort((a, b) => b.strength.compareTo(a.strength)));
                return Column(children: [
                  for (var i = 0; i < list.length; i++) _teamRow(context, car, list[i], i + 1, started),
                ]);
              }),
            ),
          ),
        ],
        if (car.history.isNotEmpty) ...[
          const SectionTitle('これまでの成績'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                for (final h in car.history.reversed)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [
                      SizedBox(width: 52, child: Text('${h.season}年目', style: const TextStyle(color: GmColors.sub))),
                      SizedBox(width: 78, child: Text('${h.wins}勝${h.losses}敗')),
                      SizedBox(width: 36, child: Text('${h.rank}位', style: const TextStyle(color: GmColors.sub))),
                      Expanded(
                        child: Text(h.resultLabel,
                            style: TextStyle(color: h.champion ? GmColors.gold : null, fontWeight: h.champion ? FontWeight.bold : null)),
                      ),
                    ]),
                  ),
              ]),
            ),
          ),
        ],
      ],
    );
  }

  Widget _teamRow(BuildContext context, Career car, Team t, int n, bool started) {
    final mine = t.index == Career.mine;
    return InkWell(
      onTap: () => _showTeam(context, car, t),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          SizedBox(width: 24, child: Text('$n', style: TextStyle(color: n <= directSeeds ? GmColors.gold : n <= playInSeeds ? GmColors.ball : GmColors.sub, fontWeight: FontWeight.bold))),
          TeamBadge(team: t.index, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, color: mine ? GmColors.ball : null)),
              if (!mine) Text(t.mode.label, style: const TextStyle(fontSize: 11, color: GmColors.sub)),
            ]),
          ),
          Text(started ? record(t) : '戦力 ${t.strength.toStringAsFixed(1)}', style: const TextStyle(fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }

  Future<void> _showTeam(BuildContext context, Career car, Team t) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (ctx) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          builder: (ctx, sc) => ListView(
            controller: sc,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            children: [
              Row(children: [
                TeamBadge(team: t.index, size: 34),
                const SizedBox(width: 10),
                Expanded(child: Text(t.name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold))),
              ]),
              const SizedBox(height: 6),
              if (t.index != Career.mine) Text('${t.mode.label}: ${t.mode.wants}', style: const TextStyle(color: GmColors.sub)),
              const SizedBox(height: 8),
              PayrollBar(payroll: t.payroll),
              const SizedBox(height: 10),
              for (final p in lineup(t.roster))
                Padding(padding: const EdgeInsets.only(bottom: 6), child: PlayerRow(p: p, team: t.index)),
            ],
          ),
        ),
      );
}
