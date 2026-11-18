import 'package:flutter/material.dart';

import '../../gm/career.dart';
import '../../gm/league.dart';
import '../gm_controller.dart';
import 'common.dart';
import 'style.dart';

/// 今季の日程表(82試合)。区切りごとに並べ、終わった試合は勝ち負けと点、次の試合は枠で示す。
class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key, required this.c});
  final GmController c;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: c,
        builder: (context, _) {
          final car = c.career!;
          final games = <(int, bool)>[
            for (final round in seasonSchedule(car.teams.length))
              for (final (h, a) in round)
                if (h == car.mine)
                  (a, true)
                else if (a == car.mine)
                  (h, false),
          ];
          final log = car.seasonLog;
          final homeW = log.where((r) => r[1] == 1 && r[2] > r[3]).length, homeL = log.where((r) => r[1] == 1 && r[2] < r[3]).length;
          final awayW = log.where((r) => r[1] == 0 && r[2] > r[3]).length, awayL = log.where((r) => r[1] == 0 && r[2] < r[3]).length;
          return Scaffold(
            appBar: AppBar(title: const Text('日程表'), toolbarHeight: 40),
            body: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                children: [
                  Wrap(spacing: 14, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    Text('${car.me.wins}勝${car.me.losses}敗', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text('ホーム $homeW勝$homeL敗・アウェー $awayW勝$awayL敗', style: const TextStyle(fontSize: 12.5, color: GmColors.sub)),
                    if (car.phase == Phase.season)
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Switch(key: const Key('rest-settled'), value: car.restWhenSettled, onChanged: c.busy ? null : c.setRestWhenSettled),
                        Text(
                          '順位が決まったら主力を休ませる${car.restWhenSettled && car.standingSettled ? '(いま休ませている)' : ''}',
                          style: const TextStyle(fontSize: 12.5),
                        ),
                      ]),
                  ]),
                  for (var b = 0; b < blocksPerSeason; b++) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 10, bottom: 4),
                      child: Text(
                        '${b + 1}区切り(${blockStart(b) + 1}〜${blockStart(b + 1)}試合)'
                        '${b == tradeDeadlineBlock - 1 ? '・終わりにトレードの締め切り・オールスター・カップ戦' : ''}'
                        '${b == blocksPerSeason - 1 ? '・終わるとプレーオフ' : ''}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    Wrap(spacing: 4, runSpacing: 4, children: [
                      for (var i = blockStart(b); i < blockStart(b + 1) && i < games.length; i++) _cell(car, i, games[i], i < log.length ? log[i] : null),
                    ]),
                  ],
                ],
              ),
            ),
          );
        },
      );

  Widget _cell(Career car, int i, (int, bool) g, List<int>? r) {
    final (opp, home) = g;
    final next = r == null && i == car.roundAt && car.phase == Phase.season;
    final win = r != null && r[2] > r[3];
    final color = r == null ? (next ? GmColors.gold : GmColors.line) : (win ? GmColors.good : GmColors.bad);
    return Container(
      width: 58,
      padding: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: r == null ? GmColors.panel : color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color, width: next ? 2 : 1),
      ),
      child: Column(children: [
        Text('${i + 1}${home ? '' : ' @'}', style: const TextStyle(fontSize: 10, color: GmColors.sub)),
        TeamBadge(team: opp, size: 20),
        Text(
          r == null ? (home ? 'ホーム' : 'アウェー') : '${win ? '勝' : '負'} ${r[2]}-${r[3]}',
          maxLines: 1,
          style: TextStyle(fontSize: 10, fontWeight: r == null ? null : FontWeight.bold, color: r == null ? GmColors.sub : color),
        ),
      ]),
    );
  }
}
