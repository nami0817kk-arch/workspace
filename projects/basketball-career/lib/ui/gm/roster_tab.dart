import 'package:flutter/material.dart';

import '../../gm/career.dart';
import '../../gm/player.dart';
import '../gm_controller.dart';
import 'common.dart';
import 'negotiate_dialog.dart';
import 'player_card.dart';
import 'rotation_screen.dart';
import 'style.dart';

/// チームのタブ。先発と控え、年俸。選手を押すと詳しく見て、放せる。
class RosterTab extends StatelessWidget {
  const RosterTab({super.key, required this.c});
  final GmController c;

  @override
  Widget build(BuildContext context) {
    final car = c.career!;
    final me = car.me;
    final order = me.order;
    final rank = car.strengthRank(car.mine) + 1;
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                PlayerAvatar(team: car.mine, size: 52, pose: 'dunk'),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(me.name, maxLines: 1, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
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
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => RotationScreen(c: c))),
          icon: const Icon(Icons.swap_vert_rounded),
          label: Text(me.rotation.isEmpty ? '先発と控えの順を決める(いまは自動)' : '先発と控えの順を決める'),
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
          team: car.mine,
          showDelta: true,
          showMorale: true,
          extra: car.draftedIds.contains(p.id) ? const Tag('生え抜き', color: GmColors.good) : null,
          onTap: () => _detail(context, car, p),
        ),
      );

  Future<void> _detail(BuildContext context, Career car, Player p) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (ctx) {
          final canRelease = !car.expiring.contains(p.id) &&
              (car.phase == Phase.preseason || car.phase == Phase.season || car.phase == Phase.contracts);
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                PlayerCardHeader(p: p, team: car.mine),
                const SizedBox(height: 12),
                AttrBars(p: p),
                const SizedBox(height: 10),
                // シーズン前とオフは、今季の成績がまだ前のシーズンのもの
                if (p.stats.gp > 0) _line(car.seasonStarted ? '今季' : '昨季', '${p.stats.line}(${p.stats.gp}試合)'),
                if (p.prev.gp > 0) _line(car.seasonStarted ? '昨季' : '2季前', '${p.prev.line}(${p.prev.gp}試合)'),
                for (final a in car.awards.where((a) => a.player == p.id)) _line('表彰', '${a.season}年目 ${a.kind.label}'),
                if (p.allStars > 0) _line('オールスター', '${p.allStars}回'),
                _line('気持ち', '${p.moraleLabel}(${p.morale})'),
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
                if (car.extendProblem(p) == null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: FilledButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await negotiateExtension(context, c, p);
                      },
                      icon: const Icon(Icons.edit_document),
                      label: const Text('契約の延長を申し出る'),
                    ),
                  )
                else if (p.years == 1 && car.me.roster.contains(p))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('延長: ${car.extendProblem(p)}', style: const TextStyle(fontSize: 12, color: GmColors.sub)),
                  ),
                if (p.nextSalary != null) _line('延長', '来季から${money(p.nextSalary!)}(残り${p.years}年)'),
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
