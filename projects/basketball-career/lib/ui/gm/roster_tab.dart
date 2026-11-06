import 'package:flutter/material.dart';

import '../../gm/career.dart';
import '../../gm/league.dart';
import '../../gm/player.dart';
import '../gm_controller.dart';
import 'common.dart';
import 'style.dart';

/// チームのタブ。先発と控え、年俸。選手を押すと詳しく見て、放せる。
class RosterTab extends StatelessWidget {
  const RosterTab({super.key, required this.c});
  final GmController c;

  @override
  Widget build(BuildContext context) {
    final car = c.career!;
    final me = car.me;
    final order = lineup(me.roster);
    final rank = car.strengthRank(Career.mine) + 1;
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                PlayerAvatar(team: Career.mine, size: 52, pose: 'dunk'),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(me.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('戦力 ${me.strength.toStringAsFixed(1)}(30チーム中$rank位)・${me.roster.length}人',
                        style: const TextStyle(color: GmColors.sub)),
                  ]),
                ),
              ]),
              const SizedBox(height: 12),
              PayrollBar(payroll: me.payroll),
              const SizedBox(height: 6),
              Text(
                  '上限 ${money(salaryCap)}・ぜいたく税 ${money(taxLine)}から・合計の上限 ${money(hardCap)}'
                  '${me.deadCap > 0 ? '\n放した選手の年俸 ${money(me.deadCap)}が今季の合計に残っている' : ''}',
                  style: const TextStyle(fontSize: 12, color: GmColors.sub, height: 1.5)),
            ]),
          ),
        ),
        const SectionTitle('先発'),
        for (final p in order.take(5)) _row(context, car, p),
        const SectionTitle('控え'),
        for (final p in order.skip(5)) _row(context, car, p),
      ],
    );
  }

  Widget _row(BuildContext context, Career car, Player p) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: PlayerRow(
          p: p,
          team: Career.mine,
          showDelta: true,
          extra: car.draftedIds.contains(p.id) ? const Tag('生え抜き', color: GmColors.good) : null,
          onTap: () => _detail(context, car, p),
        ),
      );

  Future<void> _detail(BuildContext context, Career car, Player p) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (ctx) {
          final canRelease = !car.expiring.contains(p.id) &&
              (car.phase == Phase.preseason || car.phase == Phase.season || car.phase == Phase.contracts);
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  PlayerAvatar(team: Career.mine, size: 72, pose: p.pos.big ? 'dunk' : 'shoot'),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      Text('${p.pos.label}・${p.age}歳', style: const TextStyle(color: GmColors.sub)),
                    ]),
                  ),
                  OvrBadge(p.ovr, size: 56, delta: p.lastDelta),
                ]),
                const SizedBox(height: 12),
                _line('年俸', '${money(p.salary)}(残り${p.years}年)'),
                _line('力に見合う年俸', money(fairSalary(p.ovr, p.age))),
                _line('伸びしろ', switch (p.grade) {
                  'S' => 'S(大きく伸びる見込み)',
                  'A' => 'A(まだ伸びる)',
                  'B' => 'B(少し伸びる)',
                  'C' => 'C(あまり伸びない)',
                  _ => p.age >= 30 ? 'なし(これから落ちていく)' : 'なし',
                }),
                if (p.drafted != null) _line('ドラフト', p.drafted!),
                const SizedBox(height: 14),
                if (canRelease)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: GmColors.bad),
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: ctx,
                        builder: (d) => AlertDialog(
                          title: Text('${p.name}を放す?'),
                          content: Text('今シーズンの年俸 ${money(p.salary)}は、放しても今季の合計に残る。'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('やめる')),
                            TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('放す')),
                          ],
                        ),
                      );
                      if (ok == true) {
                        c.release(p.id);
                        if (ctx.mounted) Navigator.pop(ctx);
                      }
                    },
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('この選手を放す'),
                  ),
              ]),
            ),
          );
        },
      );

  Widget _line(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          SizedBox(width: 110, child: Text(k, style: const TextStyle(color: GmColors.sub))),
          Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.bold))),
        ]),
      );
}
