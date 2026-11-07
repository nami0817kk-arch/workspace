import 'package:flutter/material.dart';

import '../../gm/career.dart';
import '../../gm/player.dart';
import '../gm_controller.dart';
import 'common.dart';
import 'negotiate_dialog.dart';
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
      Phase.contracts => '大物(最低年俸より高く求める選手)は、ほかのチームと競り合う。申し込むと、日が進むたびに行き先を決める。'
          '最低年俸(${money(minSalary)})の選手は、上限を超えていてもすぐ取れる。',
      Phase.preseason => '年俸の上限まで空きがあれば、誰とでも契約できる。最低年俸(${money(minSalary)})の選手は、上限を超えていても取れる。',
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
              if (car.phase == Phase.contracts) ...[
                const Divider(height: 20),
                Row(children: [
                  Expanded(
                    child: Text(car.faDay < faDays ? '自由契約 ${car.faDay + 1}日目 / $faDays日' : '自由契約の日程は終わった',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: GmColors.ball)),
                  ),
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                    onPressed: car.faDay >= faDays || c.busy ? null : c.nextFaDay,
                    icon: const Icon(Icons.wb_sunny_rounded, size: 18),
                    label: const Text('次の日へ'),
                  ),
                ]),
                if (car.faDay < faDays)
                  const Text('オフを終えると、残りの日は自動で進む。', style: TextStyle(fontSize: 12, color: GmColors.sub)),
              ],
            ]),
          ),
        ),
        if (car.phase == Phase.contracts && car.faLog.isNotEmpty) ...[
          const SectionTitle('このオフの移籍'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final n in car.faLog.take(8)) Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text(n, style: const TextStyle(fontSize: 13))),
              ]),
            ),
          ),
        ],
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
    if (car.isBigFa(p)) return _bigRow(context, car, p, ask);
    final problem = car.signProblem(p);
    return PlayerRow(
      p: p,
      team: car.mine,
      salaryText: '求める年俸 ${money(ask.salary)}',
      trailing: SizedBox(
        height: 36,
        child: FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(64, 36), padding: const EdgeInsets.symmetric(horizontal: 10)),
          onPressed: problem != null || c.busy
              ? null
              : () => negotiate(context, c, p, freeAgent: true),
          child: const Text('契約'),
        ),
      ),
      extra: problem != null && car.canSign ? Text(problem, style: const TextStyle(fontSize: 11, color: GmColors.sub)) : null,
    );
  }

  /// 大物の行。関心・ほかの申し込み・自分の申し込みを見せる。
  Widget _bigRow(BuildContext context, Career car, Player p, Ask ask) {
    final mine = car.myBid(p.id);
    final problem = car.bidProblem(p);
    final rivals = car.rivalBids(p.id);
    return PlayerRow(
      p: p,
      team: car.mine,
      salaryText: '求める年俸 ${money(ask.salary)}(最長${ask.maxYears}年)',
      trailing: SizedBox(
        height: 36,
        child: FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(64, 36), padding: const EdgeInsets.symmetric(horizontal: 10)),
          onPressed: (problem != null && mine == null) || c.busy ? null : () => negotiateBid(context, c, p),
          child: Text(mine == null ? '申し込む' : '変える'),
        ),
      ),
      extra: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('関心 ${interestLabel(car.interest(p, car.mine))}・ほかの申し込み ${rivals == 0 ? 'なし' : '$rivalsチーム'}',
            style: TextStyle(fontSize: 12, color: rivals > 0 ? GmColors.gold : GmColors.sub)),
        if (mine != null) ...[
          Text('申し込み中 ${mine.years}年 ${money(mine.salary)}・選ばれる見込み ${(car.winChanceOf(p) * 100).round()}%',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: GmColors.good)),
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(0, 32), padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
            onPressed: c.busy ? null : () => c.withdrawBid(p.id),
            child: const Text('申し込みを取り下げる', style: TextStyle(fontSize: 12)),
          ),
        ] else if (problem != null && car.faDay < faDays)
          Text(problem, style: const TextStyle(fontSize: 11, color: GmColors.sub)),
      ]),
    );
  }
}
