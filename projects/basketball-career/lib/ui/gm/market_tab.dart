import 'package:flutter/material.dart';

import '../../gm/career.dart';
import '../../gm/player.dart';
import '../gm_controller.dart';
import 'common.dart';
import 'style.dart';

/// 補強のタブ。自由契約の選手と契約する。
class MarketTab extends StatelessWidget {
  const MarketTab({super.key, required this.c});
  final GmController c;

  @override
  Widget build(BuildContext context) {
    final car = c.career!;
    final fa = [...car.freeAgents]..sort((a, b) => b.ovr.compareTo(a.ovr));
    final note = switch (car.phase) {
      Phase.contracts || Phase.preseason => '年俸の上限まで空きがあれば、誰とでも契約できる。最低年俸(${money(minSalary)})の選手は、上限を超えていても取れる。',
      Phase.season => 'シーズン中は、最低年俸の選手だけ取れる。',
      _ => '今は契約できない(シーズン前・シーズン中・オフの契約で取れる)。',
    };
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('自由契約の選手', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(note, style: const TextStyle(color: GmColors.sub, height: 1.5)),
              const SizedBox(height: 10),
              PayrollBar(payroll: car.me.payroll),
              const SizedBox(height: 4),
              Text('登録 ${car.me.roster.length - car.expiring.length}人 / $maxRoster人', style: const TextStyle(fontSize: 12, color: GmColors.sub)),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        if (fa.isEmpty) const Text('いない', style: TextStyle(color: GmColors.sub)),
        for (final p in fa) ...[
          _row(context, car, p),
          const SizedBox(height: 6),
        ],
      ],
    );
  }

  Widget _row(BuildContext context, Career car, Player p) {
    final ask = car.askOf(p, car.me);
    final problem = car.signProblem(p);
    return PlayerRow(
      p: p,
      team: 0,
      salaryText: '求める年俸 ${money(ask.salary)}',
      trailing: SizedBox(
        height: 36,
        child: FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(64, 36), padding: const EdgeInsets.symmetric(horizontal: 10)),
          onPressed: problem != null || c.busy
              ? null
              : () async {
                  final y = await pickYears(context, title: '${p.name}と契約', body: '年俸 ${money(ask.salary)}。何年にする?', maxYears: ask.maxYears);
                  if (y != null) c.signFreeAgent(p.id, y);
                },
          child: const Text('契約'),
        ),
      ),
      extra: problem != null && car.canSign ? Text(problem, style: const TextStyle(fontSize: 11, color: GmColors.sub)) : null,
    );
  }
}
